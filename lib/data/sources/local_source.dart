import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_listing.dart';

/// Local, device-side data source for the Keyframes app.
///
/// Combines two persistence mechanisms behind a single, testable API:
///
/// * **Hive** holds the offline-first `Cached_Catalog` — a serialized copy of
///   the [ServiceListing]s last fetched from the backend. It powers cold-start
///   rendering and the offline banner when a network fetch fails
///   (Requirements 1.3, 6.6, 17.1).
/// * **shared_preferences** holds lightweight flags and user preferences: the
///   `seenOnboarding` flag (Requirements 3.3, 3.4) plus theme and notification
///   preferences edited from the client profile.
///
/// The boxes/preferences are opened lazily via [init], which is invoked once
/// during application start-up (after `Hive.initFlutter()` in `main`). For
/// tests, a pre-opened [Box] and/or [SharedPreferences] instance can be
/// injected through the constructor so an in-memory/temp Hive setup can be used
/// without touching real device storage.
class LocalSource {
  /// Creates a [LocalSource].
  ///
  /// Both [catalogBox] and [preferences] are optional. When provided (e.g. in
  /// tests) they are used directly and [init] becomes a no-op for that
  /// dependency. When omitted, [init] opens/loads them.
  LocalSource({Box<String>? catalogBox, SharedPreferences? preferences})
      : _catalogBox = catalogBox,
        _preferences = preferences;

  /// Name of the Hive box that stores the cached catalog.
  static const String catalogBoxName = 'cached_catalog';

  /// Key under which the serialized catalog list is stored in the Hive box.
  static const String catalogKey = 'catalog_listings';

  /// shared_preferences key for the onboarding-seen flag.
  static const String seenOnboardingKey = 'seenOnboarding';

  /// shared_preferences key for the persisted [ThemeMode].
  static const String themeModeKey = 'themeMode';

  /// shared_preferences key for the notifications-enabled flag.
  static const String notificationsEnabledKey = 'notificationsEnabled';

  Box<String>? _catalogBox;
  SharedPreferences? _preferences;

  /// Opens the Hive catalog box and loads shared_preferences.
  ///
  /// Safe to call multiple times; already-open resources (or those injected via
  /// the constructor) are reused. Requires `Hive.initFlutter()` to have been
  /// called beforehand (done in `main`).
  Future<void> init() async {
    if (_catalogBox == null) {
      _catalogBox = Hive.isBoxOpen(catalogBoxName)
          ? Hive.box<String>(catalogBoxName)
          : await Hive.openBox<String>(catalogBoxName);
    }
    _preferences ??= await SharedPreferences.getInstance();
  }

  Box<String> get _box {
    final box = _catalogBox;
    if (box == null) {
      throw StateError('LocalSource.init() must be called before use.');
    }
    return box;
  }

  SharedPreferences get _prefs {
    final prefs = _preferences;
    if (prefs == null) {
      throw StateError('LocalSource.init() must be called before use.');
    }
    return prefs;
  }

  // --------------------------------------------------------------------------
  // Onboarding flag (Requirements 3.3, 3.4)
  // --------------------------------------------------------------------------

  /// Whether the user has already completed/skipped onboarding.
  ///
  /// Defaults to `false` so a brand-new install is routed to onboarding.
  bool get seenOnboarding => _prefs.getBool(seenOnboardingKey) ?? false;

  /// Persists the [seenOnboarding] flag.
  Future<void> setSeenOnboarding(bool value) =>
      _prefs.setBool(seenOnboardingKey, value);

  // --------------------------------------------------------------------------
  // Theme preference
  // --------------------------------------------------------------------------

  /// The user's preferred [ThemeMode]. Defaults to [ThemeMode.system].
  ThemeMode get themeMode {
    final stored = _prefs.getString(themeModeKey);
    if (stored == null) return ThemeMode.system;
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  /// Persists the user's preferred [ThemeMode].
  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(themeModeKey, mode.name);

  // --------------------------------------------------------------------------
  // Notification preference
  // --------------------------------------------------------------------------

  /// Whether the user has notifications enabled. Defaults to `true`.
  bool get notificationsEnabled =>
      _prefs.getBool(notificationsEnabledKey) ?? true;

  /// Persists the notifications-enabled preference.
  Future<void> setNotificationsEnabled(bool value) =>
      _prefs.setBool(notificationsEnabledKey, value);

  // --------------------------------------------------------------------------
  // Cached catalog (Requirements 1.3, 6.6, 17.1)
  // --------------------------------------------------------------------------

  /// Whether a non-empty cached catalog is currently available.
  bool get hasCachedCatalog {
    final raw = _box.get(catalogKey);
    return raw != null && raw.isNotEmpty;
  }

  /// Writes the given [listings] to the Hive cache, replacing any prior copy.
  ///
  /// Each listing is serialized through [ServiceListing.toJson]; the resulting
  /// list is JSON-encoded into a single string entry for robust round-tripping.
  Future<void> writeCatalog(List<ServiceListing> listings) async {
    final encoded =
        jsonEncode(listings.map((listing) => listing.toJson()).toList());
    await _box.put(catalogKey, encoded);
  }

  /// Reads the cached catalog back, reconstructing each [ServiceListing] via
  /// [ServiceListing.fromJson]. Returns an empty list when nothing is cached.
  List<ServiceListing> readCatalog() {
    final raw = _box.get(catalogKey);
    if (raw == null || raw.isEmpty) return const <ServiceListing>[];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (entry) => ServiceListing.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .toList();
  }

  /// Clears the cached catalog from the Hive box.
  Future<void> clearCatalog() => _box.delete(catalogKey);
}
