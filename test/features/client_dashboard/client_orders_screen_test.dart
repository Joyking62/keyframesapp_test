import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/core/widgets/k_primary_button.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_status_event.dart';
import 'package:keyframes_app/features/client_dashboard/client_dashboard_controller.dart';
import 'package:keyframes_app/features/client_dashboard/client_orders_screen.dart';

/// Widget tests for the client orders dashboard ([ClientOrdersScreen]).
///
/// The screen renders [clientOrdersProvider] — a `StreamProvider<List<Order>>`
/// that is already scoped to the signed-in client on the data layer. Because
/// the provider is overridden directly with a synchronous in-memory stream,
/// these tests never touch Firebase, auth, or the order repository: whatever
/// the override emits *is* the current client's order set, so asserting on it
/// exercises the client-scoped rendering (Requirement 10.3) and the empty-state
/// CTA (Requirement 10.5) deterministically.
///
/// The screen is hosted inside a [MaterialApp] (for Directionality / Material /
/// MediaQuery ancestors) and an inner [MediaQuery] that disables animations, so
/// the per-card [StaggeredEntrance] reveals on the first frame instead of
/// scheduling delay timers that would otherwise leave the test with pending
/// timers. Navigation from the cards / CTA uses `context.push`/`context.go`,
/// which are only invoked on tap; since these tests never tap, no router is
/// required for rendering.
///
/// Validates: Requirements 10.3, 10.5
void main() {
  // A signed-in client. The screen reads its orders from the overridden
  // provider rather than from the user, but we still inject a user so any
  // incidental read of [currentUserProvider] resolves to a real value.
  final AppUser testUser = AppUser(
    id: 'client-1',
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    createdAt: DateTime(2024, 1, 1),
  );

  /// Builds an [Order] for [testUser] with the given [status] and a single
  /// matching timeline event, keeping `status == timeline.last.status`.
  Order buildOrder({
    required String id,
    required String serviceId,
    required String serviceTitle,
    required OrderStatus status,
    PackageTier packageTier = PackageTier.standard,
  }) {
    final DateTime createdAt = DateTime(2024, 6, 1, 9);
    return Order(
      id: id,
      clientId: testUser.id,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      packageTier: packageTier,
      requirements: 'Please build the thing exactly as described here.',
      status: status,
      timeline: <OrderStatusEvent>[
        OrderStatusEvent(status: status, at: createdAt),
      ],
      createdAt: createdAt,
    );
  }

  /// Hosts [ClientOrdersScreen] under a [ProviderScope] with [overrides].
  ///
  /// The inner [MediaQuery] disables animations so the staggered card entrance
  /// reveals instantly (no pending delay timers) and content can be asserted on
  /// the first pumped frame.
  Widget host(List<Override> overrides) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const ClientOrdersScreen(),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'empty state shows the "No orders yet" message and a "Browse services" '
      'CTA when the client has no orders (Requirement 10.5)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      host(<Override>[
        currentUserProvider.overrideWithValue(testUser),
        // The signed-in client has no orders -> emit an empty list.
        clientOrdersProvider.overrideWith(
          (ref) => Stream<List<Order>>.value(const <Order>[]),
        ),
      ]),
    );
    // A single frame resolves the synchronous stream into the data state.
    await tester.pump();

    // The friendly empty state and its CTA are shown.
    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.text('Browse services'), findsOneWidget);
    expect(find.byType(KPrimaryButton), findsOneWidget);

    // No section headers render when there are no orders.
    expect(find.text('Pending'), findsNothing);
    expect(find.text('Completed'), findsNothing);
  });

  testWidgets(
      'renders the client orders grouped under their status sections '
      '(Requirement 10.3)', (WidgetTester tester) async {
    final List<Order> orders = <Order>[
      buildOrder(
        id: 'o-pending',
        serviceId: 's-app',
        serviceTitle: 'Flutter App Build',
        status: OrderStatus.pending,
      ),
      buildOrder(
        id: 'o-progress',
        serviceId: 's-logo',
        serviceTitle: 'Brand Logo Design',
        status: OrderStatus.inProgress,
      ),
      buildOrder(
        id: 'o-done',
        serviceId: 's-poster',
        serviceTitle: 'Event Poster Set',
        status: OrderStatus.completed,
      ),
      buildOrder(
        id: 'o-cancelled',
        serviceId: 's-video',
        serviceTitle: 'Promo Video Edit',
        status: OrderStatus.cancelled,
      ),
    ];

    await tester.pumpWidget(
      host(<Override>[
        currentUserProvider.overrideWithValue(testUser),
        clientOrdersProvider.overrideWith(
          (ref) => Stream<List<Order>>.value(orders),
        ),
      ]),
    );
    await tester.pump();

    // Each provided order's service title renders on its card.
    expect(find.text('Flutter App Build'), findsOneWidget);
    expect(find.text('Brand Logo Design'), findsOneWidget);
    expect(find.text('Event Poster Set'), findsOneWidget);
    expect(find.text('Promo Video Edit'), findsOneWidget);

    // The section headers appear for each status present in the data set.
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);

    // The empty state is not shown when orders exist.
    expect(find.text('No orders yet'), findsNothing);
  });
}
