import 'package:flutter_test/flutter_test.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_draft.dart';
import 'package:keyframes_app/data/models/order_status_event.dart';
import 'package:keyframes_app/features/order/default_order_service.dart';

void main() {
  const DefaultOrderService service = DefaultOrderService();
  final DateTime base = DateTime.utc(2024, 1, 1, 12);

  Order pendingOrder({
    OrderStatus status = OrderStatus.pending,
    DateTime? createdAt,
    List<OrderStatusEvent>? timeline,
  }) {
    final DateTime created = createdAt ?? base;
    return Order(
      id: 'order-1',
      clientId: 'client-1',
      serviceId: 'service-1',
      serviceTitle: 'Logo Design',
      packageTier: PackageTier.standard,
      requirements: 'A clean modern logo for my brand.',
      status: status,
      createdAt: created,
      timeline: timeline ??
          <OrderStatusEvent>[
            OrderStatusEvent(status: status, at: created),
          ],
    );
  }

  OrderDraft draft({
    String requirements = 'A clean modern logo for my startup brand.',
    DateTime? deadline,
  }) {
    return OrderDraft(
      serviceId: 'service-1',
      serviceTitle: 'Logo Design',
      packageTier: PackageTier.premium,
      requirements: requirements,
      deadline: deadline,
    );
  }

  group('isValidTransition (Task 6.1, Req 10A.4)', () {
    test('permits the forward lifecycle chain', () {
      expect(
        service.isValidTransition(OrderStatus.pending, OrderStatus.inReview),
        isTrue,
      );
      expect(
        service.isValidTransition(OrderStatus.inReview, OrderStatus.inProgress),
        isTrue,
      );
      expect(
        service.isValidTransition(
            OrderStatus.inProgress, OrderStatus.completed),
        isTrue,
      );
    });

    test('permits cancelling from any non-completed status', () {
      expect(
        service.isValidTransition(OrderStatus.pending, OrderStatus.cancelled),
        isTrue,
      );
      expect(
        service.isValidTransition(OrderStatus.inReview, OrderStatus.cancelled),
        isTrue,
      );
      expect(
        service.isValidTransition(
            OrderStatus.inProgress, OrderStatus.cancelled),
        isTrue,
      );
    });

    test('rejects self-transitions', () {
      for (final OrderStatus s in OrderStatus.values) {
        expect(service.isValidTransition(s, s), isFalse, reason: '$s -> $s');
      }
    });

    test('rejects skipping, going backwards, and leaving terminal states', () {
      expect(
        service.isValidTransition(OrderStatus.pending, OrderStatus.completed),
        isFalse,
      );
      expect(
        service.isValidTransition(OrderStatus.inProgress, OrderStatus.pending),
        isFalse,
      );
      expect(
        service.isValidTransition(OrderStatus.completed, OrderStatus.cancelled),
        isFalse,
      );
      expect(
        service.isValidTransition(OrderStatus.cancelled, OrderStatus.inReview),
        isFalse,
      );
    });
  });

  group('appendStatusEvent (Task 6.1, Req 10A.1/10A.2/10A.3)', () {
    test('appends an event and keeps status == timeline.last.status', () {
      final Order order = pendingOrder();
      final Order next = service.appendStatusEvent(
        order,
        OrderStatus.inReview,
        note: 'Triaging',
        at: base.add(const Duration(hours: 1)),
      );

      expect(next.status, OrderStatus.inReview);
      expect(next.timeline.length, 2);
      expect(next.status, next.timeline.last.status);
      expect(next.timeline.last.note, 'Triaging');
    });

    test('clamps the timestamp so the timeline is non-decreasing', () {
      final Order order = pendingOrder();
      final Order next = service.appendStatusEvent(
        order,
        OrderStatus.inReview,
        at: base.subtract(const Duration(days: 5)),
      );

      // The earlier requested timestamp is clamped up to the previous event's.
      expect(next.timeline.last.at, base);
      expect(next.timeline.last.at.isBefore(order.timeline.last.at), isFalse);
    });

    test('throws and does not mutate the input on an illegal transition', () {
      final Order order = pendingOrder();
      expect(
        () => service.appendStatusEvent(order, OrderStatus.completed),
        throwsA(isA<InvalidOrderTransitionException>()),
      );
      // Input is unchanged.
      expect(order.status, OrderStatus.pending);
      expect(order.timeline.length, 1);
    });
  });

  group('validateDraft (Task 6.2, Req 8.4)', () {
    test('accepts a well-formed draft', () {
      final DraftValidationResult result =
          service.validateDraft(draft(), now: base);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('rejects requirements shorter than 10 characters', () {
      final DraftValidationResult result =
          service.validateDraft(draft(requirements: 'too short'), now: base);
      expect(result.isValid, isFalse);
      expect(result.messageFor(DraftField.requirements), isNotNull);
    });

    test('rejects a deadline that is not in the future', () {
      final DraftValidationResult result = service.validateDraft(
        draft(deadline: base.subtract(const Duration(days: 1))),
        now: base,
      );
      expect(result.isValid, isFalse);
      expect(result.messageFor(DraftField.deadline), isNotNull);
    });

    test('accepts a null (unset) deadline', () {
      final DraftValidationResult result =
          service.validateDraft(draft(), now: base);
      expect(result.messageFor(DraftField.deadline), isNull);
    });
  });

  group('buildInitialOrder (Task 6.2, Req 8.6)', () {
    test('creates a pending order with a single pending timeline event', () {
      final Order order = service.buildInitialOrder(
        id: 'order-99',
        clientId: 'client-7',
        draft: draft(deadline: base.add(const Duration(days: 7))),
        now: base,
      );

      expect(order.id, 'order-99');
      expect(order.clientId, 'client-7');
      expect(order.serviceId, 'service-1');
      expect(order.packageTier, PackageTier.premium);
      expect(order.status, OrderStatus.pending);
      expect(order.timeline.length, 1);
      expect(order.timeline.single.status, OrderStatus.pending);
      expect(order.timeline.single.at, order.createdAt);
      expect(order.status, order.timeline.last.status);
    });

    test('throws DraftValidationException for an invalid draft', () {
      expect(
        () => service.buildInitialOrder(
          id: 'order-99',
          clientId: 'client-7',
          draft: draft(requirements: 'short'),
          now: base,
        ),
        throwsA(isA<DraftValidationException>()),
      );
    });
  });
}
