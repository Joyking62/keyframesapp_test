import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';

part 'order_status_event.freezed.dart';
part 'order_status_event.g.dart';

/// A single entry in an [Order]'s status timeline.
///
/// Each transition of an order's [OrderStatus] appends one event, optionally
/// carrying an internal [note], timestamped with [at].
@freezed
class OrderStatusEvent with _$OrderStatusEvent {
  const factory OrderStatusEvent({
    required OrderStatus status,
    String? note,
    required DateTime at,
  }) = _OrderStatusEvent;

  factory OrderStatusEvent.fromJson(Map<String, dynamic> json) =>
      _$OrderStatusEventFromJson(json);
}
