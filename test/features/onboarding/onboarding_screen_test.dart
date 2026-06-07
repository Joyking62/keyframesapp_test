// Widget tests for the first-launch onboarding flow ([OnboardingScreen]).
//
// Task 14.2 verifies the *completion* contract of the onboarding screen
// (Requirement 3.3): tapping either "Skip" or, on the final page, "Get
// Started" must
//
//   1. persist the `seenOnboarding = true` flag via the injected
//      [LocalSource], and
//   2. navigate to the login route (`KRoutes.login`).
//
// The screen reaches its [LocalSource] through `localSourceProvider`, so the
// tests construct a *real* [LocalSource] backed by an in-memory
// shared_preferences store (`SharedPreferences.setMockInitialValues`) and a
// real temp-directory Hive box, then inject it via a [ProviderScope] override.
// This exercises the genuine persistence code path (no mocks of LocalSource
// itself) while keeping everything off real device storage.
//
// The screen is hosted in a `GoRouter` (`MaterialApp.router`) whose '/login'
// route renders a `Text('Login Page')` probe, so a successful `context.go`
// is observable purely through the widget tree. An inner [MediaQuery] with
// `disableAnimations: true` zeroes out the page-indicator `AnimatedContainer`
// and the parallax motion so no animation timers stay pending after
// `pumpAndSettle`.
//
// _Requirements: 3.3_

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/data/sources/local_source.dart';
import 'package:keyframes_app/features/onboarding/onboarding_screen.dart';

void main() {
  // shared_preferences' mock channel and the widget bindings both require the
  // test binding to be initialised first.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<String> catalogBox;
  late SharedPreferences preferences;
  late LocalSource localSource;

  setUpAll(() {
    // path_provider is unavailable under the pure Flutter test harness, so
    // initialise Hive against a freshly created temp directory.
    tempDir = Directory.systemTemp.createTempSync('keyframes_onboarding_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    // Fresh in-memory preferences for every test (no persisted flag yet).
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();

    // A real, freshly cleared Hive box injected into the source so init()
    // performs no real device I/O.
    catalogBox = await Hive.openBox<String>(LocalSource.catalogBoxName);
    await catalogBox.clear();

    localSource = LocalSource(catalogBox: catalogBox, preferences: preferences);
    // No-op for injected dependencies, but mirrors real production usage.
    await localSource.init();
  });

  tearDown(() async {
    await catalogBox.clear();
    await catalogBox.close();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Hosts [OnboardingScreen] inside a real [GoRouter] with a '/login' probe
  /// page, under a [ProviderScope] that injects the test [localSource].
  ///
  /// An inner [MediaQuery] disables animations so the page indicator's
  /// `AnimatedContainer` and the parallax transforms settle instantly, leaving
  /// no pending timers for `pumpAndSettle`.
  Widget buildHarness() {
    final GoRouter router = GoRouter(
      initialLocation: KRoutes.onboarding,
      routes: <RouteBase>[
        GoRoute(
          path: KRoutes.onboarding,
          builder: (BuildContext context, GoRouterState state) =>
              const OnboardingScreen(),
        ),
        GoRoute(
          path: KRoutes.login,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('Login Page')),
        ),
      ],
    );

    return ProviderScope(
      overrides: <Override>[
        localSourceProvider.overrideWithValue(localSource),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
  }

  testWidgets(
      'tapping "Skip" persists seenOnboarding and routes to login '
      '(Requirement 3.3)', (WidgetTester tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    // Onboarding is shown first; the login probe is not yet visible.
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Login Page'), findsNothing);
    expect(localSource.seenOnboarding, isFalse);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // The flag is persisted and the router has navigated to login.
    expect(localSource.seenOnboarding, isTrue);
    expect(find.text('Login Page'), findsOneWidget);
  });

  testWidgets(
      'advancing through the pages and tapping "Get Started" reaches the same '
      'outcome (Requirement 3.3)', (WidgetTester tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    // The first two pages show "Next"; tap it to advance to the last page.
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // On the final page the primary button becomes "Get Started".
    expect(find.text('Get Started'), findsOneWidget);
    expect(localSource.seenOnboarding, isFalse);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(localSource.seenOnboarding, isTrue);
    expect(find.text('Login Page'), findsOneWidget);
  });
}
