import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../data/models/models.dart';

/// Single source of truth for the demo. In production, back each of these with
/// a repository (Firebase Auth, Firestore, REST, etc.).
class AppState extends ChangeNotifier {
  AppUser? _user;
  final List<PreOrder> _orders = MockData.seedOrders();
  final List<ChatThread> _threads = MockData.seedThreadsForClient();

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.role == UserRole.admin;

  List<PreOrder> get orders => List.unmodifiable(_orders);
  List<ChatThread> get threads => List.unmodifiable(_threads);

  // ---- Auth (mocked) ----
  Future<void> login(String email, String password,
      {bool asAdmin = false}) async {
    await Future.delayed(const Duration(milliseconds: 900));
    _user = AppUser(
      id: 'u1',
      name: asAdmin ? 'Keyframes Admin' : 'Alex Morgan',
      email: email,
      role: asAdmin ? UserRole.admin : UserRole.client,
    );
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 900));
    _user = AppUser(id: 'u1', name: name, email: email);
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }

  // ---- Orders ----
  void placePreOrder({
    required ServiceItem service,
    required ServiceTier tier,
    required String brief,
  }) {
    final id = 'KF-${1043 + _orders.length}';
    _orders.insert(
      0,
      PreOrder(
        id: id,
        serviceTitle: service.title,
        tierName: tier.name,
        clientName: _user?.name ?? 'Guest',
        amount: tier.price,
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(Duration(days: tier.deliveryDays)),
        status: OrderStatus.pending,
        brief: brief,
      ),
    );
    notifyListeners();
  }

  void updateOrderStatus(String orderId, OrderStatus status) {
    final o = _orders.firstWhere((e) => e.id == orderId);
    o.status = status;
    notifyListeners();
  }

  // ---- Chat ----
  void sendMessage(String threadId, String text) {
    final idx = _threads.indexWhere((t) => t.id == threadId);
    if (idx == -1) return;
    final thread = _threads[idx];
    final msg = ChatMessage(
      id: 'm${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      fromMe: true,
      time: DateTime.now(),
    );
    _threads[idx] = ChatThread(
      id: thread.id,
      name: thread.name,
      subtitle: thread.subtitle,
      online: thread.online,
      messages: [...thread.messages, msg],
    );
    notifyListeners();

    // Simulate an auto-reply from the team for a lively demo.
    Future.delayed(const Duration(milliseconds: 1400), () {
      final i = _threads.indexWhere((t) => t.id == threadId);
      if (i == -1) return;
      final t = _threads[i];
      final reply = ChatMessage(
        id: 'm${DateTime.now().millisecondsSinceEpoch}',
        text: 'Got it — our team will update you shortly. 👍',
        fromMe: false,
        time: DateTime.now(),
      );
      _threads[i] = ChatThread(
        id: t.id,
        name: t.name,
        subtitle: t.subtitle,
        online: t.online,
        messages: [...t.messages, reply],
      );
      notifyListeners();
    });
  }

  // ---- Analytics helpers (admin) ----
  double get totalRevenue =>
      _orders.fold(0, (sum, o) => sum + o.amount);
  int get activeOrders => _orders
      .where((o) =>
          o.status != OrderStatus.completed &&
          o.status != OrderStatus.cancelled)
      .length;
  int get completedOrders =>
      _orders.where((o) => o.status == OrderStatus.completed).length;
}
