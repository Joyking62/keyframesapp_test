// Property-based test for the order status state machine's transition rules.
//
// Property 3: Valid transitions only
//   For every (current, requested) pair of `OrderStatus` values:
//     * if the transition is NOT allowed, `appendStatusEvent` must reject it by
//       throwing `InvalidOrderTransitionException` and must leave the input
//       order completely unchanged (status and timeline length identical, the
//       original instance not mutated);
//     * if the transition IS allowed, `appendStatusEvent` must succeed and
//       append exactly one event whose status equals the requested status,
//       leaving the order's `status` equal to that requested status.
//
// Validates: Requirements 10A.4
//
// Avoiding a tautology:
//   The expected verdict for each pair is computed by an INDEPENDENT oracle
//   (`_oracleAllows`) that re-encodes the allowed-transition set directly from
//   the design's English rules — it never calls `DefaultOrderService
//   .isValidTransition`. The test additionally asserts that the service's own
//   `isValidTransition` agrees with this independent oracle, so the two
//   encodings cross-check each other instead of one validating itself.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart';

import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_status_event.dart';
import 'package:keyframes_app/features/order/default_order_service.dart';

// ---------------------------------------------------------------------------
// Independent oracle of the allowed transition graph.
//
// Re-encoded straight from the design's prose so it shares no code with the
// production `DefaultOrderService`:
//
//   * Forward lifecycle: pending -> inReview -> inProgress -> completed.
//   * Cancellation: any ACTIVE (non-terminal) status -> cancelled, where the
//     active statuses are pending, inReview, and inProgress.
//   * Everything else is illegal, including no-op self transitions and any move
//     out of a terminal state (completed / cancelled).
// ---------------------------------------------------------------------------

/// The active (non-terminal) statuses from which a cancellation is permitted.
const Set<OrderStatus> _activeStatuses = <OrderStatus>{
  OrderStatus.pending,
  OrderStatus.inReview,
  OrderStatus.inProgress,
};

/// Returns whether moving `from -> to` is allowed, computed independently of
/// the production code under test.
bool _oracleAllows(OrderStatus from, OrderStatus to) {
  // No-op self transitions are never valid.
  if (from == to) return false;

  // Forward lifecycle edges.
  if (from == OrderStatus.pending && to == OrderStatus.inReview) return true;
  if (from == OrderStatus.inReview && to == OrderStatus.inProgress) return true;
  if (from == OrderStatus.inProgress && to == OrderStatus.completed) {
    return true;
  }

  // Cancellation from any active status.
  if (to == OrderStatus.cancelled && _activeStatuses.contains(from)) {
    return true;
  }

  return false;
}

// ---------------------------------------------------------------------------
// Generators.
//
// Two independent `OrderStatus` generators are combined into a pair so the
// 5 x 5 = 25 (current, requested) combinations are all reachable. Dart's `%`
// with a positive divisor is always non-negative, so negative seeds are safe.
// ---------------------------------------------------------------------------

final Generator<OrderStatus> _anyStatus =
    any.int.map((int i) => OrderStatus.values[i % OrderStatus.values.length]);

final Generator<(OrderStatus, OrderStatus)> _anyStatusPair = any.combine2(
  _anyStatus,
  _anyStatus,
  (OrderStatus a, OrderStatus b) => (a, b),
);

/// A fixed reference time so each generated order is fully deterministic.
final DateTime _createdAt = DateTime.utc(2024, 1, 1, 12);

/// Builds an order sitting in [current] with a single timeline event whose
/// status matches (so `order.status == order.timeline.last.status`, the
/// state-machine invariant the append logic preserves).
Order _orderIn(OrderStatus current) => Order(
      id: 'order_1',
      clientId: 'client_1',
      serviceId: 'service_1',
      serviceTitle: 'Logo design',
      packageTier: PackageTier.standard,
      requirements: 'Need a modern animated brand logo package.',
      status: current,
      timeline: <OrderStatusEvent>[
        OrderStatusEvent(
          status: current,
          note: 'seed',
          at: _createdAt,
        ),
      ],
      createdAt: _createdAt,
    );

void main() {
  const DefaultOrderService service = DefaultOrderService();

  group('Order transitions: valid transitions only (Requirement 10A.4)', () {
    Glados<(OrderStatus, OrderStatus)>(_anyStatusPair).test(
      'appendStatusEvent honours exactly the allowed transition graph',
      ((OrderStatus, OrderStatus) pair) {
        final OrderStatus current = pair.$1;
        final OrderStatus requested = pair.$2;
        final bool expectedAllowed = _oracleAllows(current, requested);

        // Cross-check: the service's own verdict must match the independent
        // oracle. This prevents the property below from degenerating into a
        // tautology (asserting the service against itself).
        expect(
          service.isValidTransition(current, requested),
          equals(expectedAllowed),
          reason: 'isValidTransition disagrees with the independent oracle for '
              '${current.name} -> ${requested.name}',
        );

        final Order original = _orderIn(current);
        final int originalTimelineLength = original.timeline.length;

        if (!expectedAllowed) {
          // Illegal transition: must throw and leave the input untouched.
          expect(
            () => service.appendStatusEvent(original, requested),
            throwsA(isA<InvalidOrderTransitionException>()),
            reason: 'illegal ${current.name} -> ${requested.name} should throw',
          );

          // The original order must be unchanged: same status, same timeline
          // length, and structurally equal to a freshly built snapshot.
          expect(original.status, equals(current));
          expect(original.timeline.length, equals(originalTimelineLength));
          expect(original, equals(_orderIn(current)));
        } else {
          // Legal transition: succeeds and appends exactly one event whose
          // status is the requested status, with the order's status updated.
          final Order updated = service.appendStatusEvent(
            original,
            requested,
            at: _createdAt.add(const Duration(minutes: 1)),
          );

          expect(updated.status, equals(requested));
          expect(
            updated.timeline.length,
            equals(originalTimelineLength + 1),
            reason: 'exactly one event should be appended',
          );
          expect(updated.timeline.last.status, equals(requested));

          // The input order is never mutated, even on success.
          expect(original.status, equals(current));
          expect(original.timeline.length, equals(originalTimelineLength));
        }
      },
    );
  });
}
