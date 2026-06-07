import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/register_input.dart';
import 'package:keyframes_app/data/repositories/auth_repository.dart';

/// Firebase-backed implementation of [AuthRepository].
///
/// Combines three Firebase services:
///
/// * **firebase_auth** — credential/session management (email-password, Google).
/// * **cloud_firestore** — the `users/{uid}` profile documents that hold the
///   user's name/phone/photo and, crucially, their [UserRole]. The role is the
///   single source of truth resolved on every sign-in (Requirement 4.4).
/// * **google_sign_in** — the Google OAuth flow exchanged for a Firebase
///   credential (Requirement 4.3).
///
/// Role is **always** resolved from the profile document and defaults to
/// [UserRole.client] when absent. Registration and first-time Google sign-in
/// only ever create `client` profiles — no role selector or admin sign-up is
/// exposed to clients (Requirement 4.8).
class FirebaseAuthRepository implements AuthRepository {
  /// Creates a [FirebaseAuthRepository].
  ///
  /// Dependencies default to the global Firebase singletons but can be injected
  /// (e.g. fakes/mocks) for testing.
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Name of the Firestore collection holding user profile documents.
  static const String usersCollection = 'users';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(usersCollection);

  @override
  Stream<AppUser?> authState() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return _resolveAppUser(user);
    });
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Sign-in succeeded but no user was returned.',
      );
    }
    return _resolveAppUser(user);
  }

  @override
  Future<AppUser> register(RegisterInput input) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: input.email.trim(),
      password: input.password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'registration-failed',
        message: 'Registration succeeded but no user was returned.',
      );
    }

    // Keep the Firebase Auth display name in sync with the profile (best
    // effort; failures here must not abort registration).
    await user.updateDisplayName(input.name);

    // Always create a `client`-role profile document — role selection and admin
    // sign-up are never exposed (Requirement 4.2, 4.8).
    final appUser = AppUser(
      id: user.uid,
      name: input.name,
      email: input.email.trim(),
      phone: input.phone,
      photoUrl: user.photoURL,
      role: UserRole.client,
      createdAt: DateTime.now().toUtc(),
    );

    await _users.doc(user.uid).set(_toDoc(appUser));
    return appUser;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // The user dismissed the Google account picker.
      throw FirebaseAuthException(
        code: 'sign-in-cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google sign-in succeeded but no user was returned.',
      );
    }

    // First Google sign-in => provision a `client` profile document; otherwise
    // load and resolve the existing profile (Requirement 4.3, 4.4).
    final docRef = _users.doc(user.uid);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      return _userFromDoc(user.uid, snapshot.data(), fallback: user);
    }

    final appUser = AppUser(
      id: user.uid,
      name: user.displayName ?? googleUser.displayName ?? '',
      email: user.email ?? googleUser.email,
      phone: user.phoneNumber,
      photoUrl: user.photoURL ?? googleUser.photoUrl,
      role: UserRole.client,
      createdAt: DateTime.now().toUtc(),
    );
    await docRef.set(_toDoc(appUser));
    return appUser;
  }

  @override
  Future<void> signOut() async {
    // Sign out of both providers so a subsequent Google sign-in re-prompts for
    // account selection (Requirement 4.7). Disconnecting Google is best-effort
    // and must not block ending the Firebase session.
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  Future<AppUser?> currentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _resolveAppUser(user);
  }

  // --------------------------------------------------------------------------
  // Mapping helpers
  // --------------------------------------------------------------------------

  /// Loads the Firestore profile for [user] and resolves it to an [AppUser],
  /// falling back to the Firebase Auth record's fields where the document is
  /// missing values (or the document itself does not exist yet).
  Future<AppUser> _resolveAppUser(User user) async {
    final snapshot = await _users.doc(user.uid).get();
    return _userFromDoc(user.uid, snapshot.data(), fallback: user);
  }

  /// Converts a Firestore user document [data] into an [AppUser].
  ///
  /// Role defaults to [UserRole.client] when the `role` field is missing or
  /// unrecognized. `createdAt` accepts either a Firestore [Timestamp] or an ISO
  /// 8601 string for forward/backward compatibility. The optional [fallback]
  /// Firebase Auth user supplies name/email/photo when the document omits them
  /// (e.g. a partially provisioned profile).
  AppUser _userFromDoc(
    String uid,
    Map<String, dynamic>? data, {
    User? fallback,
  }) {
    final map = data ?? const <String, dynamic>{};
    return AppUser(
      id: uid,
      name: (map['name'] as String?) ?? fallback?.displayName ?? '',
      email: (map['email'] as String?) ?? fallback?.email ?? '',
      phone: (map['phone'] as String?) ?? fallback?.phoneNumber,
      photoUrl: (map['photoUrl'] as String?) ?? fallback?.photoURL,
      role: _roleFromValue(map['role']),
      createdAt: _dateFromValue(map['createdAt']),
    );
  }

  /// Serializes an [AppUser] into a Firestore document map.
  ///
  /// `createdAt` is stored as a Firestore [Timestamp] for native ordering and
  /// querying; `role` is stored as its enum name string.
  Map<String, dynamic> _toDoc(AppUser user) {
    return <String, dynamic>{
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'photoUrl': user.photoUrl,
      'role': user.role.name,
      'createdAt': Timestamp.fromDate(user.createdAt),
    };
  }

  /// Resolves a stored `role` value to a [UserRole], defaulting to
  /// [UserRole.client] when absent or unrecognized (Requirement 4.4).
  UserRole _roleFromValue(Object? value) {
    if (value is String) {
      for (final role in UserRole.values) {
        if (role.name == value) return role;
      }
    }
    return UserRole.client;
  }

  /// Resolves a stored `createdAt` value (Firestore [Timestamp] or ISO string)
  /// to a [DateTime], defaulting to "now" when absent or unparseable.
  DateTime _dateFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }
}
