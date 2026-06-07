import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../theme/k_colors.dart';
import '../theme/k_space.dart';
import '../theme/k_text_styles.dart';

/// Pill chip that maps an [OrderStatus] to its brand color and label.
///
/// Implements the shared status-chip mapping required by the design system
/// (Requirement 13.5) so that order state is communicated consistently across
/// the client and admin dashboards. The chip tints a soft background derived
/// from the status color and renders the label in that color.
class KStatusChip extends StatelessWidget {
  /// Creates a status chip for the given [status].
  const KStatusChip(this.status, {super.key});

  /// The order status to visualize.
  final OrderStatus status;

  /// The brand color associated with [status].
  Color get color => _colorFor(status);

  /// The human-readable label associated with [status].
  String get label => _labelFor(status);

  static Color _colorFor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return KColors.warning;
      case OrderStatus.inReview:
        return KColors.navy400;
      case OrderStatus.inProgress:
        return KColors.navy600;
      case OrderStatus.completed:
        return KColors.success;
      case OrderStatus.cancelled:
        return KColors.danger;
    }
  }

  static String _labelFor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.inReview:
        return 'In Review';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpace.md,
        vertical: KSpace.xs,
      ),
      decoration: BoxDecoration(
        // Soft tinted background from the status color.
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(KSpace.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: KSpace.sm),
          Text(
            label,
            style: KTextStyles.label.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
