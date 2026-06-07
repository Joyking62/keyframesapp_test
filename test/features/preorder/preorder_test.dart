// Tests for the multi-step pre-order flow's submission contract (Task 18.3).
//
// These exercise [PreOrderController.submit] — the single decision point that
// the pre-order UI funnels into — through a real [ProviderContainer], using
// the production [DefaultOrderService] (the default `orderServiceProvider`)
// and a hand-written [FakeOrderRepository] swapped in via a ProviderScope
// override on `orderRepositoryProvider`. This keeps the tests free of any
// Firebase dependency while still validating the genuine validation + success
// behaviour, and lets us assert the key negative invariant directly: that an
// invalid submission NEVER reaches `OrderRepository.createOrder`.
//
//   * Validation (Requirement 8.5): an invalid draft (requirements too short,
//     or no package tier selected) surfaces inline field errors, returns
//     `null`, leaves the submission idle (no success), and creates NO order —
//     the fake repository's `createOrder` is never called.
//   * Success (Requirement 8.8): a valid draft (>= 10 char requirements, a
//     selected tier, and a future deadline) calls `createOrder`, returns the
//     created [Order], and stores it in `state.submission` as `AsyncData`, the
//     state the screen reads to route to the order-success screen.
//
// Validates: Requirements 8.5, 8.8

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_draft.dart';
import 'package:keyframes_app/data/models/order_status_event.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/data/repositories/order_repository.dart';
import 'package:keyframes_app/features/order/default_order_service.dart';
import 'package:keyframes_app/features/preorder/preorder_controller.dart';

/// A minimal in-memory [OrderRepository] for tests.
///
/// [createOrder] records that it was invoked (and with which draft) and returns
/// a pre-seeded [orderToReturn]. The streaming/admin methods are unused by the
/// pre-order submission path and throw if exercised, so any accidental reliance
/// on them fails loudly rather than silently passing.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({required this.orderToReturn});

  /// The order returned by [createOrder] on success.
  final Order orderToReturn;

  /// Whether [createOrder] has been called at least once.
  bool createOrderCalled = false;

  /// The draft passed to the most recent [createOrder] call, if any.
  OrderDraft? lastDraft;

  @override
  Future<Order> createOrder(OrderDraft draft) async {
    createOrderCalled = true;
    lastDraft = draft;
    return orderToReturn;
  }

  @override
  Stream<List<Order>> watchClientOrders(String clientId) =>
      throw UnimplementedError();

  @override
  Stream<List<Order>> watchAllOrders({OrderStatus? filter}) =>
      throw UnimplementedError();

  @override
  Future<void> updateStatus(String orderId, OrderStatus status,
          {String? note}) =>
      throw UnimplementedError();

  @override
  Stream<Order> watchOrder(String orderId) => throw UnimplementedError();
}

