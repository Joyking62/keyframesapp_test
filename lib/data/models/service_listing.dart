import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';

part 'service_listing.freezed.dart';
part 'service_listing.g.dart';

/// A single service offering in the Keyframes catalog.
///
/// Listings are the only purchasable unit in the marketplace — clients
/// pre-order a [ServiceListing], never an individual employee.
@freezed
class ServiceListing with _$ServiceListing {
  const factory ServiceListing({
    required String id,
    required String title,
    required String tagline,
    required String description,
    required ServiceCategory category,
    required double basePrice,
    @Default(<String>[]) List<String> deliverables,
    @Default(<String>[]) List<String> gallery,
    String? thumbnailUrl,
    @Default(true) bool active,
    @Default(0) int estimatedDays,
  }) = _ServiceListing;

  factory ServiceListing.fromJson(Map<String, dynamic> json) =>
      _$ServiceListingFromJson(json);
}
