import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/app/app.dart';
import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/bootstrap_result.dart';
import 'package:keyframes_app/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets(
      'App boots MaterialApp.router and routes via bootstrap to onboarding '
      'for a signed-out, first-launch user', (WidgetTester tester) async {
    // Override only the two top-level providers the router/splash consume so
    // the app boots without touching Firebase or the (throwing) LocalSource:
    //   * authStateProvider -> a signed-out session
    //   * bootstrapProvider -> first launch, no user
    // resolveInitialRoute(BootstrapResult()) => '/onboarding'.
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authStateProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(null),
          ),
          bootstrapProvider.overrideWith(
            (ref) async => const BootstrapResult(seenOnboarding: false),
          ),
        ],
        child: const KeyframesApp(),
      ),
    );

    // The app is a MaterialApp.router.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Let bootstrap resolve and the splash perform its one-time redirect.
    await tester.pumpAndSettle();

    // The signed-out, first-launch user lands on the real onboarding screen
    // (now wired in place of the former placeholder — task 24.1).
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Browse services'), findsOneWidget);
  });
}
