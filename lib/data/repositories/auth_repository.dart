import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/register_input.dart';

/// Domain contract for authentication and session management.
///
/// This is the **domain-layer** abstraction the presentation layer depends on;
/// concrete implementations (e.g. a Firebase-backed `FirebaseAuthRepository`,
/// added in a later task) live in the data layer and are injected via Riverpod
/// providers. Keeping the interface backend-agnostic lets the auth backend be
/// swapped without touching controllers or UI.
///
/// The role of the returned [AppUser] is always resolved from the user's
/// profile document; no role selector or admin sign-up is ever exposed to
/// clients (registration always yields [UserRole.client]).
abstract interface class AuthRepository {
  /// Emits the current [AppUser] whenever the authentication state changes,
  /// or `null` while no user is signed in.
  Stream<AppUser?> authState();

  /// Authenticates with email/password credentials and returns the resolved
  /// [AppUser]. Throws on invalid credentials or authentication failure.
  Future<AppUser> signIn({required String email, required String password});

  /// Registers a new client account from [input] and returns the created
  /// [AppUser] (always with role [UserRole.client]).
  Future<AppUser> register(RegisterInput input);

  /// Authenticates through Google sign-in and returns the resolved [AppUser].
  Future<AppUser> signInWithGoogle();

  /// Ends the current session.
  Future<void> signOut();

  /// Returns the currently authenticated [AppUser], or `null` if signed out.
  Future<AppUser?> currentUser();
}
