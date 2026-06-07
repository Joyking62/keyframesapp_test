// Property-based tests for the service-centric marketplace boundary
// (Requirements 15.1, 15.2).
//
// Property 8: No employee-hiring surface.
//   No route, screen, or model exposes a per-employee selection/hiring surface,
//   and every Order binds to a service (`serviceId`) rather than to an
//   individual employee.
//
// Validates: Requirements 15.1, 15.2
//
// Two facets are pinned down here, each combining a finite enumeration of the
// app's real surface (the [knownRoutePaths] table and the [orderFieldNames]
// schema) with `glados`-generated random inputs that probe the detector's
// soundness (no false positives on the marketplace token set) and completeness
// (every embedded hiring token is caught).
//
// Generators follow the patterns in
// `test/data/models/serialization_property_test.dart`: random strings are built
// by mapping `any.int` over a fixed token list (Dart's `%` with a positive
// divisor always yields a non-negative index, so negative seeds are safe), and
// composite values are assembled with `any.combine2` / `any.list` / `.map`.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart';

import 'package:keyframes_app/core/utils/marketplace_boundary.dart';

// ---------------------------------------------------------------------------
// Token vocabularies.
// ---------------------------------------------------------------------------

/// Tokens drawn from the app's legitimate, service-centric vocabulary. None of
/// these embeds an employee-hiring token as a substring, so any string built
/// purely from them must be classified as clean.
const List<String> _marketplaceTokens = <String>[
  'service',
  'order',
  'chat',
  'profile',
  'admin',
  'listing',
  'home',
  'login',
];

/// Clean model field names (no hiring token). Includes the real [Order] field
/// `serviceId` plus other service-centric names.
const List<String> _cleanFieldNames = <String>[
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
  'title',
  'category',
  'price',
];

// ---------------------------------------------------------------------------
// Generators.
// ---------------------------------------------------------------------------

/// A single marketplace path segment (always clean).
final Generator<String> _marketplaceToken =
    any.int.map((int i) => _marketplaceTokens[i % _marketplaceTokens.length]);

/// A random route-like path composed only of marketplace tokens, e.g.
/// `/home/service/order`. An empty segment list yields `'/'`, which is also
/// clean.
final Generator<String> _marketplacePath =
    any.list(_marketplaceToken).map((List<String> segs) => '/${segs.join('/')}');

/// A single employee-hiring token (`employee`, `freelancer`, ...).
final Generator<String> _hiringToken = any
    .int
    .map((int i) => employeeHiringTokens[i % employeeHiringTokens.length]);

/// A marketplace path with a hiring token embedded in a trailing segment, e.g.
/// `/home/service/employee-42`. The base is always clean, so the only hiring
/// token present is the injected one, which the detector must catch.
final Generator<String> _pathWithHiringToken = any.combine2(
  _marketplacePath,
  _hiringToken,
  (String base, String token) => '$base/$token-42',
);

/// A random set of clean model field names.
final Generator<List<String>> _cleanFieldSet = any.list(
  any.int.map((int i) => _cleanFieldNames[i % _cleanFieldNames.length]),
);

/// A model field name that embeds a hiring token, e.g. `employeeId`,
/// `freelancerId`, `hireId`.
final Generator<String> _hiringField =
    _hiringToken.map((String token) => '${token}Id');

/// A field-name set guaranteed to contain at least one hiring field.
final Generator<List<String>> _fieldSetWithHiring = any.combine2(
  _cleanFieldSet,
  _hiringField,
  (List<String> clean, String hiring) => <String>[...clean, hiring],
);

void main() {
  group('Property 8: No employee-hiring surface (Requirements 15.1, 15.2)', () {
    group('Property A: the route table is clean', () {
      test('the known route table exposes no hiring surface', () {
        // Finite enumeration over the real KRoutes-derived table.
        for (final String path in knownRoutePaths) {
          expect(
            containsHiringToken(path),
            isFalse,
            reason: 'route "$path" must not expose a hiring surface',
          );
        }
        expect(
          hasEmployeeHiringSurface(knownRoutePaths, orderFieldNames),
          isFalse,
        );
      });

      test('every employee-hiring token is individually detected', () {
        // Completeness on the token set itself.
        for (final String token in employeeHiringTokens) {
          expect(
            hasEmployeeHiringSurface(<String>['/$token'], const <String>[]),
            isTrue,
            reason: 'token "$token" should be detected',
          );
        }
      });

      Glados<String>(_marketplacePath).test(
        'random marketplace paths are never flagged (soundness)',
        (String path) {
          expect(
            hasEmployeeHiringSurface(<String>[path], const <String>[]),
            isFalse,
          );
        },
      );

      Glados<String>(_pathWithHiringToken).test(
        'paths embedding a hiring token are always flagged (completeness)',
        (String path) {
          expect(
            hasEmployeeHiringSurface(<String>[path], const <String>[]),
            isTrue,
          );
        },
      );
    });

    group('Property B: an Order binds to a service, not an employee', () {
      test('Order schema contains serviceId and is service-centric', () {
        expect(orderFieldNames, contains('serviceId'));
        expect(orderFieldNames, isNot(contains('employeeId')));
        expect(orderFieldNames, isNot(contains('freelancerId')));
        expect(assertServiceCentric(orderFieldNames), isNull);
      });

      Glados<List<String>>(_cleanFieldSet).test(
        'field sets without hiring tokens are compliant (null violation)',
        (List<String> fields) {
          expect(assertServiceCentric(fields), isNull);
        },
      );

      Glados<List<String>>(_fieldSetWithHiring).test(
        'field sets containing a hiring token return a violation',
        (List<String> fields) {
          expect(assertServiceCentric(fields), isNotNull);
        },
      );
    });
  });
}
