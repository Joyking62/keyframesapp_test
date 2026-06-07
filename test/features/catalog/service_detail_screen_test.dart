// Widget test for the service-detail "Pre-Order" CTA (Task 17.2).
//
// Verifies the user-visible contract of [ServiceDetailScreen]'s sticky bottom
// call-to-action: once the listing has loaded, the gradient "Pre-Order" button
// is shown, and tapping it navigates into the pre-order flow for the selected
// listing (Requirement 7.4).
//
// Test design notes:
//   * The screen watches [serviceByIdProvider] (a `FutureProvider.family` keyed
//     by id). We override that provider for the `'test-id'` key so the detail
//     resolves to a known [ServiceListing] without any Firebase access.
//   * The CTA calls `context.push(KRoutes.preorder, extra: listing)`, which
//     requires a real router in the tree. We host the screen inside a minimal
//     [GoRouter] exposing the detail route and a `'/preorder'` probe screen, so
//     tapping the CTA actually navigates and we can assert the destination.
//   * The CTA bar runs an INFINITE looping "pulse" glow animation, so
//     `pumpAndSettle()` would never converge. We therefore advance frames with
//     explicit `pump(Duration)` calls instead of settling.
//   * The sample listing uses a null `thumbnailUrl` and empty gallery so no
//     network image is fetched during the test.
//
// Validates: Requirements 7.4

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/widgets/k_primary_button.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/features/catalog/catalog_controller.dart';
import 'package:keyframes_app/features/catalog/service_detail_screen.dart';

void main() {
  const String serviceId = 'test-id';

  // A fully-populated sample listing with NO remote imagery (null thumbnail,
  // empty gallery) so the widget tree builds without any network fetch.
  const ServiceListing sampleListing = ServiceListing(
    id: serviceId,
    title: 'Logo Creation',
    tagline: 'A mark that sticks',
    description: 'Three concepts, unlimited revisions, vector delivery.',
    category: ServiceCategory.graphicDesign,
    basePrice: 199,
    deliverables: <String>['Three concepts', 'Vector source files'],
    estimatedDays: 5,
  );

  /// Builds a minimal GoRouter that starts on the detail screen and exposes a
  /// `'/preorder'` probe destination so navigation from the CTA is observable.
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: KRoutes.serviceDetailPath(serviceId),
      routes: <RouteBase>[
        GoRoute(
          path: KRoutes.serviceDetailPath(serviceId),
          builder: (BuildContext context, GoRouterState state) =>
              const ServiceDetailScreen(serviceId: serviceId),
        ),
        GoRoute(
          path: KRoutes.preorder,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(
            body: Center(child: Text('PreOrder Page')),
          ),
        ),
      ],
    );
  }

  /// Pumps the detail screen inside a ProviderScope whose
  /// [serviceByIdProvider] is overridden to resolve to [sampleListing], then
  /// advances frames until the loaded state (and its sticky CTA) is shown.
  Future<GoRouter> pumpDetail(WidgetTester tester) async {
    final GoRouter router = buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          serviceByIdProvider(serviceId).overrideWith(
            (ref) async => sampleListing,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    // Resolve the overridden future and rebuild into the `data` state.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    return router;
  }

  testWidgets(
      'shows the sticky "Pre-Order" CTA once the listing loads and tapping it '
      'navigates to the pre-order flow', (WidgetTester tester) async {
    await pumpDetail(tester);

    // The loaded detail renders its title and the sticky CTA.
    expect(find.text('Logo Creation'), findsOneWidget);
    expect(find.byType(KPrimaryButton), findsOneWidget);
    expect(find.text('Pre-Order'), findsOneWidget);
    expect(find.text('PreOrder Page'), findsNothing);

    // Tap the CTA. (Avoid pumpAndSettle: the CTA's glow animation loops
    // forever, so we advance frames enough for the route transition instead.)
    await tester.tap(find.byType(KPrimaryButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // The pre-order probe destination is now on screen, confirming the CTA
    // opened the pre-order flow (Requirement 7.4).
    expect(find.text('PreOrder Page'), findsOneWidget);
  });

  testWidgets(
      'the "Pre-Order" CTA is present and enabled after the listing loads',
      (WidgetTester tester) async {
    await pumpDetail(tester);

    // The CTA button exists and exposes its label.
    final Finder cta = find.byType(KPrimaryButton);
    expect(cta, findsOneWidget);
    expect(find.text('Pre-Order'), findsOneWidget);

    // It is enabled: a non-null onPressed is wired (it carries a real callback
    // that pushes the pre-order route).
    final KPrimaryButton button = tester.widget<KPrimaryButton>(cta);
    expect(button.onPressed, isNotNull);
    expect(button.loading, isFalse);
  });
}
