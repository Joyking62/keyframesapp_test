import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/app/route_guard.dart';
import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/animations/route_transitions.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/features/admin_dashboard/admin_chats_screen.dart';
import 'package:keyframes_app/features/admin_dashboard/admin_listings_screen.dart';
import 'package:keyframes_app/features/admin_dashboard/admin_orders_screen.dart';
import 'package:keyframes_app/features/admin_dashboard/admin_overview_screen.dart';
import 'package:keyframes_app/features/auth/login_screen.dart';
import 'package:keyframes_app/features/auth/register_screen.dart';
import 'package:keyframes_app/features/catalog/home_screen.dart';
import 'package:keyframes_app/features/catalog/service_detail_screen.dart';
import 'package:keyframes_app/features/chat/chat_screen.dart';
import 'package:keyframes_app/features/client_dashboard/client_orders_screen.dart';
import 'package:keyframes_app/features/client_dashboard/order_detail_screen.dart';
import 'package:keyframes_app/features/client_dashboard/profile_screen.dart';
import 'package:keyframes_app/features/onboarding/onboarding_screen.dart';
import 'package:keyframes_app/features/preorder/order_success_screen.dart';
import 'package:keyframes_app/features/preorder/preorder_screen.dart';
import 'package:keyframes_app/features/splash/splash_screen.dart';

/// go_router configuration with role-based access guards (Requirement 5).
///
/// This file owns the app's declarative route table and the redirect logic that
/// enforces authentication and role gating. It mirrors the design's
/// "Navigation Flow" graph and "Router (low-level)" section:
///
/// * The initial location is [KRoutes.splash]; the splash performs bootstrap →
///   route resolution (see `features/splash/bootstrap.dart`).
/// * Two persistent bottom-navigation shells exist — a **client** shell
///   (Home · Orders · Chat · Profile) and an **admin** shell
///   (Overview · Orders · Chats · Listings · Profile) — built with
///   [StatefulShellRoute.indexedStack] so each tab keeps its own navigation
///   state.
/// * Detail / flow routes (service detail, pre-order, order-success, order
///   detail) sit at the top level so they push fullscreen above the shells.
/// * [_authRoleGuard] is wired as the router-wide `redirect` and re-runs
///   whenever the auth state changes (via [_AuthRefreshNotifier]).
///
/// Every screen referenced here is now the real feature screen (the end-to-end
/// wiring pass, task 24.1); the route table, guards, and transitions are
/// unchanged from when the screens were placeholders.

/// Exposes the configured [GoRouter] to the widget tree.
///
/// `app.dart` reads this provider and hands the router to `MaterialApp.router`.
/// The router is built once per [ProviderScope]; its redirect closure captures
/// [ref] so it can read the live [authStateProvider] on every navigation.
final routerProvider = Provider<GoRouter>((ref) => buildRouter(ref));

