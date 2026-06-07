import 'package:flutter_test/flutter_test.dart';
import 'package:keyframes_app/core/utils/marketplace_boundary.dart';

/// Unit tests for [MarketplaceBoundary].
///
/// The boundary guard encodes the service-centric invariant: no route, screen,
/// or model may expose a per-employee selection/hiring surface, and every Order
/// must bind to a `serviceId` (a ServiceListing).
///
/// _Requirements: 15.1 (no per-employee surface), 15.2 (Order binds to a
/// ServiceListing)._
void main() {
  group('MarketplaceBoundary.hasEmployeeHiringSurface', () {
    test('returns false for the real route table and Order model', () {
      expect(
        MarketplaceBoundary.hasEmployeeHiringSurface(
          MarketplaceBoundary.knownRoutePaths,
          MarketplaceBoundary.orderModelFieldNames,
        ),
        isFalse,
      );
    });

    test('detects a hiring token in a route path', () {
      expect(
        MarketplaceBoundary.hasEmployeeHiringSurface(
          const <String>['/home', '/hire/:employeeId'],
          const <String>[],
        ),
        isTrue,
      );
    });

    test('detects a hiring token in a model field name', () {
      expect(
        MarketplaceBoundary.hasEmployeeHiringSurface(
          const <String>[],
          const <String>['id', 'freelancerId'],
        ),
        isTrue,
      );
    });

    test('matching is case-insensitive', () {
      expect(
        MarketplaceBoundary.hasEmployeeHiringSurface(
          const <String>['/Staff'],
          const <String>[],
        ),
        isTrue,
      );
    });

    test('every canonical token is detected', () {
      for (final String token in MarketplaceBoundary.employeeHiringTokens) {
        expect(
          MarketplaceBoundary.hasEmployeeHiringSurface(
            <String>['/prefix-$token-suffix'],
            const <String>[],
          ),
          isTrue,
          reason: 'token "$token" should be detected',
        );
      }
    });
  });

  group('MarketplaceBoundary.assertServiceCentric', () {
    test('returns null for the real route table and Order model', () {
      expect(MarketplaceBoundary.assertServiceCentric(), isNull);
      expect(MarketplaceBoundary.isServiceCentric, isTrue);
    });

    test('reports a violating route path first', () {
      final String? violation = MarketplaceBoundary.assertServiceCentric(
        routePaths: const <String>['/home', '/employees'],
        orderFieldNames: MarketplaceBoundary.orderModelFieldNames,
      );
      expect(violation, isNotNull);
      expect(violation, contains('/employees'));
    });

    test('reports a violating order field name', () {
      final String? violation = MarketplaceBoundary.assertServiceCentric(
        routePaths: MarketplaceBoundary.knownRoutePaths,
        orderFieldNames: const <String>['id', 'serviceId', 'employeeId'],
      );
      expect(violation, isNotNull);
      expect(violation, contains('employeeId'));
    });

    test('reports a missing serviceId binding (Requirement 15.2)', () {
      final String? violation = MarketplaceBoundary.assertServiceCentric(
        routePaths: MarketplaceBoundary.knownRoutePaths,
        orderFieldNames: const <String>['id', 'clientId', 'createdAt'],
      );
      expect(violation, isNotNull);
      expect(violation, contains('serviceId'));
    });

    test('Order model exposes a serviceId and no employee binding', () {
      expect(
        MarketplaceBoundary.orderModelFieldNames,
        contains(MarketplaceBoundary.orderServiceBindingField),
      );
      expect(
        MarketplaceBoundary.orderModelFieldNames,
        isNot(contains('employeeId')),
      );
      expect(
        MarketplaceBoundary.orderModelFieldNames,
        isNot(contains('freelancerId')),
      );
    });
  });
}
