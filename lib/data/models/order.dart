import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'order_status_event.dart';

part 'order.freezed.dart';
part 'order.g.dart';

/// A client's pre-order for a [ServiceListing].
///
/// An order always references the service it was placed against
/// ([serviceId]/[serviceTitle]), tracks its lifecycle through [status] and the
/// append-only [timeline], and is created with [OrderStatus.pending].
@freezed
class Order with _$Order {
  const factory Order({
    required String id,
    required String clientId,
    required String serviceId,
    required String serviceTitle,
    required PackageTier packageTier,
    required String requirements,
    @Default(<String>[]) List<String> attachments,
    double? budget,
    DateTime? deadline,
    @Default(OrderStatus.pending) OrderStatus status,
    @Default(<OrderStatusEvent>[]) List<OrderStatusEvent> timeline,
    required DateTime createdAt,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
}