/// Builds the [GoRouter] for the Keyframes app.
///
/// Wires the full route table, the client/admin shell routes, the role guard,
/// and a [refreshListenable] bridged to authentication changes so guarded
/// routes re-evaluate the moment the user signs in or out.
GoRouter buildRouter(Ref ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: KRoutes.splash,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) =>
        _authRoleGuard(ref, state),
    routes: <RouteBase>[
      // -----------------------------------------------------------------
      // Splash (initial) — bootstrap + redirect.
      // -----------------------------------------------------------------
      GoRoute(
        path: KRoutes.splash,
        name: 'splash',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            buildFadeThroughPage<void>(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),

      // -----------------------------------------------------------------
      // Pre-auth / public routes.
      // -----------------------------------------------------------------
      GoRoute(
        path: KRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            buildFadeThroughPage<void>(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: KRoutes.login,
        name: 'login',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            buildFadeThroughPage<void>(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: KRoutes.register,
        name: 'register',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            buildSharedAxisPage<void>(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),

      // -----------------------------------------------------------------
      // Client shell: Home · Orders · Chat · Profile.
      // -----------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) =>
            _ClientShellScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: KRoutes.home,
                name: 'home',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    buildFadeThroughPage<void>(
                  key: state.pageKey,
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: KRoutes.orders,
                name: 'orders',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    buildFadeThroughPage<void>(
                  key: state.pageKey,
                  child: const ClientOrdersScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: KRoutes.chat,
                name: 'chat',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    buildFadeThroughPage<void>(
                  key: state.pageKey,
                  child: const ChatScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: KRoutes.profile,
                name: 'profile',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    buildFadeThroughPage<void>(
                  key: state.pageKey,
                  child: const ClientProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------
      // Admin shell: Overview · Orders · Chats · Listings · Profile.
      // -----------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) =>
            _AdminShellScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: KRoutes.adminOverview,
                name: 'adminOverview',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    buildFadeThroughPage<void>(
                  key: state.pageKey,
                  child: const AdminOverviewScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: KRoutes.adminOrders,
                name: 'adminOrders',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    buildFadeThroughPage<void>(
                  key: state.pageKey,
                  child: const AdminOrdersScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: KRoutes.adminChats,
                name: 'adminChats',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    buildFadeThroughPage<void>(
                  key: state.pageKey,
                  child: const AdminChatsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: KRoutes.adminListings,
                name: 'adminListings',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    buildFadeThroughPage<void>(
                  key: state.pageKey,
                  child: const AdminListingsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: KRoutes.adminProfile,
                name: 'adminProfile',
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    buildFadeThroughPage<void>(
                  key: state.pageKey,
                  // Reuse the client profile screen for admins: it shows the
                  // signed-in user plus sign-out and works for any role.
                  child: const ClientProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------
      // Detail / flow routes — pushed fullscreen above the shells.
      // -----------------------------------------------------------------
      GoRoute(
        path: KRoutes.serviceDetail, // '/service/:id'
        name: 'serviceDetail',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            buildSharedAxisPage<void>(
          key: state.pageKey,
          child: ServiceDetailScreen(
            serviceId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: KRoutes.preorder,
        name: 'preorder',
        pageBuilder: (BuildContext context, GoRouterState state) {
          // The pre-order flow is launched from service detail with the chosen
          // listing passed via `extra`. On a deep-link / direct navigation
          // `extra` is null, so render a non-crashing fallback that nudges the
          // user back to the catalog instead of throwing on a bad cast.
          final Object? extra = state.extra;
          final Widget child = extra is ServiceListing
              ? PreOrderScreen(listing: extra)
              : const _MissingListingFallback();
          return buildSharedAxisPage<void>(
            key: state.pageKey,
            direction: SharedAxisDirection.vertical,
            child: child,
          );
        },
      ),
      GoRoute(
        path: KRoutes.orderSuccess,
        name: 'orderSuccess',
        // The success screen requires the freshly-created order via `extra`.
        // If it is missing (e.g. a direct nav / refresh), fall back to home
        // rather than rendering a screen with no order to show.
        redirect: (BuildContext context, GoRouterState state) =>
            state.extra is Order ? null : KRoutes.home,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            buildFadeThroughPage<void>(
          key: state.pageKey,
          child: OrderSuccessScreen(order: state.extra! as Order),
        ),
      ),
      GoRoute(
        path: KRoutes.orderDetail, // '/order/:id'
        name: 'orderDetail',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            buildSharedAxisPage<void>(
          key: state.pageKey,
          child: OrderDetailScreen(
            orderId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
    ],
  );
}

/// The role-based redirect guard wired as the router-wide `redirect`.
///
/// Returns a path to redirect to, or `null` to allow the requested navigation.
/// Implements the design's `_authRoleGuard` contract and the correctness
/// property "role isolation" (Requirements 5.1, 5.2, 5.4):
///
/// * **While auth is still resolving**, keep the user on the splash so the
///   guard never makes a premature decision based on a not-yet-loaded session.
/// * **Unauthenticated** users may only reach public routes
///   ([KRoutes.publicRoutes]); any other (protected) route → [KRoutes.login].
/// * **Clients** are blocked from every `/admin/**` route → [KRoutes.home].
/// * **Admins** are allowed on admin routes (and everywhere else).
///
/// Data-layer permission-denied handling (Requirement 5.3) — redirecting to
/// home with a toast when a client hits an admin-only backend operation — is
/// surfaced from the data layer / Result error handling (task 24.1) rather than
/// from this navigation guard, which only reasons about the requested route.
String? _authRoleGuard(Ref ref, GoRouterState state) {
  final AsyncValue<AppUser?> authState = ref.read(authStateProvider);

  // While the auth state is still resolving (no value emitted yet), do not
  // redirect: the splash owns initial routing (it watches `bootstrapProvider`
  // and navigates via `resolveInitialRoute`). The guard re-runs the instant the
  // auth stream emits — via [_AuthRefreshNotifier] — and enforces access then,
  // which avoids any race where the bootstrap future resolves before the auth
  // stream and the user gets bounced back to (or stuck on) the splash.
  final bool authResolving = authState.isLoading && !authState.hasValue;

  // Delegate the actual access decision to the pure, framework-free
  // `resolveGuardRedirect` so the role-isolation logic is unit/property
  // testable in isolation (Requirements 5.1, 5.2, 5.4).
  return resolveGuardRedirect(
    user: authState.valueOrNull,
    authResolving: authResolving,
    location: state.matchedLocation,
  );
}

/// Bridges Riverpod's [authStateProvider] to a [Listenable] so go_router
/// re-evaluates [_authRoleGuard] whenever the authentication state changes
/// (sign-in / sign-out), without the router holding any auth state itself.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AsyncValue<AppUser?>>(
      authStateProvider,
      (AsyncValue<AppUser?>? previous, AsyncValue<AppUser?> next) =>
          notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AppUser?>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

/// The client bottom-navigation shell scaffold (Home · Orders · Chat · Profile).
///
/// Hosts the [StatefulNavigationShell] (an `IndexedStack` of the four branch
/// roots) as its body and a Material 3 [NavigationBar] for switching tabs while
/// preserving each branch's state.
class _ClientShellScaffold extends StatelessWidget {
  const _ClientShellScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // `initialLocation: true` when re-tapping the active tab pops that branch
    // back to its root, matching common bottom-nav behavior.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        indicatorColor: KColors.amber300,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// The admin bottom-navigation shell scaffold
/// (Overview · Orders · Chats · Listings · Profile).
class _AdminShellScaffold extends StatelessWidget {
  const _AdminShellScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        indicatorColor: KColors.amber300,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_customize_outlined),
            selectedIcon: Icon(Icons.dashboard_customize_rounded),
            label: 'Listings',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}


/// Fallback shown when the pre-order route is reached without a [ServiceListing]
/// in `extra` (e.g. a deep link or a direct navigation / page refresh).
///
/// The pre-order flow is meaningless without a service to order, so rather than
/// crashing on a null cast this guides the user back to the catalog to pick a
/// service first (Requirement 8, defensive wiring for task 24.1).
class _MissingListingFallback extends StatelessWidget {
  const _MissingListingFallback();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pre-Order')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(KSpace.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: KColors.amber500,
              ),
              const SizedBox(height: KSpace.lg),
              Text(
                'Pick a service first',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: KSpace.sm),
              Text(
                'Choose a service from the catalog to start a pre-order.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: KColors.slate500,
                    ),
              ),
              const SizedBox(height: KSpace.xl),
              FilledButton(
                onPressed: () => context.go(KRoutes.home),
                child: const Text('Browse services'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
