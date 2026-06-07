import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models/models.dart';
import '../data/repositories/repositories.dart';

/// App-wide state. The UI talks only to this class; this class talks only to
/// the [Repositories]. Swapping demo data for Firebase happens entirely inside
/// the repositories (see lib/core/app_config.dart → kUseFirebase).
class AppState extends ChangeNotifier {
  AppState(this._repos) {
    _authSub = _repos.auth.authStateChanges().listen(
          _onUserChanged,
          onError: (Object e) => debugPrint('auth stream error: $e'),
        );
  }

  final Repositories _repos;

  AppUser? _user;
  List<PreOrder> _orders = const [];
  List<ChatThread> _threads = const [];

  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<List<PreOrder>>? _ordersSub;
  StreamSubscription<List<ChatThread>>? _threadsSub;

  // ---- Public getters (unchanged API the UI relies on) ----
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.role == UserRole.admin;
  List<PreOrder> get orders => _orders;
  List<ChatThread> get threads => _threads;

  double get totalRevenue => _orders.fold(0, (sum, o) => sum + o.amount);
  int get activeOrders => _orders
      .where((o) =>
          o.status != OrderStatus.completed &&
          o.status != OrderStatus.cancelled)
      .length;
  int get completedOrders =>
      _orders.where((o) => o.status == OrderStatus.completed).length;

  // ---- React to auth changes: (re)wire data streams ----
  void _onUserChanged(AppUser? user) {
    _user = user;
    _ordersSub?.cancel();
    _threadsSub?.cancel();
    _orders = const [];
    _threads = const [];

    if (user != null) {
      _ordersSub = _repos.orders
          .watchOrders(uid: user.id, isAdmin: isAdmin)
          .listen((data) {
        _orders = data;
        notifyListeners();
      }, onError: (Object e) => debugPrint('orders stream error: $e'));
      _threadsSub = _repos.chat
          .watchThreads(uid: user.id, isAdmin: isAdmin)
          .listen((data) {
        _threads = data;
        notifyListeners();
      }, onError: (Object e) => debugPrint('chat stream error: $e'));
    }
    notifyListeners();
  }

  // ---- Auth ----
  Future<void> login(String email, String password,
      {bool asAdmin = false}) async {
    await _repos.auth.signIn(email, password, asAdmin: asAdmin);
    // _onUserChanged fires via the auth stream.
  }

  Future<void> register(String name, String email, String password) async {
    await _repos.auth.register(name, email, password);
  }

  void logout() => _repos.auth.signOut();

  // ---- Orders ----
  Future<void> placePreOrder({
    required ServiceItem service,
    required ServiceTier tier,
    required String brief,
  }) async {
    final order = PreOrder(
      id: 'KF-${DateTime.now().millisecondsSinceEpoch % 100000}',
      serviceTitle: service.title,
      tierName: tier.name,
      clientId: _user?.id ?? '',
      clientName: _user?.name ?? 'Guest',
      amount: tier.price,
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(days: tier.deliveryDays)),
      status: OrderStatus.pending,
      brief: brief,
    );
    await _repos.orders.placeOrder(order);
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) =>
      _repos.orders.updateStatus(orderId, status);

  // ---- Chat ----
  void sendMessage(String threadId, String text) {
    final uid = _user?.id ?? '';
    _repos.chat.sendMessage(threadId, uid, text);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _ordersSub?.cancel();
    _threadsSub?.cancel();
    super.dispose();
  }
}