void main() {
  // A sample listing the pre-order flow is scoped to. No remote imagery is
  // referenced so nothing touches the network.
  const ServiceListing listing = ServiceListing(
    id: 'svc-1',
    title: 'Logo Creation',
    tagline: 'A mark that sticks',
    description: 'Three concepts, unlimited revisions, vector delivery.',
    category: ServiceCategory.graphicDesign,
    basePrice: 199,
  );

  // The order a successful createOrder resolves to.
  final DateTime createdAt = DateTime.utc(2024, 6, 1, 12);
  final Order sampleOrder = Order(
    id: 'order-1',
    clientId: 'client-1',
    serviceId: listing.id,
    serviceTitle: listing.title,
    packageTier: PackageTier.standard,
    requirements: 'A detailed 60-second promo video for my brand launch.',
    status: OrderStatus.pending,
    timeline: <OrderStatusEvent>[
      OrderStatusEvent(
        status: OrderStatus.pending,
        note: DefaultOrderService.initialStatusNote,
        at: createdAt,
      ),
    ],
    createdAt: createdAt,
  );

  /// Builds a [ProviderContainer] wiring the real order service and the
  /// [fake] repository, keeps the autoDispose pre-order controller alive for
  /// the duration of the test, and disposes everything on teardown.
  ProviderContainer makeContainer(FakeOrderRepository fake) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        orderRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    // Subscribe so the autoDispose family provider is not torn down between
    // our reads.
    final ProviderSubscription<PreOrderState> sub =
        container.listen<PreOrderState>(
      preOrderControllerProvider(listing),
      (_, __) {},
    );
    addTearDown(sub.close);
    return container;
  }

  PreOrderController controllerOf(ProviderContainer container) =>
      container.read(preOrderControllerProvider(listing).notifier);

  PreOrderState stateOf(ProviderContainer container) =>
      container.read(preOrderControllerProvider(listing));

  group('PreOrderController.submit - validation (Requirement 8.5)', () {
    test(
        'requirements shorter than 10 chars: returns null, surfaces an inline '
        'error, stays idle, and creates NO order', () async {
      final FakeOrderRepository fake =
          FakeOrderRepository(orderToReturn: sampleOrder);
      final ProviderContainer container = makeContainer(fake);
      final PreOrderController controller = controllerOf(container);

      // A tier IS selected (so we get past the tier guard and into full
      // draft validation), but the requirements are too short.
      controller.setPackage(PackageTier.standard);
      controller.setRequirements('too short');

      final Order? result = await controller.submit();

      expect(result, isNull, reason: 'an invalid submit must not yield an order');
      expect(fake.createOrderCalled, isFalse,
          reason: 'no order may be created when validation fails (R8.5)');

      final PreOrderState state = stateOf(container);
      // The inline, field-level error is surfaced for the UI.
      expect(state.errorFor(DraftField.requirements), isNotNull);
      // Submission stays idle: AsyncData holding null, never a success.
      expect(state.submission, isA<AsyncData<Order?>>());
      expect(state.submission.value, isNull);
      expect(state.submission.hasError, isFalse);
    });

    test(
        'no package tier selected: returns null, flags the tier, routes to the '
        'options step, and creates NO order', () async {
      final FakeOrderRepository fake =
          FakeOrderRepository(orderToReturn: sampleOrder);
      final ProviderContainer container = makeContainer(fake);
      final PreOrderController controller = controllerOf(container);

      // Valid requirements, but the user never chose a tier.
      controller.setRequirements('A perfectly long enough requirement text.');

      final Order? result = await controller.submit();

      expect(result, isNull);
      expect(fake.createOrderCalled, isFalse,
          reason: 'a draft cannot even be built without a tier (R8.5)');

      final PreOrderState state = stateOf(container);
      expect(state.errorFor(DraftField.packageTier), isNotNull);
      // The user is sent back to the options step to fix the selection.
      expect(state.step, PreOrderStep.options);
      expect(state.submission, isA<AsyncData<Order?>>());
      expect(state.submission.value, isNull);
    });
  });

  group('PreOrderController.submit - success (Requirement 8.8)', () {
    test(
        'a valid draft creates the order and exposes it via AsyncData '
        'submission', () async {
      final FakeOrderRepository fake =
          FakeOrderRepository(orderToReturn: sampleOrder);
      final ProviderContainer container = makeContainer(fake);
      final PreOrderController controller = controllerOf(container);

      controller.setRequirements(
        'A detailed 60-second promo video for my brand launch.',
      );
      controller.setPackage(PackageTier.standard);
      controller.setDeadline(DateTime.now().add(const Duration(days: 14)));

      final Order? result = await controller.submit();

      // The created order is returned to the caller (the screen routes on it).
      expect(result, same(sampleOrder));
      expect(fake.createOrderCalled, isTrue);
      // The draft handed to the repository carries the entered fields.
      expect(fake.lastDraft, isNotNull);
      expect(fake.lastDraft!.packageTier, PackageTier.standard);
      expect(fake.lastDraft!.serviceId, listing.id);

      final PreOrderState state = stateOf(container);
      // Submission settled to success holding the created order (R8.8).
      expect(state.submission, isA<AsyncData<Order?>>());
      expect(state.submission.hasError, isFalse);
      expect(state.submission.value, same(sampleOrder));
      // No residual validation errors after a clean submit.
      expect(state.errorFor(DraftField.requirements), isNull);
      expect(state.errorFor(DraftField.packageTier), isNull);
      expect(state.errorFor(DraftField.deadline), isNull);
    });
  });
}
