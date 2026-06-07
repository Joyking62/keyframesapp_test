import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/register_input.dart';

/// Presentation-layer controller for the authentication screens
/// (Requirements 4.1–4.7).
///
/// [AuthController] is a thin, UI-facing wrapper around the [AuthRepository]
/// that exposes the three authentication actions used by the login/register
/// screens — [signIn], [register], and [signInWithGoogle] — while modeling the
/// in-flight / success / failure lifecycle as an [AsyncValue].
///
/// ## State semantics
///
/// The controller's state is `AsyncValue<AppUser?>`:
/// * **`AsyncData(null)`** — the initial, idle state (no user resolved yet).
/// * **`AsyncLoading`** — an authentication request is in flight. The submit
///   button binds its spinner to [AsyncValue.isLoading] (Requirement 4.6).
/// * **`AsyncData(user)`** — authentication succeeded; [AppUser] (with its
///   role resolved from the profile document, Requirement 4.4) is exposed for
///   the screen to read and route on.
/// * **`AsyncError`** — authentication/validation failed; the screen reads the
///   error for inline display and plays its shake animation (Requirement 4.5).
///
/// ## No navigation side effects
///
/// By design the controller performs **no navigation**: on success it simply
/// exposes the resolved [AppUser]. The router's auth guard + role resolution
/// (or the screen reading the returned user's role) decide where to go. This
/// keeps the controller testable and free of `BuildContext` coupling.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

/// See [authControllerProvider].
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  FutureOr<AppUser?> build() => null;

  /// `true` while an authentication request is in flight.
  ///
  /// Convenience mirror of `state.isLoading` for widgets that hold a reference
  /// to the notifier (e.g. to bind a button's loading state).
  bool get isLoading => state.isLoading;

  /// Authenticates with email/password credentials (Requirement 4.1).
  ///
  /// Returns the resolved [AppUser] on success, or `null` if the request failed
  /// (in which case the error is surfaced through [state] for inline display).
  /// The email is trimmed before being forwarded to the repository.
  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue<AppUser?>.loading();
    final next = await AsyncValue.guard<AppUser?>(
      () => ref.read(authRepositoryProvider).signIn(
            email: email.trim(),
            password: password,
          ),
    );
    state = next;
    return next.valueOrNull;
  }

  /// Registers a new client account (Requirements 4.2, 4.8).
  ///
  /// The created [AppUser] always has role `client`; no role selector or admin
  /// sign-up is ever exposed. Returns the created user on success or `null` on
  /// failure (error surfaced through [state]).
  Future<AppUser?> register(RegisterInput input) async {
    state = const AsyncValue<AppUser?>.loading();
    final next = await AsyncValue.guard<AppUser?>(
      () => ref.read(authRepositoryProvider).register(input),
    );
    state = next;
    return next.valueOrNull;
  }

  /// Authenticates through Google sign-in (Requirement 4.3).
  ///
  /// Returns the resolved [AppUser] on success or `null` on failure (error
  /// surfaced through [state]).
  Future<AppUser?> signInWithGoogle() async {
    state = const AsyncValue<AppUser?>.loading();
    final next = await AsyncValue.guard<AppUser?>(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
    state = next;
    return next.valueOrNull;
  }
}
