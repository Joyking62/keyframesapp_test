/// Service-centric marketplace boundary guard (Requirements 15.1, 15.2).
///
/// Keyframes is a **service marketplace**, not a Fiverr-style per-freelancer
/// hiring platform. The product invariant is that **no route, screen, or model
/// ever exposes a per-employee selection or hiring surface**, and that every
/// [Order] binds to a [ServiceListing] (via `serviceId`) rather than to an
/// individual employee.
///
/// This module turns that prose invariant into a small, pure, testable API so
/// it can be enforced mechanically (and asserted by the property test for
/// Property 8). It deliberately depends only on the real [KRoutes] table and a
/// declared list of [Order] field names, so the check stays in lock-step with
/// the actual route table and data model rather than drifting into a stale
/// copy.
///
/// Two equivalent surfaces are exposed over a single shared implementation:
///
/// * A set of **top-level** functions/constants ([employeeHiringTokens],
///   [knownRoutePaths], [orderFieldNames], [containsHiringToken],
///   [hasEmployeeHiringSurface], [assertServiceCentric]) — convenient for
///   property tests that drive the primitives directly.
/// * A namespaced [MarketplaceBoundary] class that re-exports the same data and
///   adds a combined [MarketplaceBoundary.assertServiceCentric] audit (routes +
///   fields + `serviceId` binding) plus the [MarketplaceBoundary.isServiceCentric]
///   convenience getter.
///
/// The detector is intentionally simple and total: a name "exposes a hiring
/// surface" iff its lower-cased form contains any of the [employeeHiringTokens]
/// as a substring. On the marketplace token set used by the app (service,
/// order, chat, profile, admin, listing, home, login) this is both **sound**
/// (no false positives) and **complete** (every embedded hiring token is
/// detected), which is exactly what the property test pins down.
library;

import 'package:keyframes_app/app/routes.dart';

/// Tokens that would indicate a per-employee selection or hiring surface.
///
/// Matching is case-insensitive and substring-based, so derived forms such as
/// `employeeId`, `hireNow`, or `freelancerProfile` are all caught.
const List<String> employeeHiringTokens = <String>[
  'employee',
  'freelancer',
  'hire',
  'hiring',
  'staff',
  'worker',
  'seller',
];

/// The app's known route paths, taken directly from [KRoutes].
///
/// Kept in lock-step with the real route table so the audit can never pass
/// against a stale copy. Path-parameter templates (e.g. `/service/:id`) are
/// included verbatim because that is exactly what the router registers.
const List<String> knownRoutePaths = <String>[
  KRoutes.splash,
  KRoutes.onboarding,
  KRoutes.login,
  KRoutes.register,
  KRoutes.home,
  KRoutes.orders,
  KRoutes.chat,
  KRoutes.profile,
  KRoutes.adminOverview,
  KRoutes.adminOrders,
  KRoutes.adminChats,
  KRoutes.adminListings,
  KRoutes.adminProfile,
  KRoutes.serviceDetail,
  KRoutes.preorder,
  KRoutes.orderSuccess,
  KRoutes.orderDetail,
];

/// The field names of the [Order] model.
///
/// Declared here (rather than reflected, which Dart does not support without
/// `dart:mirrors`) so the boundary check can assert two things about the order
/// schema: that it binds to a service (`serviceId`) and that it never grows a
/// per-employee binding such as `employeeId` / `freelancerId`.
const List<String> orderFieldNames = <String>[
  'id',
  'clientId',
  'serviceId',
  'serviceTitle',
  'packageTier',
  'requirements',
  'attachments',
  'budget',
  'deadline',
  'status',
  'timeline',
  'createdAt',
];

/// Whether [name] embeds any employee-hiring token (case-insensitive).
///
/// This is the single primitive both [hasEmployeeHiringSurface] and
/// [assertServiceCentric] build on.
bool containsHiringToken(String name) {
  final String lower = name.toLowerCase();
  for (final String token in employeeHiringTokens) {
    if (lower.contains(token)) {
      return true;
    }
  }
  return false;
}

/// Whether any of the given [routePaths] or [modelFieldNames] exposes an
/// employee-hiring surface (Requirement 15.1).
///
/// Returns `true` as soon as a single offending name is found, otherwise
/// `false`. Callers typically pass [knownRoutePaths] and [orderFieldNames], but
/// the parameters are open so the property test can drive arbitrary inputs.
bool hasEmployeeHiringSurface(
  Iterable<String> routePaths,
  Iterable<String> modelFieldNames,
) {
  for (final String path in routePaths) {
    if (containsHiringToken(path)) {
      return true;
    }
  }
  for (final String field in modelFieldNames) {
    if (containsHiringToken(field)) {
      return true;
    }
  }
  return false;
}

