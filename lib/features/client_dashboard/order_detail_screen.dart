import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_status_event.dart';
import 'package:keyframes_app/features/client_dashboard/client_dashboard_controller.dart';

/// The order detail / tracking screen (Requirement 10.2).
///
/// Watches [orderByIdProvider] for the given [orderId] and renders, in order:
///
/// * a header with the service title and the current [KStatusChip],
/// * a **status timeline** — a vertical stepper of every [OrderStatusEvent]
///   with its label, optional internal note, and timestamp,
/// * a **"Chat about this order"** entry point that opens the chat portal
///   (the linked conversation),
/// * a **service info** card (service title, package tier, budget, deadline),
/// * and a **requirements recap** card.
///
/// Loading and error states use the shared [KShimmer] / [KErrorView] widgets.
class OrderDetailScreen extends ConsumerWidget {
  /// Creates the order detail screen for the order identified by [orderId].
  const OrderDetailScreen({required this.orderId, super.key});

  /// The id of the order to display (the `/order/:id` path parameter).
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Order> orderAsync = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      backgroundColor: KColors.offWhite,
      appBar: AppBar(
        title: const Text('Order details'),
        backgroundColor: KColors.offWhite,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: orderAsync.when(
          data: (Order order) => _OrderDetailBody(order: order),
          loading: () => const _OrderDetailLoadingSkeleton(),
          error: (Object error, StackTrace stackTrace) => KErrorView(
            message: 'We could not load this order right now.',
            onRetry: () => ref.invalidate(orderByIdProvider(orderId)),
          ),
        ),
      ),
    );
  }
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.md,
        KSpace.lg,
        KSpace.xxl,
      ),
      children: <Widget>[
        // Header: service title + current status.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(order.serviceTitle, style: KTextStyles.headingMd),
            ),
            const SizedBox(width: KSpace.sm),
            KStatusChip(order.status),
          ],
        ),
        const SizedBox(height: KSpace.lg),

        // Status timeline.
        _SectionCard(
          title: 'Status timeline',
          child: _StatusTimeline(events: order.timeline),
        ),
        const SizedBox(height: KSpace.md),

        // Linked conversation entry point.
        _ChatEntryCard(
          onTap: () => context.push(KRoutes.chat),
        ),
        const SizedBox(height: KSpace.md),

        // Service information.
        _SectionCard(
          title: 'Service info',
          child: _ServiceInfo(order: order),
        ),
        const SizedBox(height: KSpace.md),

        // Requirements recap.
        _SectionCard(
          title: 'Requirements',
          child: Text(
            order.requirements.isEmpty
                ? 'No requirements were provided.'
                : order.requirements,
            style: KTextStyles.bodyMd.copyWith(
              color: order.requirements.isEmpty
                  ? KColors.slate500
                  : KColors.slate700,
            ),
          ),
        ),
      ],
    );
  }
}

/// A titled white card wrapper used for each detail section.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: KTextStyles.titleMd),
          const SizedBox(height: KSpace.md),
          child,
        ],
      ),
    );
  }
}

/// Vertical stepper rendering each [OrderStatusEvent] in the timeline.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.events});

  final List<OrderStatusEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text(
        'No status updates yet.',
        style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < events.length; i++)
          _TimelineRow(
            event: events[i],
            isFirst: i == 0,
            isLast: i == events.length - 1,
          ),
      ],
    );
  }
}

/// A single timeline entry: connector rail + dot, label, note, timestamp.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final OrderStatusEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color dotColor = _statusColor(event.status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Rail + node.
          Column(
            children: <Widget>[
              Container(
                width: 2,
                height: KSpace.sm,
                color: isFirst ? Colors.transparent : KColors.slate200,
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : KColors.slate200,
                ),
              ),
            ],
          ),
          const SizedBox(width: KSpace.md),
          // Content.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: KSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _statusLabel(event.status),
                    style: KTextStyles.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (event.note != null && event.note!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: KSpace.xs),
                    Text(event.note!, style: KTextStyles.bodyMd),
                  ],
                  const SizedBox(height: KSpace.xs),
                  Text(
                    _formatTimestamp(event.at),
                    style: KTextStyles.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Chat about this order" entry point linking to the conversation.
class _ChatEntryCard extends StatelessWidget {
  const _ChatEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KColors.navy600.withOpacity(0.12),
              borderRadius: BorderRadius.circular(KSpace.rMd),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: KColors.navy600,
            ),
          ),
          const SizedBox(width: KSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Chat about this order', style: KTextStyles.titleMd),
                const SizedBox(height: KSpace.xs),
                Text(
                  'Message our team about your project.',
                  style: KTextStyles.caption,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: KColors.slate500,
          ),
        ],
      ),
    );
  }
}

/// Service-info key/value rows (title, package, budget, deadline).
class _ServiceInfo extends StatelessWidget {
  const _ServiceInfo({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _InfoRow(label: 'Service', value: order.serviceTitle),
        _InfoRow(label: 'Package', value: _packageLabel(order.packageTier)),
        _InfoRow(
          label: 'Budget',
          value: order.budget != null
              ? '\$${order.budget!.toStringAsFixed(2)}'
              : 'Not specified',
        ),
        _InfoRow(
          label: 'Deadline',
          value: order.deadline != null
              ? _formatDate(order.deadline!)
              : 'Not specified',
        ),
      ],
    );
  }
}

/// A single label/value row within the service-info card.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: KTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer skeleton shown while the order is loading.
class _OrderDetailLoadingSkeleton extends StatelessWidget {
  const _OrderDetailLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.lg,
        KSpace.lg,
        KSpace.xxl,
      ),
      children: const <Widget>[
        KShimmer.box(height: 28, width: 200),
        SizedBox(height: KSpace.lg),
        KShimmer.box(height: 180),
        SizedBox(height: KSpace.md),
        KShimmer.box(height: 72),
        SizedBox(height: KSpace.md),
        KShimmer.box(height: 140),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

String _packageLabel(PackageTier tier) {
  switch (tier) {
    case PackageTier.basic:
      return 'Basic package';
    case PackageTier.standard:
      return 'Standard package';
    case PackageTier.premium:
      return 'Premium package';
  }
}

String _statusLabel(OrderStatus status) {
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

Color _statusColor(OrderStatus status) {
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

const List<String> _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a date as e.g. `5 Jun 2026`.
String _formatDate(DateTime date) {
  final DateTime d = date.toLocal();
  final String month =
      (d.month >= 1 && d.month <= 12) ? _monthNames[d.month - 1] : '${d.month}';
  return '${d.day} $month ${d.year}';
}

/// Formats a timestamp as e.g. `5 Jun 2026 · 14:05`.
String _formatTimestamp(DateTime date) {
  final DateTime d = date.toLocal();
  final String hh = d.hour.toString().padLeft(2, '0');
  final String mm = d.minute.toString().padLeft(2, '0');
  return '${_formatDate(d)} \u00B7 $hh:$mm';
}
