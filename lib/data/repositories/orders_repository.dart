import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_config.dart';
import '../mock_data.dart';
import '../models/models.dart';

abstract class OrdersRepository {
  /// Admins see every order; clients see only their own.
  Stream<List<PreOrder>> watchOrders(
      {required String uid, required bool isAdmin});

  Future<void> placeOrder(PreOrder order);

  Future<void> updateStatus(String orderId, OrderStatus status);
}

/// ---- Demo implementation ----
class MockOrdersRepository implements OrdersRepository {
  final List<PreOrder> _orders = MockData.seedOrders();
  final _controller = StreamController<List<PreOrder>>.broadcast();

  void _emit() => _controller.add(List.unmodifiable(_orders));

  @override
  Stream<List<PreOrder>> watchOrders(
      {required String uid, required bool isAdmin}) async* {
    yield List.unmodifiable(_orders);
    yield* _controller.stream;
  }

  @override
  Future<void> placeOrder(PreOrder order) async {
    _orders.insert(0, order);
    _emit();
  }

  @override
  Future<void> updateStatus(String orderId, OrderStatus status) async {
    final o = _orders.firstWhere((e) => e.id == orderId,
        orElse: () => throw StateError('Order $orderId not found'));
    o.status = status;
    _emit();
  }
}

/// ---- Firebase implementation ----
class FirebaseOrdersRepository implements OrdersRepository {
  FirebaseOrdersRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FsCollections.orders);

  @override
  Stream<List<PreOrder>> watchOrders(
      {required String uid, required bool isAdmin}) {
    Query<Map<String, dynamic>> q =
        _col.orderBy('createdAt', descending: true);
    if (!isAdmin) {
      q = _col
          .where('clientId', isEqualTo: uid)
          .orderBy('createdAt', descending: true);
    }
    return q.snapshots().map((snap) =>
        snap.docs.map((d) => PreOrder.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> placeOrder(PreOrder order) async {
    // Let Firestore generate the id; store the rest of the fields.
    await _col.add(order.toMap());
  }

  @override
  Future<void> updateStatus(String orderId, OrderStatus status) async {
    await _col.doc(orderId).update({'status': status.name});
  }
}
