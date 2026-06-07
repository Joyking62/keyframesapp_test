import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/enums.dart';

/// Pure, framework-free decision function for the router's role-based access
/// guard (Requirements 5.1, 5.2, 5.4).
///
/// This function isolates the *decision* of the router's `_authRoleGuard` from
/// the `go_router` / Riverpod plumbing (`GoRouterState`, `Ref`) so it can be
/// reasoned about and property-tested directly. `router.dart`'s guard reads the
/// live auth state and the requested location and delegates the actual verdict
/// to this function; the returned value is interpreted by `go_router` exactly
/// as a `redirect` result:
///
/// * `null` — allow the requested navigation to [location].
/// * a path string — redirect the navigation to that path instead.
///
/// The rules, in order, are:
///
/// 1. **Auth still resolving** ([authResolving] is `true`, i.e. the auth stream
///    has not yet emitted a value): return `null`. The splash owns initial
///    routing while bootstrap runs; the guard must not make a premature
///    decision against a not-yet-loaded session. The guard re-runs the instant
///    the auth state emits and enforces access then.
/// 2. **Unauthenticated** ([user] is `null`, auth resolved): public routes are
///    allowed (`null`); any other (protected) route redirects to
///    [KRoutes.login] (Requirement 5.2).
/// 3. **Authenticated client on an admin route**: redirect to [KRoutes.home]
///    (Requirements 5.1, 5.4) — clients can never reach `/admin/**`.
/// 4. **Otherwise** (admins anywhere, clients on non-admin routes): allow
///    (`null`).
///
/// Note that rule 3 returns [KRoutes.home], which is itself a non-admin
/// location, so a redirected client never lands on another admin route.
String? resolveGuardRedirect({
  required AppUser? user,
  required bool authResolving,
  required String location,
}) {
  // 1. While the auth state is still resolving, defer to the splash / bootstrap
  //    flow and make no redirect decision.
  if (authResolving) {
    return null;
  }

  final bool isPublic = KRoutes.isPublicLocation(location);
  final bool isAdminRoute = KRoutes.isAdminLocation(location);

  // 2. Unauthenticated: only public routes are reachable (Requirement 5.2).
  if (user == null) {
    return isPublic ? null : KRoutes.login;
  }

  // 3. Authenticated client attempting an admin route → client home
  //    (Requirements 5.1, 5.4).
  if (user.role == UserRole.client && isAdminRoute) {
    return KRoutes.home;
  }

  // 4. Authenticated and allowed (admins everywhere; clients on non-admin).
  return null;
}
