// Unit tests for [LocalSource] — the device-side persistence façade that wraps
// the Hive `cached_catalog` box and the shared_preferences flags.
//
// These tests exercise the two responsibilities highlighted by Task 7.2:
//
//   * The cached-catalog round-trip: `writeCatalog` followed by `readCatalog`
//     must reproduce an equal list of [ServiceListing]s, an empty cache must
//     read back as `[]`, `hasCachedCatalog` must reflect the stored state, and
//     `clearCatalog` must empty it (Requirement 6.6).
//   * The `seenOnboarding` flag must default to `false` and persist `true`
//     after being set, alongside the theme/notification preferences
//     (Requirement 3.4).
//
// Test setup avoids real device storage:
//   * Hive is initialised against a freshly created temp directory
//     (`Directory.systemTemp.createTempSync`) since `path_provider` is not
//     available under the pure-Dart/Flutter test harness. A real `Box<String>`
//     is opened there and injected into [LocalSource] so the Hive code path is
//     genuinely exercised (no mocks).
//   * shared_preferences uses `SharedPreferences.setMockInitialValues({})` to
//     provide an in-memory backing store, and the resulting instance is
//     injected into [LocalSource].
//
// _Requirements: 3.4, 6.6_

import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/data/sources/local_source.dart';

void main() {
  // shared_preferences' mock channel needs the test binding initialised.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<String> catalogBox;
  late SharedPreferences preferences;
  late LocalSource source;

  /// A couple of representative listings covering both categories, optional
  /// fields populated and defaulted, so the round-trip exercises the full
  /// serialization surface (lists, nullable thumbnail, flags, ints).
  List<ServiceListing> sampleListings() => <ServiceListing>[
        const ServiceListing(
          id: 'svc_1',
          title: 'Mobile App Development',
          tagline: 'Ship your idea to the store',
          description: 'End-to-end Flutter app build with backend wiring.',
          category: ServiceCategory.itServices,
          basePrice: 1499.99,
          deliverables: <String>['Source code', 'Store submission'],
          gallery: <String>['https://cdn.example.com/a.png'],
          thumbnailUrl: 'https://cdn.example.com/thumb_1.png',
          estimatedDays: 30,
        ),
        const ServiceListing(
          id: 'svc_2',
          title: 'Logo Creation',
          tagline: 'A mark that sticks',
          description: 'Three concepts, two revision rounds, vector delivery.',
          category: ServiceCategory.graphicDesign,
          basePrice: 199,
          // deliverables/gallery left at their defaults to cover the empty-list
          // path; thumbnailUrl null to cover the nullable path.
          active: false,
        ),
      ];

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('keyframes_local_source_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    // Fresh in-memory preferences for every test.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();

    // A real, freshly cleared Hive box injected into the source.
    catalogBox = await Hive.openBox<String>(LocalSource.catalogBoxName);
    await catalogBox.clear();

    source = LocalSource(catalogBox: catalogBox, preferences: preferences);
    // init() is a no-op for injected dependencies but mirrors real usage.
    await source.init();
  });

  tearDown(() async {
    await catalogBox.clear();
    await catalogBox.close();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('cached catalog (Requirement 6.6)', () {
    test('readCatalog returns an empty list when nothing is cached', () {
      expect(source.readCatalog(), isEmpty);
    });

    test('hasCachedCatalog is false for an empty cache', () {
      expect(source.hasCachedCatalog, isFalse);
    });

    test('writeCatalog then readCatalog reproduces equal ServiceListings',
        () async {
      final listings = sampleListings();

      await source.writeCatalog(listings);
      final readBack = source.readCatalog();

      // freezed value equality compares every field (including list contents),
      // so this asserts a lossless round-trip.
      expect(readBack, equals(listings));
      expect(readBack, hasLength(listings.length));
    });

    test('hasCachedCatalog reflects state after a write', () async {
      expect(source.hasCachedCatalog, isFalse);

      await source.writeCatalog(sampleListings());

      expect(source.hasCachedCatalog, isTrue);
    });

    test('writing an empty list reads back as an empty list', () async {
      await source.writeCatalog(const <ServiceListing>[]);

      // An empty catalog is encoded as the JSON string "[]", which decodes
      // back to an empty list of listings.
      expect(source.readCatalog(), isEmpty);
      expect(source.readCatalog(), isA<List<ServiceListing>>());
    });

    test('clearCatalog empties a previously populated cache', () async {
      await source.writeCatalog(sampleListings());
      expect(source.hasCachedCatalog, isTrue);

      await source.clearCatalog();

      expect(source.hasCachedCatalog, isFalse);
      expect(source.readCatalog(), isEmpty);
    });

    test('a later writeCatalog replaces the previous cache', () async {
      await source.writeCatalog(sampleListings());

      final replacement = <ServiceListing>[
        const ServiceListing(
          id: 'svc_only',
          title: 'Poster Design',
          tagline: 'Eye-catching prints',
          description: 'Single high-resolution poster, print-ready.',
          category: ServiceCategory.graphicDesign,
          basePrice: 79.5,
        ),
      ];

      await source.writeCatalog(replacement);

      expect(source.readCatalog(), equals(replacement));
    });
  });

  group('onboarding flag (Requirement 3.4)', () {
    test('seenOnboarding defaults to false on a fresh install', () {
      expect(source.seenOnboarding, isFalse);
    });

    test('seenOnboarding is true after setSeenOnboarding(true)', () async {
      await source.setSeenOnboarding(true);

      expect(source.seenOnboarding, isTrue);
    });

    test('seenOnboarding can be toggled back to false', () async {
      await source.setSeenOnboarding(true);
      expect(source.seenOnboarding, isTrue);

      await source.setSeenOnboarding(false);
      expect(source.seenOnboarding, isFalse);
    });
  });

  group('theme & notification preferences', () {
    test('themeMode defaults to system and round-trips each value', () async {
      expect(source.themeMode, ThemeMode.system);

      for (final mode in ThemeMode.values) {
        await source.setThemeMode(mode);
        expect(source.themeMode, mode);
      }
    });

    test('notificationsEnabled defaults to true and round-trips', () async {
      expect(source.notificationsEnabled, isTrue);

      await source.setNotificationsEnabled(false);
      expect(source.notificationsEnabled, isFalse);

      await source.setNotificationsEnabled(true);
      expect(source.notificationsEnabled, isTrue);
    });
  });
}
