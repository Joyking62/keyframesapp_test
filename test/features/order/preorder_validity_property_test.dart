// Property-based test for the pre-order validity correctness property.
//
// Property 4: Pre-order validity
//   For every created Order:
//     requirements.length >= 10
//     AND (deadline == null OR deadline > createdAt)
//     AND packageTier != null
//
// Restated as the contract of `DefaultOrderService.buildInitialOrder`: it
// succeeds *if and only if* the draft is valid per an independent oracle, and
// every Order it returns satisfies the invariants above. When the draft is
// invalid it must throw `DraftValidationException` and create no Order.
//
// The independent oracle mirrors the design's validation rules WITHOUT reusing
// the service's own branching, so the test cross-checks the implementation
// rather than restating it:
//   valid  <=>  requirements.trim().length >= 10
//               AND (deadline == null OR deadline.isAfter(now))
// (`packageTier` is statically non-nullable on `OrderDraft`, so "a tier is
// selected" is guaranteed by construction and is asserted on every result.)
//
// Validates: Requirements 8.4, 8.6
//
// The generators deliberately straddle every boundary:
//   * requirements lengths span 0..25, covering both < 10 and >= 10 (and the
//     exact 9/10 boundary);
//   * deadlines are null, in the past, exactly equal to `now` (which is NOT
//     "in the future" and so must be rejected), and in the future, relative to
//     an injected, fixed `now`;
//   * packageTier ranges over every enum variant.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart';

import 'package:keyframes_app/core/utils/validators.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_draft.dart';
import 'package:keyframes_app/features/order/default_order_service.dart';

// ---------------------------------------------------------------------------
// Record combinators (lifted from glados' `combine2`, mirroring the helper
// style used in the serialization property test) so each draft generator is a
// flat mapping from a positional record onto `OrderDraft`.
// ---------------------------------------------------------------------------

Generator<(A, B)> _r2<A, B>(Generator<A> a, Generator<B> b) =>
    any.combine2(a, b, (A x, B y) => (x, y));

Generator<(A, B, C)> _r3<A, B, C>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
) =>
    any.combine2(_r2(a, b), c, ((A, B) p, C z) => (p.$1, p.$2, z));

Generator<(A, B, C, D)> _r4<A, B, C, D>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
) =>
    any.combine2(
      _r3(a, b, c),
      d,
      ((A, B, C) p, D z) => (p.$1, p.$2, p.$3, z),
    );

Generator<(A, B, C, D, E)> _r5<A, B, C, D, E>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
  Generator<E> e,
) =>
    any.combine2(
      _r4(a, b, c, d),
      e,
      ((A, B, C, D) p, E z) => (p.$1, p.$2, p.$3, p.$4, z),
    );

// ---------------------------------------------------------------------------
// Fixed reference clock.
//
// `buildInitialOrder` is always invoked with this `now`, and (because we omit
// an explicit `createdAt`) the resulting Order's `createdAt` equals it. The
// deadline generator is expressed as a millisecond offset from this instant so
// "past / equal / future" are exercised deterministically.
// ---------------------------------------------------------------------------

final DateTime _now = DateTime.utc(2024, 6, 1, 12);

/// A wide window (~120 days) for deadline offsets, in milliseconds.
const int _offsetSpanMs = 1000 * 60 * 60 * 24 * 120;

// ---------------------------------------------------------------------------
// Field generators.
//
// Derived from glados' core `any.int` primitive. Dart's `%` with a positive
// divisor yields a non-negative result even for negative seeds, so the bounded
// lengths and enum indices below are always in range.
// ---------------------------------------------------------------------------

/// Requirements text of length 0..25 (plain ASCII, so `trim().length` equals
/// `length`). This spans both sides of the 10-character minimum and hits the
/// exact 9/10 boundary.
final Generator<String> _requirements =
    any.int.map((int i) => 'r' * (i % 26));

/// Deadline relative to [_now]:
///   * ~1 in 4 -> null (deadline omitted, which is valid);
///   * otherwise an offset in [-_offsetSpanMs, +_offsetSpanMs], so the result
///     can be in the past, exactly `_now` (offset 0 -> NOT in the future ->
///     invalid), or in the future.
final Generator<DateTime?> _deadline = any.int.map((int i) {
  if (i % 4 == 0) {
    return null;
  }
  final int offsetMs = (i % (2 * _offsetSpanMs + 1)) - _offsetSpanMs;
  return _now.add(Duration(milliseconds: offsetMs));
});

/// Every package tier variant (the field is non-nullable on the draft).
final Generator<PackageTier> _packageTier =
    any.int.map((int i) => PackageTier.values[i % PackageTier.values.length]);

