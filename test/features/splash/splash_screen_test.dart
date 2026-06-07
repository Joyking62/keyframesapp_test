// Widget test for the 3D-depth animated splash auto-navigation (Task 13.4).
//
// Verifies the user-visible navigation contract of [SplashScreen]: it renders
// its animated layers (the "KEYFRAMES" wordmark, the depth-emerging logo, the
// shimmer progress bar) while bootstrap is resolving, and then — once BOTH the
// entrance animation has completed AND [bootstrapProvider] has resolved — it
// navigates **exactly once** to the route chosen by `resolveInitialRoute`
// (Requirements 2.4, 2.5).
//
// Test design notes:
//   * [SplashScreen] issues `context.go(resolveInitialRoute(result))`, which
//     needs a real router in the tree. We host it inside a minimal [GoRouter]
//     (`MaterialApp.router`) whose initial location is `/splash` and which
//     exposes one probe destination per possible target route. Each probe is a
//     plain `Text` page so the resolved destination is directly observable.
//   * [bootstrapProvider] is overridden with a fake that resolves synchronously
//     to a known [BootstrapResult], so no Firebase / Hive / network is touched.
//     Resolving to `(seenOnboarding: false, user: null)` must land on
//     `/onboarding`; resolving to a client user must land on `/home`.
//   * [isOnlineProvider] is overridden with `Stream.value(true)` so the real
//     connectivity service (which schedules a periodic [Timer] and performs DNS
//     lookups) is never constructed — keeping the test free of pending timers.
//   * The splash runs an idle "sway" + shimmer animation that LOOPS FOREVER, so
//     `pumpAndSettle()` would never converge. We therefore advance frames with
//     explicit `pump(Duration)` calls: the entrance is ~800ms, so a couple of
//     one-second pumps comfortably cover entrance completion + the route
//     transition.
//   * After navigating, the splash subtree (and its "KEYFRAMES" wordmark) is
//     gone and the probe page is shown — confirming the transition happened and
//     that we did not somehow remain on / re-enter the splash.
//
// Validates: Requirements 2.4, 2.5

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/utils/connectivity.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/bootstrap_result.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/features/splash/splash_screen.dart';

void main() {
  // A signed-in client used by the "navigates to /home" case.
  final AppUser clientUser = AppUser(
    id: 'u-client',
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    role: UserRole.client,
    createdAt: DateTime.utc(2024, 1, 1),
  );

  /// Builds a minimal GoRouter that starts on the splash and exposes one
  /// probe destination per possible resolved route, so whichever route the
  /// splash resolves to is directly observable on screen.
  GoRouter buildRouter() {
    Widget probe(String label) => Scaffold(body: Center(child: Text(label)));

    return GoRouter(
      initialLocation: KRoutes.splash,
      routes: <RouteBase>[
        GoRoute(
          path: KRoutes.splash,
          builder: (BuildContext context, GoRouterState state) =>
              const SplashScreen(),
        ),
        GoRoute(
          path: KRoutes.onboarding,
          builder: (BuildContext context, GoRouterState state) =>
              probe('Onboarding Page'),
        ),
        GoRoute(
          path: KRoutes.login,
          builder: (BuildContext context, GoRouterState state) =>
              probe('Login Page'),
        ),
        GoRoute(
          path: KRoutes.home,
          builder: (BuildContext context, GoRouterState state) =>
              probe('Home Page'),
        ),
        GoRoute(
          path: KRoutes.adminOverview,
          builder: (BuildContext context, GoRouterState state) =>
              probe('Admin Overview Page'),
        ),
      ],
    );
  }

  /// Hosts the splash inside the probe router, overriding [bootstrapProvider]
  /// to resolve to [result] and stubbing [isOnlineProvider] so no real
  /// connectivity timer is ever scheduled.
  Future<void> pumpSplash(
    WidgetTester tester,
    BootstrapResult result,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          bootstrapProvider.overrideWith((ref) async => result),
          isOnlineProvider.overrideWith((ref) => Stream<bool>.value(true)),
        ],
        child: MaterialApp.router(
          routerConfig: buildRouter(),
        ),
      ),
    );
  }

  testWidgets(
      'renders the splash, then auto-navigates exactly once to /onboarding '
      'for a first-launch (no user, onboarding unseen) bootstrap '
      '(Requirements 2.4, 2.5)', (WidgetTester tester) async {
    await pumpSplash(
      tester,
      const BootstrapResult(seenOnboarding: false, user: null),
    );

    // First frame: the splash is on screen with its brand wordmark, and no
    // probe destination has been reached yet (entrance is still animating).
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('KEYFRAMES'), findsOneWidget);
    expect(find.text('Onboarding Page'), findsNothing);

    // Advance past the ~800ms entrance and let bootstrap resolve + the route
    // transition run. NEVER pumpAndSettle: the idle sway + shimmer loop forever.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // The splash has left for the resolved route exactly once: the onboarding
    // probe is shown and the splash (and its wordmark) is gone.
    expect(find.text('Onboarding Page'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('KEYFRAMES'), findsNothing);
  });

  testWidgets(
      'auto-navigates to /home when bootstrap resolves to a signed-in client '
      'user (Requirements 2.4, 2.5)', (WidgetTester tester) async {
    await pumpSplash(
      tester,
      BootstrapResult(seenOnboarding: true, user: clientUser),
    );

    // The splash renders first; the destination is not yet reached.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('KEYFRAMES'), findsOneWidget);
    expect(find.text('Home Page'), findsNothing);

    // Advance past the entrance + bootstrap resolution + route transition.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // The client lands on the home probe, exactly once.
    expect(find.text('Home Page'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('KEYFRAMES'), findsNothing);
  });
}
