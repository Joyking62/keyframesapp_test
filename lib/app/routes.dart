/// Centralized route path constants for the Keyframes app.
///
/// Defined in their own file (rather than inside `router.dart`) so that both
/// the router and the pure `resolveInitialRoute` decision logic can reference
/// the exact same path strings without creating an import cycle. Every screen
/// and navigation call should reference these constants instead of hard-coding
/// path literals, keeping the route table and the navigation flow in the design
/// document in lock-step.
abstract final class KRoutes {
  // ---------------------------------------------------------------------------
  // Pre-auth / public routes
  // ---------------------------------------------------------------------------

  /// The initial route — the 3D-depth animated splash / preloader.
  static const String splash = '/splash';

  /// The three-page onboarding flow (first launch only).
  static const String onboarding = '/onboarding';

  /// The sign-in screen.
  static const String login = '/login';

  /// The client registration screen.
  static const String register = '/register';

  // ---------------------------------------------------------------------------
  // Client shell (bottom navigation): Home · Orders · Chat · Profile
  // ---------------------------------------------------------------------------

  /// Client home / service catalog tab.
  static const String home = '/home';

  /// Client orders dashboard tab.
  static const String orders = '/orders';

  /// Client chat portal tab.
  static const String chat = '/chat';

  /// Client profile tab.
  static const String profile = '/profile';

  // ---------------------------------------------------------------------------
  // Admin shell (bottom navigation):
  // Overview · Orders · Chats · Listings · Profile
  // ---------------------------------------------------------------------------

  /// Admin overview / dashboard tab (KPIs). The admin's landing route.
  static const String adminOverview = '/admin/overview';

  /// Admin orders management tab.
  static const String adminOrders = '/admin/orders';

  /// Admin conversations tab.
  static const String adminChats = '/admin/chats';

  /// Admin service-listings CRUD tab.
  static const String adminListings = '/admin/listings';

  /// Admin profile tab.
  static const String adminProfile = '/admin/profile';

  // ---------------------------------------------------------------------------
  // Detail / flow routes (pushed above the shells)
  // ---------------------------------------------------------------------------

  /// Service detail screen. Path parameter: `id` (the ServiceListing id).
  static const String serviceDetail = '/service/:id';

  /// The multi-step pre-order flow.
  static const String preorder = '/preorder';

  /// The post-submission order-success screen.
  static const String orderSuccess = '/order-success';

  /// Order detail / tracking screen. Path parameter: `id` (the Order id).
  static const String orderDetail = '/order/:id';

  /// Builds the concrete path for [serviceDetail] with the given service [id].
  static String serviceDetailPath(String id) => '/service/$id';

  /// Builds the concrete path for [orderDetail] with the given order [id].
  static String orderDetailPath(String id) => '/order/$id';

  /// The set of routes reachable without an authenticated session.
  ///
  /// Any route NOT in this set is considered "protected" by [the auth guard];
  /// unauthenticated users hitting a protected route are redirected to
  /// [login] (Requirement 5.2).
  static const Set<String> publicRoutes = <String>{
    splash,
    onboarding,
    login,
    register,
  };

  /// Whether [location] targets an admin-only route (prefix `/admin`).
  ///
  /// Used by the role guard to block clients from admin areas (Requirement 5.1).
  static bool isAdminLocation(String location) => location.startsWith('/admin');

  /// Whether [location] is reachable without authentication.
  static bool isPublicLocation(String location) =>
      publicRoutes.contains(location);
}