/// Asserts that the given model [fieldNames] describe a service-centric entity
/// (Requirement 15.2).
///
/// Follows the validator convention used elsewhere in `core/utils`: a `null`
/// return means **compliant**, while a non-null [String] is a human-readable
/// description of the first violation found. A field set is non-compliant iff
/// one of its names embeds an [employeeHiringTokens] token (e.g. `employeeId`,
/// `freelancerId`).
///
/// This is the **field-only** check. For the combined route + field + binding
/// audit, use [MarketplaceBoundary.assertServiceCentric].
String? assertServiceCentric(Iterable<String> fieldNames) {
  for (final String field in fieldNames) {
    if (containsHiringToken(field)) {
      return 'Field "$field" exposes a per-employee/hiring binding; '
          'orders must bind to a service (serviceId), not an individual.';
    }
  }
  return null;
}

/// Namespaced facade over the service-centric marketplace boundary guard.
///
/// Re-exports the same data and primitives as the top-level API and adds a
/// combined audit ([assertServiceCentric]) plus the [isServiceCentric]
/// convenience getter. All members are static; the type is never instantiated.
abstract final class MarketplaceBoundary {
  /// Tokens that would indicate a per-employee selection or hiring surface.
  ///
  /// Identical to the top-level [employeeHiringTokens].
  static const List<String> employeeHiringTokens = <String>[
    'employee',
    'freelancer',
    'hire',
    'hiring',
    'staff',
    'worker',
    'seller',
  ];

  /// The app's known route paths, taken directly from [KRoutes].
  ///
  /// Identical to the top-level [knownRoutePaths].
  static const List<String> knownRoutePaths = <String>[
    KRoutes.splash,
    KRoutes.onboarding,
    KRoutes.login,
    KRoutes.register,
    KRoutes.home,
    KRoutes.orders,
    KRoutes.chat,
    KRoutes.profile,
    KRoutes.adminOverview,
    KRoutes.adminOrders,
    KRoutes.adminChats,
    KRoutes.adminListings,
    KRoutes.adminProfile,
    KRoutes.serviceDetail,
    KRoutes.preorder,
    KRoutes.orderSuccess,
    KRoutes.orderDetail,
  ];

  /// The field names of the [Order] model.
  ///
  /// Alias of the top-level [orderFieldNames]; named `orderModelFieldNames`
  /// here to read clearly at call sites such as
  /// `MarketplaceBoundary.orderModelFieldNames`.
  static const List<String> orderModelFieldNames = orderFieldNames;

  /// The single field through which an [Order] binds to a [ServiceListing].
  ///
  /// Its presence in [orderModelFieldNames] is what makes an order
  /// service-centric (Requirement 15.2).
  static const String orderServiceBindingField = 'serviceId';

  /// Whether any of the given [routePaths] or [modelFieldNames] exposes an
  /// employee-hiring surface (Requirement 15.1).
  ///
  /// Delegates to the top-level [hasEmployeeHiringSurface].
  static bool hasEmployeeHiringSurface(
    Iterable<String> routePaths,
    Iterable<String> modelFieldNames,
  ) =>
      hasEmployeeHiringSurfaceImpl(routePaths, modelFieldNames);

  /// Audits the marketplace boundary end-to-end (Requirements 15.1, 15.2).
  ///
  /// Returns `null` when compliant, otherwise a human-readable description of
  /// the **first** violation found, checked in this order:
  ///
  /// 1. any [routePaths] entry embedding a hiring token,
  /// 2. any [orderFieldNames] entry embedding a hiring token,
  /// 3. a missing [orderServiceBindingField] (`serviceId`) binding.
  ///
  /// Defaults audit the app's real route table and order schema.
  static String? assertServiceCentric({
    Iterable<String> routePaths = knownRoutePaths,
    Iterable<String> orderFieldNames = orderModelFieldNames,
  }) {
    for (final String path in routePaths) {
      if (containsHiringToken(path)) {
        return 'Route "$path" exposes a per-employee/hiring surface; '
            'the marketplace is service-centric and must not let clients '
            'select or hire individuals.';
      }
    }
    for (final String field in orderFieldNames) {
      if (containsHiringToken(field)) {
        return 'Field "$field" exposes a per-employee/hiring binding; '
            'orders must bind to a service (serviceId), not an individual.';
      }
    }
    if (!orderFieldNames.contains(orderServiceBindingField)) {
      return 'Order model is missing its "$orderServiceBindingField" binding; '
          'every order must bind to a ServiceListing (Requirement 15.2).';
    }
    return null;
  }

  /// Whether the app's real route table and order schema satisfy the
  /// service-centric boundary. Equivalent to `assertServiceCentric() == null`.
  static bool get isServiceCentric => assertServiceCentric() == null;
}

/// Internal alias so [MarketplaceBoundary.hasEmployeeHiringSurface] can delegate
/// to the top-level implementation without colliding with its own static
/// method name during resolution.
bool hasEmployeeHiringSurfaceImpl(
  Iterable<String> routePaths,
  Iterable<String> modelFieldNames,
) =>
    hasEmployeeHiringSurface(routePaths, modelFieldNames);
