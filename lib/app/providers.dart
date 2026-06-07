import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/bootstrap_result.dart';
import 'package:keyframes_app/data/repositories/auth_repository.dart';
import 'package:keyframes_app/data/repositories/chat_repository.dart';
import 'package:keyframes_app/data/repositories/firebase_auth_repository.dart';
import 'package:keyframes_app/data/repositories/firebase_chat_repository.dart';
import 'package:keyframes_app/data/repositories/firebase_order_repository.dart';
import 'package:keyframes_app/data/repositories/firebase_service_repository.dart';
import 'package:keyframes_app/data/repositories/order_repository.dart';
import 'package:keyframes_app/data/repositories/service_repository.dart';
import 'package:keyframes_app/data/sources/local_source.dart';
import 'package:keyframes_app/features/order/default_order_service.dart';

/// Application-wide dependency-injection wiring (Requirement 17.3).
///
/// This file is the single place where the app's data layer is composed. It
/// follows the standard Riverpod DI pattern: small "leaf" providers expose the
/// raw infrastructure handles (Firebase singletons, the [LocalSource]) and the
/// higher-level repository/service providers depend on those leaves. Because
/// every dependency is reached through a provider, the entire data layer can be
/// re-pointed at fakes in a single [ProviderScope] override block.
///
/// ## Injecting Firebase vs. fake implementations
///
/// Production wiring leaves the leaf providers at their defaults (the live
/// Firebase singletons) — `main()` only needs to override [localSourceProvider]
/// with the instance whose [LocalSource.init] it already awaited:
///
/// ```dart
/// final localSource = LocalSource();
/// await localSource.init();
/// runApp(
///   ProviderScope(
///     overrides: [
///       localSourceProvider.overrideWithValue(localSource),
///     ],
///     child: const KeyframesApp(),
///   ),
/// );
/// ```
///
/// Tests (or a Firebase-emulator harness) swap the backend by overriding the
/// leaf providers; every repository above them is rebuilt against the fakes
/// automatically, with no change to the repository providers themselves:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     localSourceProvider.overrideWithValue(fakeLocalSource),
///     firebaseFirestoreProvider.overrideWithValue(fakeFirestore),
///     firebaseAuthProvider.overrideWithValue(fakeAuth),
///     firebaseStorageProvider.overrideWithValue(fakeStorage),
///     // …or override a repository provider directly with a hand-written fake:
///     // authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
///   ],
///   child: const KeyframesApp(),
/// );
/// ```

// ---------------------------------------------------------------------------
// Leaf providers — raw infrastructure handles (overridable in tests)
// ---------------------------------------------------------------------------

/// The device-local cache / preferences source.
///
/// [LocalSource.init] is asynchronous (it opens Hive boxes and loads
/// shared_preferences), so it cannot be created synchronously here. Instead it
/// is initialized in `main()` and injected via a [ProviderScope] override; this
/// default implementation throws to make a missing override fail fast and
/// loudly rather than silently using an uninitialized cache.
final localSourceProvider = Provider<LocalSource>((ref) {
  throw UnimplementedError(
    'localSourceProvider must be overridden in ProviderScope with a '
    'LocalSource whose init() has already completed (see main()).',
  );
});

/// The Cloud Firestore instance used by every Firestore-backed repository.
///
/// Defaults to the live singleton; override in tests with a fake Firestore.
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// The Firebase Auth instance used for authentication and the current-user id.
///
/// Defaults to the live singleton; override in tests with a fake auth handle.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// The Firebase Storage instance used for chat attachment uploads.
///
/// Defaults to the live singleton; override in tests with a fake storage handle.
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

// ---------------------------------------------------------------------------
// Domain service
// ---------------------------------------------------------------------------

/// The pure order lifecycle service (transition validation + timeline append).
///
/// Stateless and side-effect free by default; the notification hooks can be
/// supplied via an override when wiring real push/notification delivery.
final orderServiceProvider = Provider<DefaultOrderService>((ref) {
  return const DefaultOrderService();
});

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

/// The authentication repository (Firebase Auth + Firestore profile docs).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});

/// The service-catalog repository (Firestore reads with Hive cache fallback).
final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return FirebaseServiceRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    local: ref.watch(localSourceProvider),
  );
});

/// The order repository (Firestore, wired to the order lifecycle service).
///
/// The acting client id is resolved lazily from the current Firebase user, so
/// the repository always reflects the live session without holding stale state.
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return FirebaseOrderRepository(
    orderService: ref.watch(orderServiceProvider),
    currentUserId: () => auth.currentUser?.uid,
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});

/// The chat repository (Firestore conversations/messages + Storage uploads).
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return FirebaseChatRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    storage: ref.watch(firebaseStorageProvider),
  );
});

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------

/// Streams the current [AppUser] (or `null` when signed out), re-emitting on
/// every authentication state change. UI and route guards watch this to react
/// to sign-in / sign-out in real time.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authState();
});

/// The currently authenticated [AppUser], or `null` while signed out or while
/// the auth stream is still resolving. A synchronous convenience view over
/// [authStateProvider] for widgets/guards that only need the latest value.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------

/// Resolves the app's startup decision data (Requirements 1.1–1.3).
///
/// Mirrors the design's `bootstrap()` pseudocode: it reads the persisted
/// `seenOnboarding` flag from the [LocalSource], loads the current user from
/// the [AuthRepository], and kicks off a **best-effort, non-blocking** catalog
/// preload to warm the offline cache. The catalog preload is intentionally not
/// awaited, so a slow or failing network never delays the splash → route
/// resolution. The returned [BootstrapResult] carries no navigation side
/// effects; `resolveInitialRoute` (task 10.1) consumes it to choose the route.
final bootstrapProvider = FutureProvider<BootstrapResult>((ref) async {
  final local = ref.watch(localSourceProvider);
  final authRepository = ref.watch(authRepositoryProvider);

  final seenOnboarding = local.seenOnboarding;
  final user = await authRepository.currentUser();

  // Best-effort, non-blocking catalog preload (Requirements 1.3, 17.1).
  unawaited(_preloadCatalog(ref));

  return BootstrapResult(seenOnboarding: seenOnboarding, user: user);
});

/// Warms the offline catalog cache without blocking [bootstrapProvider].
///
/// Pulls the first catalog snapshot (which write-throughs to the Hive cache in
/// [FirebaseServiceRepository]) and swallows any failure — offline/permission
/// errors must never surface from a best-effort preload.
Future<void> _preloadCatalog(Ref ref) async {
  try {
    await ref.read(serviceRepositoryProvider).watchServices().first;
  } catch (_) {
    // Best-effort only: ignore network/permission failures.
  }
}
