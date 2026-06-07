import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/service_listing.dart';

/// Domain contract for reading and administering the service catalog.
///
/// Client-facing reads ([watchServices], [getById]) surface only the listings
/// clients are allowed to browse, while the admin mutations ([upsert],
/// [setActive], [delete]) back the listings-management screens. Concrete
/// implementations (e.g. a Firestore-backed repository with a Hive cache
/// fallback) are provided in the data layer.
abstract interface class ServiceRepository {
  /// Streams the catalog in real time, optionally filtered to a single
  /// [ServiceCategory]. Implementations surface active listings to clients.
  Stream<List<ServiceListing>> watchServices({ServiceCategory? category});

  /// Fetches a single [ServiceListing] by its [id].
  Future<ServiceListing> getById(String id);

  // --- Admin operations ---

  /// Creates or updates [listing] and returns its id.
  Future<String> upsert(ServiceListing listing);

  /// Toggles the `active` flag of the listing identified by [id].
  Future<void> setActive(String id, bool active);

  /// Permanently removes the listing identified by [id].
  Future<void> delete(String id);
}
