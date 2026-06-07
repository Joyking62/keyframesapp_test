import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';

/// Domain contract for the order status state machine and its side effects.
///
/// `OrderService` is the single source of truth for order lifecycle rules. It
/// owns:
///
/// * **Transition validation** ([isValidTransition]) — the allowed graph is
///   `pending -> inReview -> inProgress -> completed`, plus any non-`completed`
///   status -> `cancelled`.
/// * **Status-event appending** ([appendStatusEvent]) — a pure operation that
///   returns a new [Order] with one [OrderStatusEvent] appended, keeping
///   `order.status == order.timeline.last.status` and timestamps
///   non-decreasing, and rejecting illegal transitions without mutating the
///   input.
/// * **Notification hooks** ([notifyAdminsOfNewOrder],
///   [notifyClientOfStatusChange]) — fired when a pre-order is created and when
///   an order's status changes, so messaging can be delivered out-of-band.
///
/// This file defines only the contract; the concrete, pure implementation is
/// added in a subsequent task. Repository implementations delegate to this
/// service so that the same lifecycle rules apply regardless of the backend.
abstract interface class OrderService {
  /// Returns `true` if moving an order from [from] to [to] is permitted by the
  /// order lifecycle rules, and `false` otherwise (including no-op self
  /// transitions, which callers may treat as invalid).
  bool isValidTransition(OrderStatus from, OrderStatus to);

  /// Returns a new [Order] with a single [OrderStatusEvent] appended for the
  /// transition to [status] (optionally carrying a [note], timestamped with
  /// [at] or the current time).
  ///
  /// The returned order's [Order.status] equals the new event's status and the
  /// appended event's timestamp is greater than or equal to the previous
  /// event's. Implementations must throw (or otherwise reject) when the
  /// transition is not a [isValidTransition], leaving [order] unchanged.
  Order appendStatusEvent(
    Order order,
    OrderStatus status, {
    String? note,
    DateTime? at,
  });

  /// Notification hook invoked when a new pre-order is created, so the company
  /// admins can be alerted of incoming work.
  Future<void> notifyAdminsOfNewOrder(Order order);

  /// Notification hook invoked when an order's status changes, so the owning
  /// client can be alerted of the update.
  Future<void> notifyClientOfStatusChange(Order order, OrderStatus status);
}
