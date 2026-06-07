import 'package:flutter_test/flutter_test.dart';
import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/bootstrap_result.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/features/splash/bootstrap.dart';

/// Unit tests for the pure [resolveInitialRoute] decision function (Task 10.4).
///
/// Verifies the four startup-routing decisions from the design's
/// `resolveInitialRoute` table:
///
/// | user        | seenOnboarding | route                  |
/// |-------------|----------------|------------------------|
/// | `null`      | `false`        | [KRoutes.onboarding]   | (Requirement 1.4)
/// | `null`      | `true`         | [KRoutes.login]        | (Requirement 1.5)
/// | role admin  | (any)          | [KRoutes.adminOverview]| (Requirement 1.6)
/// | role client | (any)          | [KRoutes.home]         | (Requirement 1.7)
void main() {
  // A fixed timestamp so constructed users are deterministic.
  final DateTime createdAt = DateTime.utc(2024, 1, 1, 12);

  AppUser userWithRole(UserRole role) => AppUser(
        id: 'user-1',
        name: 'Test User',
        email: 'test@example.com',
        role: role,
        createdAt: createdAt,
      );

  group('resolveInitialRoute', () {
    test(
        'returns onboarding when no user and onboarding not yet seen '
        '(Requirement 1.4)', () {
      const BootstrapResult result =
          BootstrapResult(seenOnboarding: false, user: null);

      expect(resolveInitialRoute(result), KRoutes.onboarding);
    });

    test(
        'returns login when no user but onboarding already seen '
        '(Requirement 1.5)', () {
      const BootstrapResult result =
          BootstrapResult(seenOnboarding: true, user: null);

      expect(resolveInitialRoute(result), KRoutes.login);
    });

    test(
        'returns adminOverview for an admin user regardless of seenOnboarding '
        '(Requirement 1.6)', () {
      final AppUser admin = userWithRole(UserRole.admin);

      expect(
        resolveInitialRoute(
          BootstrapResult(seenOnboarding: false, user: admin),
        ),
        KRoutes.adminOverview,
      );
      expect(
        resolveInitialRoute(
          BootstrapResult(seenOnboarding: true, user: admin),
        ),
        KRoutes.adminOverview,
      );
    });

    test(
        'returns home for a client user regardless of seenOnboarding '
        '(Requirement 1.7)', () {
      final AppUser client = userWithRole(UserRole.client);

      expect(
        resolveInitialRoute(
          BootstrapResult(seenOnboarding: false, user: client),
        ),
        KRoutes.home,
      );
      expect(
        resolveInitialRoute(
          BootstrapResult(seenOnboarding: true, user: client),
        ),
        KRoutes.home,
      );
    });
  });
}
