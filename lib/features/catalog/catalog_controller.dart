import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/core/utils/connectivity.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/service_listing.dart';

/// Presentation-layer controllers for the service catalog (Requirement 6).
///
/// The catalog screen is driven by two small providers:
///
/// * [selectedCategoryProvider] — the currently selected category filter. A
///   `null` value means "all categories" (no chip selected). Tapping a
///   category chip toggles this state, which in turn re-points the catalog
///   stream at the matching [ServiceCategory].
/// * [catalogControllerProvider] — a `family` [StreamProvider] keyed by the
///   optional [ServiceCategory]. It surfaces the live catalog stream from the
///   [ServiceRepository], which already filters to `active`-only listings and
///   falls back to the offline cache on fetch failure (Requirements 6.3, 6.8).
///
/// Keeping the selected-category state and the stream separate lets the UI
/// watch `catalogControllerProvider(ref.watch(selectedCategoryProvider))` so
/// that flipping a chip rebuilds only the catalog list, not the whole screen.

/// The currently selected catalog category filter.
///
/// `null` represents the "all" selection (no specific category chip active).
/// The home screen reads this to decide which chip is highlighted and which
/// argument to pass to [catalogControllerProvider].
final selectedCategoryProvider = StateProvider<ServiceCategory?>((ref) => null);

/// Whether the catalog is currently being served from the offline cache
/// because the live fetch is unavailable (Requirements 6.6, 17.1).
///
/// When `true`, the home screen shows an offline banner above the catalog
/// while still rendering the last-known [Cached_Catalog] listings. The flag is
/// toggled by [catalogControllerProvider] (set `false` whenever a live
/// snapshot arrives, `true` when the live stream errors) and may additionally
/// be driven by the connectivity-aware auto-retry wiring (task 24.1).
///
/// Note: [ServiceRepository.watchServices] currently *silently* falls back to
/// the cache on a fetch failure (it yields the cached listings instead of
/// surfacing the error), so in production this flag is primarily driven by the
/// connectivity layer rather than the stream's error channel. Exposing it as a
/// standalone [StateProvider] keeps the banner trivially testable — a widget
/// test can override it to assert the offline-with-cache rendering.
final catalogOfflineProvider = StateProvider<bool>((ref) => false);

/// Streams the catalog filtered by the given [ServiceCategory] (or all
/// categories when the argument is `null`).
///
/// Delegates to [ServiceRepository.watchServices], which emits only active
/// listings and transparently serves the cached catalog when the live fetch
/// fails. Because this is a `family` provider, each distinct category argument
/// (including `null`) gets its own independently-cached subscription, so
/// toggling between chips is instant after the first load of each.
///
/// As snapshots flow through, the provider keeps [catalogOfflineProvider] in
/// sync with the live connectivity signal ([isOnlineProvider]): while offline
/// the flag is set (so the banner shows above the cached listings the
/// repository transparently serves), and a regained connection both clears the
/// flag and rebuilds this provider so `watchServices` is re-subscribed
/// (auto-retry, Requirements 17.1, 17.2). The state mutations are deferred to a
/// microtask so they never run during another provider's build.
final catalogControllerProvider =
    StreamProvider.family<List<ServiceListing>, ServiceCategory?>(
  (ref, category) {
    final repository = ref.watch(serviceRepositoryProvider);

    // Re-subscribe to the live catalog whenever connectivity changes so a
    // failed/offline fetch is automatically retried the moment the network is
    // regained (Requirement 17.2). Watching the value (defaulting to online
    // while the probe is still resolving) rebuilds this family provider on
    // every online<->offline transition, which re-runs `watchServices`.
    final bool online = ref.watch(isOnlineProvider).valueOrNull ?? true;

    void setOffline(bool offline) {
      // Defer to avoid mutating a provider during a synchronous build pass.
      Future<void>.microtask(() {
        if (ref.read(catalogOfflineProvider) != offline) {
          ref.read(catalogOfflineProvider.notifier).state = offline;
        }
      });
    }

    return repository.watchServices(category: category).map(
      (List<ServiceListing> listings) {
        // The repository transparently serves cached listings when the live
        // fetch is unavailable (so the stream itself does not error), so the
        // offline banner is driven by the connectivity signal: render the
        // cached catalog plus the banner whenever there is no network
        // (Requirement 17.1).
        setOffline(!online);
        return listings;
      },
    ).handleError((Object _) {
      // The live stream failed; flag offline so the banner is shown alongside
      // whatever cached data the repository surfaced.
      setOffline(true);
    });
  },
);

/// Fetches a single [ServiceListing] by its id for the service-detail screen
/// (Requirement 7).
///
/// A `family` [FutureProvider] keyed by the listing id, delegating to
/// [ServiceRepository.getById]. The detail screen watches this provider and
/// renders its `loading` / `data` / `error` states via [AsyncValue.when];
/// `ref.invalidate(serviceByIdProvider(id))` re-runs the fetch on retry.
final serviceByIdProvider =
    FutureProvider.family<ServiceListing, String>((ref, id) {
  return ref.watch(serviceRepositoryProvider).getById(id);
});