final Generator<String> _serviceId = any.int.map((int i) => 'svc_$i');
final Generator<String> _serviceTitle = any.int.map((int i) => 'Service $i');

final Generator<OrderDraft> _anyDraft = _r5(
  _requirements,
  _deadline,
  _packageTier,
  _serviceId,
  _serviceTitle,
).map(
  (t) => OrderDraft(
    serviceId: t.$4,
    serviceTitle: t.$5,
    packageTier: t.$3,
    requirements: t.$1,
    deadline: t.$2,
  ),
);

/// Independent oracle for draft validity, derived directly from the design's
/// pre-order rules rather than from the service implementation.
bool _oracleValid(OrderDraft draft, DateTime now) {
  final bool requirementsOk =
      draft.requirements.trim().length >= Validators.requirementsMin;
  final bool deadlineOk =
      draft.deadline == null || draft.deadline!.isAfter(now);
  return requirementsOk && deadlineOk;
}

void main() {
  const DefaultOrderService service = DefaultOrderService();

  group('Pre-order validity (Property 4 - Requirements 8.4, 8.6)', () {
    Glados<OrderDraft>(_anyDraft).test(
      'buildInitialOrder succeeds IFF the draft is valid, and every created '
      'Order satisfies the pre-order invariants',
      (OrderDraft draft) {
        final bool expectedValid = _oracleValid(draft, _now);

        if (expectedValid) {
          final Order order = service.buildInitialOrder(
            id: 'order_1',
            clientId: 'client_1',
            draft: draft,
            now: _now,
          );

          // Invariant: requirements.length >= 10.
          expect(
            order.requirements.length,
            greaterThanOrEqualTo(Validators.requirementsMin),
          );

          // Invariant: deadline == null OR deadline > createdAt.
          if (order.deadline != null) {
            expect(order.deadline!.isAfter(order.createdAt), isTrue);
          }

          // Invariant: a package tier is selected (non-null).
          expect(order.packageTier, isNotNull);
          expect(PackageTier.values, contains(order.packageTier));

          // Invariant: a fresh order is pending with exactly one pending event.
          expect(order.status, OrderStatus.pending);
          expect(order.timeline, hasLength(1));
          expect(order.timeline.single.status, OrderStatus.pending);
          expect(order.timeline.single.at, order.createdAt);
        } else {
          // Invalid drafts must be rejected; no Order is constructed.
          expect(
            () => service.buildInitialOrder(
              id: 'order_1',
              clientId: 'client_1',
              draft: draft,
              now: _now,
            ),
            throwsA(isA<DraftValidationException>()),
          );
        }
      },
    );
  });

  group('Pre-order validity - explicit boundary examples', () {
    OrderDraft draftWith({
      required String requirements,
      DateTime? deadline,
    }) =>
        OrderDraft(
          serviceId: 'svc',
          serviceTitle: 'Service',
          packageTier: PackageTier.standard,
          requirements: requirements,
          deadline: deadline,
        );

    test('rejects requirements of exactly 9 characters', () {
      expect(
        () => service.buildInitialOrder(
          id: 'o',
          clientId: 'c',
          draft: draftWith(requirements: 'r' * 9),
          now: _now,
        ),
        throwsA(isA<DraftValidationException>()),
      );
    });

    test('accepts requirements of exactly 10 characters with no deadline', () {
      final Order order = service.buildInitialOrder(
        id: 'o',
        clientId: 'c',
        draft: draftWith(requirements: 'r' * 10),
        now: _now,
      );
      expect(order.status, OrderStatus.pending);
      expect(order.deadline, isNull);
      expect(order.timeline.single.status, OrderStatus.pending);
    });

    test('rejects a deadline exactly equal to now (not in the future)', () {
      expect(
        () => service.buildInitialOrder(
          id: 'o',
          clientId: 'c',
          draft: draftWith(requirements: 'r' * 12, deadline: _now),
          now: _now,
        ),
        throwsA(isA<DraftValidationException>()),
      );
    });

    test('rejects a past deadline', () {
      expect(
        () => service.buildInitialOrder(
          id: 'o',
          clientId: 'c',
          draft: draftWith(
            requirements: 'r' * 12,
            deadline: _now.subtract(const Duration(days: 1)),
          ),
          now: _now,
        ),
        throwsA(isA<DraftValidationException>()),
      );
    });

    test('accepts a future deadline and records it on the order', () {
      final DateTime future = _now.add(const Duration(days: 7));
      final Order order = service.buildInitialOrder(
        id: 'o',
        clientId: 'c',
        draft: draftWith(requirements: 'r' * 12, deadline: future),
        now: _now,
      );
      expect(order.deadline, future);
      expect(order.deadline!.isAfter(order.createdAt), isTrue);
    });
  });
}
