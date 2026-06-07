import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/data/models/bootstrap_result.dart';
import 'package:keyframes_app/data/models/enums.dart';

/// Bootstrap & initial-routing logic (Requirement 1).
///
/// This file owns the two pieces of the design's bootstrap algorithm:
///
/// * [bootstrap] — a thin async wrapper over [bootstrapProvider] that resolves
///   the startup decision data ([BootstrapResult]: the `seenOnboarding` flag
///   and the current user). The heavy lifting (reading the persisted flag,
///   loading the current user, and kicking off the best-effort, non-blocking
///   catalog preload) already lives in [bootstrapProvider]; this wrapper simply
///   exposes it as an awaitable for callers that don't want to interact with
///   the provider directly (Requirements 1.1, 1.2, 1.3).
/// * [resolveInitialRoute] — a **pure** function that maps a [BootstrapResult]
///   to the path the app should land on once the splash completes. It performs
///   no navigation and has no side effects, so it is trivially unit-testable
///   (Requirements 1.4–1.7).
///
/// Keeping the decision pure and separate from the splash widget guarantees the
/// splash never navigates twice and that the routing decision can be verified
/// in isolation (see task 10.4).

/// Resolves the app's startup decision data.
///
/// A thin awaitable wrapper over [bootstrapProvider]; see that provider for the
/// full algorithm (load `seenOnboarding`, load the current user, best-effort
/// non-blocking catalog preload). Returns the resulting [BootstrapResult].
Future<BootstrapResult> bootstrap(Ref ref) {
  return ref.read(bootstrapProvider.future);
}

/// Maps a resolved [BootstrapResult] to the initial route path.
///
/// Mirrors the design's `resolveInitialRoute` pseudocode exactly:
///
/// | user        | seenOnboarding | route                  |
/// |-------------|----------------|------------------------|
/// | `null`      | `false`        | [KRoutes.onboarding]   |
/// | `null`      | `true`         | [KRoutes.login]        |
/// | role admin  | (any)          | [KRoutes.adminOverview]|
/// | role client | (any)          | [KRoutes.home]         |
///
/// This is a pure function: it never navigates and has no side effects.
/// Requirements: 1.4, 1.5, 1.6, 1.7.
String resolveInitialRoute(BootstrapResult result) {
  final user = result.user;

  // No authenticated user: route by onboarding state (Requirements 1.4, 1.5).
  if (user == null) {
    return result.seenOnboarding ? KRoutes.login : KRoutes.onboarding;
  }

  // Authenticated: route by role (Requirements 1.6, 1.7). Admins land on the
  // overview/dashboard tab (the first admin shell branch); clients on home.
  return switch (user.role) {
    UserRole.admin => KRoutes.adminOverview,
    UserRole.client => KRoutes.home,
  };
}
