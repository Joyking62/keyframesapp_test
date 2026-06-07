import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'order_draft.freezed.dart';

/// Immutable input value object for [OrderRepository.createOrder].
///
/// Captures everything the pre-order flow collects before an [Order] is
/// persisted. Validation (requirements length >= 10, future deadline, a
/// selected [PackageTier]) is applied by the order service on submission.
@freezed
class OrderDraft with _$OrderDraft {
  const factory OrderDraft({
    /// The selected [ServiceListing] id.
    required String serviceId,

    /// Denormalized service title for display on the order summary.
    required String serviceTitle,

    /// The chosen package tier.
    required PackageTier packageTier,

    /// Free-text requirements (validated to be at least 10 chars).
    required String requirements,

    /// References to uploaded attachment files.
    @Default(<String>[]) List<String> attachments,

    /// Optional budget figure.
    double? budget,

    /// Optional desired deadline (must be in the future if set).
    DateTime? deadline,
  }) = _OrderDraft;
}
