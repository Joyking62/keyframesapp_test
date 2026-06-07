import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/data/repositories/service_repository.dart';
import 'package:keyframes_app/data/sources/local_source.dart';

/// Firestore-backed [ServiceRepository] with an offline-first cache fallback.
///
/// Reads stream from the `services` collection in Cloud Firestore and are
/// **written through** to the Hive-backed [LocalSource] cache on every
/// snapshot, so a cold start or a transient backend failure can still render
/// the last-known catalog (Requirements 6.6, 17.1, 17.2). When the live stream
/// errors, the repository emits the cached catalog as a graceful fallback
/// instead of surfacing the error to the UI.
///
/// Client-facing reads ([watchServices], [getById]) surface only listings
/// clients may browse (active-only by default), while the admin mutations
/// ([upsert], [setActive], [delete]) back the listings-management screens
/// (Requirements 11.5, 11.6).
///
/// ### Document <-> model mapping
/// The Firestore document **id is the source of truth** for
/// [ServiceListing.id]: it is injected when reading and stripped from the
/// stored payload when writing, so the id is never duplicated inside the
/// document body.
class FirebaseServiceRepository implements ServiceRepository {
  /// Creates a repository backed by [firestore] and caching through [local].
  FirebaseServiceRepository({
    required FirebaseFirestore firestore,
    required LocalSource local,
  })  : _firestore = firestore,
        _local = local;

  /// Name of the Firestore collection holding the service catalog.
  static const String collectionPath = 'services';

  /// Firestore document field name for the active flag.
  static const String _activeField = 'active';

  /// Firestore document field name for the category.
  static const String _categoryField = 'category';

  final FirebaseFirestore _firestore;
  final LocalSource _local;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionPath);

  // --------------------------------------------------------------------------
  // Client-facing reads
  // --------------------------------------------------------------------------

  @override
  Stream<List<ServiceListing>> watchServices({ServiceCategory? category}) async* {
    final query = _buildQuery(category: category);

    try {
      await for (final snapshot in query.snapshots()) {
        final listings =
            snapshot.docs.map(_listingFromDoc).toList(growable: false);
        // Write-through: keep the offline cache in sync with the latest data.
        await _local.writeCatalog(listings);
        yield listings;
      }
    } catch (_) {
      // Fallback: surface the last-known catalog when the live stream fails,
      // re-applying the same active-only + category filter for consistency.
      yield cachedListings(category: category);
    }
  }

  @override
  Future<ServiceListing> getById(String id) async {
    final snapshot = await _collection.doc(id).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw StateError('Service listing not found: $id');
    }
    return _listingFromData(snapshot.id, data);
  }

  // --------------------------------------------------------------------------
  // Admin operations
  // --------------------------------------------------------------------------

  @override
  Future<String> upsert(ServiceListing listing) async {
    final data = _listingToData(listing);

    if (listing.id.isEmpty) {
      // Create: let Firestore allocate a fresh document id.
      final ref = await _collection.add(data);
      return ref.id;
    }

    // Update/create at a known id, merging so partial payloads are safe.
    await _collection.doc(listing.id).set(data, SetOptions(merge: true));
    return listing.id;
  }

  @override
  Future<void> setActive(String id, bool active) {
    return _collection.doc(id).update(<String, Object?>{_activeField: active});
  }

  @override
  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }

  // --------------------------------------------------------------------------
  // Internal helpers
  // --------------------------------------------------------------------------

  /// Builds the catalog query: active listings only, optionally narrowed to a
  /// single [category].
  Query<Map<String, dynamic>> _buildQuery({ServiceCategory? category}) {
    Query<Map<String, dynamic>> query =
        _collection.where(_activeField, isEqualTo: true);
    if (category != null) {
      query = query.where(_categoryField, isEqualTo: category.name);
    }
    return query;
  }

  /// Reads the cached catalog and re-applies the active-only + [category]
  /// filter so the fallback matches what the live query would have returned.
  ///
  /// Exposed for testing: this is the exact filtering applied in the
  /// [watchServices] error-fallback branch, so a test can populate the injected
  /// [LocalSource] cache and assert the offline behavior (Requirements 6.8,
  /// 17.1) without a live Firestore stream.
  @visibleForTesting
  List<ServiceListing> cachedListings({ServiceCategory? category}) {
    return _local
        .readCatalog()
        .where((listing) => listing.active)
        .where((listing) => category == null || listing.category == category)
        .toList(growable: false);
  }

  /// Maps a Firestore document to a [ServiceListing], using the document id as
  /// the listing id.
  ServiceListing _listingFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _listingFromData(doc.id, doc.data());
  }

  /// Reconstructs a [ServiceListing] from raw document [data], injecting the
  /// document [id] (the source of truth) into the JSON payload.
  ServiceListing _listingFromData(String id, Map<String, dynamic> data) {
    return ServiceListing.fromJson(<String, dynamic>{...data, 'id': id});
  }

  /// Serializes a [ServiceListing] for storage, stripping the `id` so it is not
  /// duplicated inside the document body (the document id owns the identity).
  Map<String, dynamic> _listingToData(ServiceListing listing) {
    final json = listing.toJson()..remove('id');
    return json;
  }
}
