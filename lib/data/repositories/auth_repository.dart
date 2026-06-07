import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_config.dart';
import '../models/models.dart';

/// Auth abstraction so the rest of the app never talks to Firebase directly.
abstract class AuthRepository {
  /// Emits the signed-in user (or null when signed out).
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> signIn(String email, String password, {bool asAdmin = false});

  Future<AppUser> register(String name, String email, String password);

  Future<void> signOut();
}

/// ---- Demo implementation (no backend) ----
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<AppUser> signIn(String email, String password,
      {bool asAdmin = false}) async {
    await Future.delayed(const Duration(milliseconds: 700));
    _user = AppUser(
      id: 'demo-uid',
      name: asAdmin ? 'Keyframes Admin' : 'Alex Morgan',
      email: email,
      role: asAdmin ? UserRole.admin : UserRole.client,
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> register(String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 700));
    _user = AppUser(id: 'demo-uid', name: name, email: email);
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }
}

/// ---- Firebase implementation ----
///
/// Profile data (display name + role) lives in `users/{uid}`. Admin access is
/// granted by setting `role: "admin"` on that document in the Firebase console
/// (the in-app "Admin login" toggle is ignored here — role comes from the doc).
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AppUser? _cached;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(FsCollections.users).doc(uid);

  @override
  AppUser? get currentUser => _cached;

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((fbUser) async {
      if (fbUser == null) {
        _cached = null;
        return null;
      }
      final snap = await _userDoc(fbUser.uid).get();
      final data = snap.data();
      _cached = data != null
          ? AppUser.fromMap(fbUser.uid, data)
          : AppUser(
              id: fbUser.uid,
              name: fbUser.displayName ?? fbUser.email ?? 'User',
              email: fbUser.email ?? '',
            );
      return _cached;
    });
  }

  @override
  Future<AppUser> signIn(String email, String password,
      {bool asAdmin = false}) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    final uid = cred.user!.uid;
    final snap = await _userDoc(uid).get();
    final data = snap.data();
    _cached = data != null
        ? AppUser.fromMap(uid, data)
        : AppUser(id: uid, name: email.trim(), email: email.trim());
    return _cached!;
  }

  @override
  Future<AppUser> register(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    final uid = cred.user!.uid;
    await cred.user!.updateDisplayName(name);
    final user = AppUser(id: uid, name: name, email: email.trim());
    await _userDoc(uid).set(user.toMap());
    _cached = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _cached = null;
  }
}
