// Property-based test for the order status state machine's monotonicity
// invariant (design Correctness Property 2).
//
// Property 2: Order status monotonicity
//   For every order produced by a sequence of VALID status updates:
//     * the order's current `status` always equals the status of the most
//       recent timeline event (`order.status == order.timeline.last.status`),
//       and
//     * the timeline's timestamps are non-decreasing across the whole history
//       (each event's `at` is `>=` the previous event's `at`).
//
// Validates: Requirements 10A.2, 10A.3
//
// Strategy:
//   Starting from a freshly built `pending` order, we walk the allowed
//   transition graph
//     pending -> inReview -> inProgress -> completed
//     (any non-completed) -> cancelled
//   choosing among the valid successors of the current status at each step
//   until a terminal state (`completed`/`cancelled`) is reached or the
//   generated sequence is exhausted. Valid successors are discovered through
//   the public `isValidTransition` API so the test stays decoupled from the
//   service's private transition table.
//
//   Each step is driven by a generated `(choice, tsOffset)` pair: `choice`
//   selects which valid successor to move to, and `tsOffset` produces an
//   arbitrary `at` timestamp (deliberately allowed to fall *before* the
//   previous event's timestamp) so the service's non-decreasing clamp is
//   exercised. After every append we assert the two monotonicity invariants;
//   they must hold regardless of how "out of order" the requested timestamps
//   are.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart';

import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_status_event.dart';
import 'package:keyframes_app/features/order/default_order_service.dart';

/// The pure order lifecycle service under test.
const DefaultOrderService _service = DefaultOrderService();

/// Anchor timestamp used as the initial order's `createdAt` and the first
/// timeline event's `at`. UTC keeps comparisons unambiguous.
final DateTime _base = DateTime.utc(2024, 1, 1, 12);

/// Span (in ms) over which generated timestamp offsets range; centering the
/// modulo on zero lets offsets be negative, so some requested `at` values land
/// before the previous event (forcing the service's non-decreasing clamp).
const int _tsSpanMs = 1000 * 60 * 60 * 24 * 30; // ~30 days

/// Builds the initial `pending` order with a single `pending` timeline event,
/// mirroring how [DefaultOrderService.buildInitialOrder] seeds a new order.
Order _initialPendingOrder() => Order(
      id: 'order-1',
      clientId: 'client-1',
      serviceId: 'service-1',
      serviceTitle: 'Logo Design',
      packageTier: PackageTier.standard,
      requirements: 'A clean modern logo for my startup brand.',
      status: OrderStatus.pending,
      createdAt: _base,
      timeline: <OrderStatusEvent>[
        OrderStatusEvent(status: OrderStatus.pending, at: _base),
      ],
    );

/// The valid successor statuses of [from], discovered via the public
/// [DefaultOrderService.isValidTransition] API. Returned in a stable order so
/// `choice` selection is deterministic for a given generated value.
List<OrderStatus> _validSuccessors(OrderStatus from) => OrderStatus.values
    .where((OrderStatus to) => _service.isValidTransition(from, to))
    .toList(growable: false);

/// Maps a raw generated integer to an arbitrary `at` timestamp around [_base].
/// The result may precede the previous event's timestamp, intentionally
/// stressing the service's clamping behaviour (Requirement 10A.3).
DateTime _timestampFor(int raw) {
  final int offsetMs = (raw % _tsSpanMs) - (_tsSpanMs ~/ 2);
  return _base.add(Duration(milliseconds: offsetMs));
}

/// Asserts the order's current status matches its last timeline event and that
/// the entire timeline is non-decreasing in time.
void _assertMonotonic(Order order) {
  // Requirement 10A.2: current status == status of the most recent event.
  expect(
    order.status,
    equals(order.timeline.last.status),
    reason: 'order.status must equal timeline.last.status',
  );

  // Requirement 10A.3: timestamps are non-decreasing across the timeline.
  for (int i = 1; i < order.timeline.length; i++) {
    final DateTime prev = order.timeline[i - 1].at;
    final DateTime curr = order.timeline[i].at;
    expect(
      curr.isBefore(prev),
      isFalse,
      reason: 'timeline[$i].at ($curr) must be >= timeline[${i - 1}].at ($prev)',
    );
  }
}

/// A single generated update step: `choice` picks among valid successors and
/// `tsOffset` seeds the requested `at` timestamp.
final Generator<(int, int)> _stepGen =
    any.combine2(any.int, any.int, (int a, int b) => (a, b));

/// A random-length sequence of update steps to apply while walking the graph.
final Generator<List<(int, int)>> _stepsGen = any.list(_stepGen);

void main() {
  group('Order status monotonicity (Property 2, Requirements 10A.2, 10A.3)',
      () {
    Glados<List<(int, int)>>(_stepsGen).test(
      'a valid sequence of updates keeps status == timeline.last.status and '
      'timestamps non-decreasing',
      (List<(int, int)> steps) {
        Order order = _initialPendingOrder();

        // The freshly built order already satisfies the invariants.
        _assertMonotonic(order);

        for (final (int choice, int tsOffset) in steps) {
          final List<OrderStatus> successors = _validSuccessors(order.status);
          if (successors.isEmpty) {
            // Reached a terminal state (completed/cancelled); the walk ends.
            break;
          }

          // `% length` is always non-negative for a positive divisor, so this
          // is a safe index even for negative seeds.
          final OrderStatus next = successors[choice % successors.length];
          final DateTime at = _timestampFor(tsOffset);

          order = _service.appendStatusEvent(order, next, at: at);

          // The invariants must hold after every single append.
          _assertMonotonic(order);
        }

        // And they must still hold for the full, accumulated timeline.
        _assertMonotonic(order);
      },
    );
  });
}
