// Property-based test for the router's role-based access guard.
//
// Property 1: Role isolation
//   For every (user state, requested location) pair, the pure guard decision
//   `resolveGuardRedirect` enforces role isolation:
//     * a client user can NEVER end up allowed on an `/admin/**` location — the
//       guard always redirects them away, and never to another admin location;
//     * an unauthenticated (resolved) user on a non-public location is always
//       redirected to `/login` (never left on the protected location);
//     * no redirect ever targets a protected/admin destination.
//
// Validates: Requirements 5.1, 5.2
//
// The guard's decision logic was extracted into the framework-free
// `resolveGuardRedirect` (in `lib/app/route_guard.dart`) precisely so this
// invariant can be checked directly over a large random input space with
// `glados`, without standing up `go_router`/Riverpod.
//
// An independent oracle (`_oracleIsPublic` / `_oracleIsAdmin`) re-derives the
// public/admin classification from first principles inside the test, and a
// sanity property cross-checks it against the production `KRoutes` helpers so a
// regression in either classifier cannot silently mask a role-isolation bug.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart';

import 'package:keyframes_app/app/route_guard.dart';
import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/enums.dart';

// ---------------------------------------------------------------------------
// Fixtures.
// ---------------------------------------------------------------------------

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Builds a minimal [AppUser] with the given [role]; only `role` is relevant to
/// the guard, the other fields are fixed.
AppUser _user(UserRole role) => AppUser(
      id: 'u',
      name: 'Test User',
      email: 'test@example.com',
      role: role,
      createdAt: _epoch,
    );

/// The space of locations the guard can be asked about: public + client-shell +
/// admin-shell + top-level detail/flow routes (including parameterized paths).
const List<String> _locations = <String>[
  // Public (reachable without authentication).
  KRoutes.splash,
  KRoutes.onboarding,
  KRoutes.login,
  KRoutes.register,
  // Client shell — protected, non-admin.
  KRoutes.home,
  KRoutes.orders,
  KRoutes.chat,
  KRoutes.profile,
  // Admin shell — protected, admin-only.
  KRoutes.adminOverview,
  KRoutes.adminOrders,
  KRoutes.adminChats,
  KRoutes.adminListings,
  KRoutes.adminProfile,
  // Top-level detail / flow routes — protected, non-admin.
  KRoutes.preorder,
  KRoutes.orderSuccess,
  '/service/svc_123',
  '/order/ord_456',
];

// ---------------------------------------------------------------------------
// Independent oracle for public/admin classification.
//
// Deliberately re-states the classification rules rather than calling KRoutes,
// so the tests do not assume the production helpers are correct.
// ---------------------------------------------------------------------------

const Set<String> _oraclePublicRoutes = <String>{
  '/splash',
  '/onboarding',
  '/login',
  '/register',
};

bool _oracleIsPublic(String location) => _oraclePublicRoutes.contains(location);

bool _oracleIsAdmin(String location) => location.startsWith('/admin');

// ---------------------------------------------------------------------------
// Generators.
//
// Derived from `any.int` (glados' core primitive). Dart's `%` with a positive
// divisor always yields a non-negative result, so index math is safe even for
// negative seeds.
// ---------------------------------------------------------------------------

/// User state: `0 -> unauthenticated (null)`, `1 -> client`, `2 -> admin`.
final Generator<AppUser?> _anyUserState = any.int.map((int i) {
  switch (i % 3) {
    case 0:
      return null;
    case 1:
      return _user(UserRole.client);
    default:
      return _user(UserRole.admin);
  }
});

final Generator<String> _anyLocation =
    any.int.map((int i) => _locations[i % _locations.length]);

void main() {
  group('Property 1: Role isolation (Requirements 5.1, 5.2)', () {
    // Sanity: the independent oracle agrees with the production classification.
    // If this drifts, the role-isolation assertions below could be checking the
    // wrong thing, so we pin them together.
    Glados<String>(_anyLocation).test(
      'oracle classification matches KRoutes helpers',
      (String location) {
        expect(KRoutes.isPublicLocation(location), _oracleIsPublic(location));
        expect(KRoutes.isAdminLocation(location), _oracleIsAdmin(location));
      },
    );

    // 5.1 — a client can NEVER be allowed onto an /admin/** location.
    Glados2<AppUser?, String>(_anyUserState, _anyLocation).test(
      'a client is never allowed onto an /admin/** location',
      (AppUser? user, String location) {
        // Restrict to the relevant case: an authenticated client targeting an
        // admin location.
        if (user == null || user.role != UserRole.client) return;
        if (!_oracleIsAdmin(location)) return;

        final String? redirect = resolveGuardRedirect(
          user: user,
          authResolving: false,
          location: location,
        );

        // The client must be redirected away (non-null) ...
        expect(redirect, isNotNull);
        // ... to a non-admin destination (here, the client home) ...
        expect(_oracleIsAdmin(redirect!), isFalse);
        // ... which the guard specifies as the client home.
        expect(redirect, KRoutes.home);
      },
    );

    // 5.2 — an unauthenticated (resolved) user on a non-public location is
    // redirected to /login and never left on the protected location.
    Glados<String>(_anyLocation).test(
      'an unauthenticated user is sent to /login from any non-public route',
      (String location) {
        final String? redirect = resolveGuardRedirect(
          user: null,
          authResolving: false,
          location: location,
        );

        if (_oracleIsPublic(location)) {
          // Public routes are reachable without authentication.
          expect(redirect, isNull);
        } else {
          // Protected routes redirect to login (a public route), and never
          // leave the user on the protected location they requested.
          expect(redirect, KRoutes.login);
          expect(redirect, isNot(location));
          expect(_oracleIsPublic(redirect!), isTrue);
        }
      },
    );

    // 5.1 / 5.2 combined — whatever the user state, a redirect target is always
    // "safe": it never points at an admin location, so the guard can never
    // bounce anyone *into* a protected admin area.
    Glados2<AppUser?, String>(_anyUserState, _anyLocation).test(
      'no redirect target is ever an admin location',
      (AppUser? user, String location) {
        final String? redirect = resolveGuardRedirect(
          user: user,
          authResolving: false,
          location: location,
        );
        if (redirect == null) return;
        expect(_oracleIsAdmin(redirect), isFalse);
      },
    );

    // An admin is allowed everywhere (no redirect), confirming the isolation is
    // role-specific and does not over-block.
    Glados<String>(_anyLocation).test(
      'an admin is allowed on every location',
      (String location) {
        final String? redirect = resolveGuardRedirect(
          user: _user(UserRole.admin),
          authResolving: false,
          location: location,
        );
        expect(redirect, isNull);
      },
    );
  });
}
