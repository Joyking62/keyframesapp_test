import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/register_input.dart';
import 'package:keyframes_app/data/repositories/auth_repository.dart';
import 'package:keyframes_app/features/auth/login_screen.dart';
import 'package:keyframes_app/features/auth/register_screen.dart';

/// Widget tests for the authentication flows (Task 15.2).
///
/// These tests exercise the user-visible auth contracts without any Firebase
/// backend: the data layer is replaced by overriding [authRepositoryProvider]
/// with a hand-written [FakeAuthRepository]. No router is needed because none
/// of the assertions depend on a successful sign-in navigating away — invalid
/// submits intentionally do not navigate, and the loading-state test keeps the
/// request in flight forever so navigation never happens.
///
/// Validates: Requirements 4.5, 4.6, 4.8
void main() {
  /// A fake [AuthRepository] whose [signIn] never completes.
  ///
  /// Returning a [Completer.future] that is never completed lets a test drive
  /// the controller into its `AsyncLoading` state and keep it there, so the
  /// in-flight loading UI (the spinner inside the primary button) can be
  /// asserted deterministically with `pump` (never `pumpAndSettle`).
  ///
  /// All other methods throw — the tests in this file never invoke them.
  late FakeAuthRepository fakeAuth;

  setUp(() {
    fakeAuth = FakeAuthRepository();
  });

  /// Pumps [screen] inside a [ProviderScope] (with the fake auth repository)
  /// and a [MaterialApp], disabling implicit animations so the entrance/shake
  /// motion does not interfere with finding widgets.
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            );
          },
          home: screen,
        ),
      ),
    );
    // Let the first frame build (the entrance animation kicks off here).
    await tester.pump();
  }

  group('LoginScreen', () {
    testWidgets(
        'invalid submit shows an inline validation error and does not navigate '
        '(Requirement 4.5)', (WidgetTester tester) async {
      await pumpScreen(tester, const LoginScreen());

      // Leave email & password empty and submit.
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      // Allow the Form to validate and rebuild the fields with their errors.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // An inline validation error from Validators.email is shown.
      expect(find.text('Email is required.'), findsOneWidget);

      // No navigation occurred: we are still on the LoginScreen and its
      // submit button is still present.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets(
        'shows a loading spinner in the submit button while sign-in is '
        'in flight (Requirement 4.6)', (WidgetTester tester) async {
      await pumpScreen(tester, const LoginScreen());

      // Enter valid credentials so validation passes and signIn is invoked.
      final Finder fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'user@example.com');
      await tester.enterText(fields.at(1), 'password123');

      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));

      // signIn() returns a never-completing future, so the controller stays in
      // AsyncLoading. Pump (NOT pumpAndSettle) to advance the button's
      // morph into its spinner state.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The primary button now shows its loading spinner and hides the label.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);
    });
  });

  group('RegisterScreen', () {
    testWidgets(
        'exposes no role selector or admin sign-up control (Requirement 4.8)',
        (WidgetTester tester) async {
      await pumpScreen(tester, const RegisterScreen());

      // The register screen is the client sign-up surface.
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      // There is no role chooser: no dropdown and no "Admin" affordance.
      expect(find.byType(DropdownButton), findsNothing);
      expect(find.byType(DropdownButtonFormField), findsNothing);
      expect(find.text('Admin'), findsNothing);
      expect(find.text('Administrator'), findsNothing);
      expect(find.text('Role'), findsNothing);
    });
  });
}

/// A fake [AuthRepository] used to drive the auth UI in tests.
///
/// [signIn] deliberately returns a future that never completes so the
/// controller can be observed in its loading state; every other member throws
/// because no test in this file exercises them.
class FakeAuthRepository implements AuthRepository {
  final Completer<AppUser> _neverCompletes = Completer<AppUser>();

  @override
  Stream<AppUser?> authState() => const Stream<AppUser?>.empty();

  @override
  Future<AppUser> signIn({required String email, required String password}) {
    // Intentionally never completes — keeps the controller in AsyncLoading.
    return _neverCompletes.future;
  }

  @override
  Future<AppUser> register(RegisterInput input) =>
      throw UnimplementedError('register is not used in these tests');

  @override
  Future<AppUser> signInWithGoogle() =>
      throw UnimplementedError('signInWithGoogle is not used in these tests');

  @override
  Future<void> signOut() =>
      throw UnimplementedError('signOut is not used in these tests');

  @override
  Future<AppUser?> currentUser() async => null;
}
