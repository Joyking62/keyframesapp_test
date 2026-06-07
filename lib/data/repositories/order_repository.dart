import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_draft.dart';

/// Domain contract for creating, tracking, and administering orders.
///
/// Client reads ([watchClientOrders], [watchOrder]) are scoped to a single
/// client, while [watchAllOrders] backs the admin orders-management view.
/// Status changes flow through [updateStatus], whose concrete implementation
/// delegates transition validation and timeline appending to the order
/// service (see `features/order/order_service.dart`) and notifies the owning
/// client.
abstract interface class OrderRepository {
  /// Persists a new [Order] from [draft] with status [OrderStatus.pending] and
  /// an initial `pending` timeline event, returning the created order.
  Future<Order> createOrder(OrderDraft draft);

  /// Streams, in real time, the orders belonging to the client identified by
  /// [clientId].
  Stream<List<Order>> watchClientOrders(String clientId);

  /// Streams all orders for the admin dashboard, optionally filtered by
  /// [filter] status.
  Stream<List<Order>> watchAllOrders({OrderStatus? filter});

  /// Applies a validated status transition to the order identified by
  /// [orderId], appending one [OrderStatusEvent] (with an optional [note]).
  Future<void> updateStatus(String orderId, OrderStatus status, {String? note});

  /// Streams a single order by [orderId] in real time.
  Stream<Order> watchOrder(String orderId);
}
