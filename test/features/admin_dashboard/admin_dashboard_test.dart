import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_draft.dart';
import 'package:keyframes_app/data/models/order_status_event.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/data/repositories/order_repository.dart';
import 'package:keyframes_app/data/repositories/service_repository.dart';
import 'package:keyframes_app/features/admin_dashboard/admin_listings_screen.dart';
import 'package:keyframes_app/features/admin_dashboard/admin_orders_screen.dart';

/// Widget tests for the admin dashboard's orders-management and
/// listings-management screens (Requirements 11.3, 11.6).
///
/// These tests run entirely against in-memory Riverpod overrides — no Firebase,
/// network, or Hive cache is touched. Hand-written fakes record the mutating
/// calls the screens make:
///
/// * [FakeOrderRepository] streams a single pending order and records every
///   `updateStatus` call, so we can assert the admin's status change is routed
///   through [OrderRepository.updateStatus] (Requirement 11.3). The real
///   [DefaultOrderService] (via the un-overridden `orderServiceProvider`)
///   computes the valid next statuses, so the test also exercises the genuine
///   transition rules (`pending -> inReview`/`cancelled`).
/// * [FakeServiceRepository] streams a single active listing and records every
///   `setActive` call, so we can assert toggling the per-row switch persists
///   through [ServiceRepository.setActive] (Requirement 11.6).
void main() {
  // An admin user injected via [currentUserProvider] so no real auth/Firebase
  // session is ever resolved.
  final AppUser adminUser = AppUser(
    id: 'admin-1',
    name: 'Grace Hopper',
    email: 'grace@keyframes.dev',
    role: UserRole.admin,
    createdAt: DateTime(2024, 1, 1),
  );

  /// A single pending order. Valid next statuses for `pending` (computed by the
  /// real order service) are `inReview` and `cancelled`.
  final Order pendingOrder = Order(
    id: 'order-1',
    clientId: 'client-1',
    serviceId: 'service-1',
    serviceTitle: 'Flutter App Build',
    packageTier: PackageTier.standard,
    requirements: 'Build a cross-platform mobile app for our brand.',
    status: OrderStatus.pending,
    timeline: <OrderStatusEvent>[
      OrderStatusEvent(
        status: OrderStatus.pending,
        note: 'Pre-order received',
        at: DateTime(2024, 2, 1),
      ),
    ],
    createdAt: DateTime(2024, 2, 1),
  );

  /// A single active listing whose per-row switch starts in the "on" position.
  const ServiceListing activeListing = ServiceListing(
    id: 'listing-1',
    title: 'Brand Logo Design',
    tagline: 'A logo that pops',
    description: 'Custom logo design for your brand.',
    category: ServiceCategory.graphicDesign,
    basePrice: 300,
  );

  /// Hosts [child] under a [ProviderScope] with [overrides], wrapped in a
  /// [MaterialApp] and an inner [MediaQuery] that disables animations so the
  /// staggered list entrance reveals instantly (no pending delay timers).
  Widget host(Widget child, List<Override> overrides) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets(
      'admin status change is routed through OrderRepository.updateStatus '
      '(Requirement 11.3)', (WidgetTester tester) async {
    final FakeOrderRepository fakeOrders =
        FakeOrderRepository(<Order>[pendingOrder]);

    await tester.pumpWidget(
      host(
        const AdminOrdersScreen(),
        <Override>[
          currentUserProvider.overrideWithValue(adminUser),
          orderRepositoryProvider.overrideWithValue(fakeOrders),
          // orderServiceProvider intentionally left at its real default so the
          // genuine transition rules drive the valid-next-status choices.
        ],
      ),
    );
    // Let the Stream.value emit and the order card render.
    await tester.pump();

    // Open the per-order status-update sheet.
    expect(find.widgetWithText(TextButton, 'Update status'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Update status'));
    await tester.pumpAndSettle();

    // The sheet offers only the valid next statuses for a pending order.
    // 'In Review' also appears in the status filter bar behind the sheet, so we
    // target the ChoiceChip specifically.
    final Finder inReviewChip =
        find.widgetWithText(ChoiceChip, 'In Review');
    expect(inReviewChip, findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Cancelled'), findsOneWidget);

    await tester.tap(inReviewChip);
    await tester.pump();

    // Apply the update.
    await tester.tap(find.text('Apply update'));
    await tester.pumpAndSettle();

    // The change was routed through the repository with the chosen status.
    expect(fakeOrders.updateStatusCalls, hasLength(1));
    final UpdateStatusCall call = fakeOrders.updateStatusCalls.single;
    expect(call.id, pendingOrder.id);
    expect(call.status, OrderStatus.inReview);

    // Flush the success SnackBar's auto-dismiss timer so no timer is pending at
    // teardown.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'toggling a listing off persists through ServiceRepository.setActive '
      '(Requirement 11.6)', (WidgetTester tester) async {
    final FakeServiceRepository fakeServices =
        FakeServiceRepository(<ServiceListing>[activeListing]);

    await tester.pumpWidget(
      host(
        const AdminListingsScreen(),
        <Override>[
          currentUserProvider.overrideWithValue(adminUser),
          serviceRepositoryProvider.overrideWithValue(fakeServices),
        ],
      ),
    );
    // Let the Stream.value emit and the listing card render.
    await tester.pump();

    // The active listing renders exactly one per-row toggle, in the "on" state.
    final Finder toggle = find.byType(Switch);
    expect(toggle, findsOneWidget);
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // The toggle was persisted as inactive through the repository.
    expect(fakeServices.setActiveCalls, hasLength(1));
    final SetActiveCall call = fakeServices.setActiveCalls.single;
    expect(call.id, activeListing.id);
    expect(call.active, isFalse);
  });
}

/// A recorded [OrderRepository.updateStatus] invocation.
class UpdateStatusCall {
  const UpdateStatusCall(this.id, this.status, this.note);

  final String id;
  final OrderStatus status;
  final String? note;
}

/// In-memory [OrderRepository] fake for widget tests.
///
/// Streams the supplied [orders] from [watchAllOrders] and records every
/// [updateStatus] call, completing normally. Read methods that the
/// orders-management screen does not exercise are intentionally minimal.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository(this._orders);

  final List<Order> _orders;

  /// Every recorded [updateStatus] invocation, in call order.
  final List<UpdateStatusCall> updateStatusCalls = <UpdateStatusCall>[];

  @override
  Stream<List<Order>> watchAllOrders({OrderStatus? filter}) {
    final List<Order> result = filter == null
        ? _orders
        : _orders.where((Order o) => o.status == filter).toList();
    return Stream<List<Order>>.value(result);
  }

  @override
  Future<void> updateStatus(
    String orderId,
    OrderStatus status, {
    String? note,
  }) async {
    updateStatusCalls.add(UpdateStatusCall(orderId, status, note));
  }

  @override
  Future<Order> createOrder(OrderDraft draft) =>
      throw UnimplementedError('createOrder is not used in these tests.');

  @override
  Stream<List<Order>> watchClientOrders(String clientId) =>
      Stream<List<Order>>.empty();

  @override
  Stream<Order> watchOrder(String orderId) => Stream<Order>.empty();
}

/// A recorded [ServiceRepository.setActive] invocation.
class SetActiveCall {
  const SetActiveCall(this.id, this.active);

  final String id;
  final bool active;
}

/// In-memory [ServiceRepository] fake for widget tests.
///
/// Streams the supplied [listings] from [watchServices] and records every
/// [setActive], [upsert], and [delete] call. Read methods that the
/// listings-management screen does not exercise are intentionally minimal.
class FakeServiceRepository implements ServiceRepository {
  FakeServiceRepository(this._listings);

  final List<ServiceListing> _listings;

  /// Every recorded [setActive] invocation, in call order.
  final List<SetActiveCall> setActiveCalls = <SetActiveCall>[];

  /// Every listing passed to [upsert], in call order.
  final List<ServiceListing> upsertCalls = <ServiceListing>[];

  /// Every id passed to [delete], in call order.
  final List<String> deleteCalls = <String>[];

  @override
  Stream<List<ServiceListing>> watchServices({ServiceCategory? category}) {
    final List<ServiceListing> result = category == null
        ? _listings
        : _listings
            .where((ServiceListing s) => s.category == category)
            .toList();
    return Stream<List<ServiceListing>>.value(result);
  }

  @override
  Future<void> setActive(String id, bool active) async {
    setActiveCalls.add(SetActiveCall(id, active));
  }

  @override
  Future<String> upsert(ServiceListing listing) async {
    upsertCalls.add(listing);
    return listing.id.isEmpty ? 'generated-id' : listing.id;
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls.add(id);
  }

  @override
  Future<ServiceListing> getById(String id) =>
      throw UnimplementedError('getById is not used in these tests.');
}
