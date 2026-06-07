import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/animations/staggered_entrance.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/features/client_dashboard/client_dashboard_controller.dart';

/// The client's orders dashboard tab (Requirement 10.1, 10.3, 10.5).
///
/// Watches [clientOrdersProvider] — which is already scoped to the signed-in
/// client on the data layer — and renders the orders grouped into four
/// sections in lifecycle order: **Pending**, **In Progress** (combining
/// `inReview` + `inProgress`), **Completed**, and **Cancelled**. Each order is
/// a [KCard] showing the service title, a [KStatusChip], and a step-based
/// progress indicator derived from its status/timeline.
///
/// Tapping a card navigates to the order-detail route. When the client has no
/// orders at all, a friendly empty state with a "Browse services" CTA is shown
/// that routes back to the home/catalog tab (Requirement 10.5). Loading and
/// error states are rendered with the shared [KShimmer] / [KErrorView] widgets.
class ClientOrdersScreen extends ConsumerWidget {
  /// Creates the client orders dashboard screen.
  const ClientOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Order>> ordersAsync = ref.watch(clientOrdersProvider);

    return Scaffold(
      backgroundColor: KColors.offWhite,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: KColors.offWhite,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ordersAsync.when(
          data: (List<Order> orders) => _OrdersBody(orders: orders),
          loading: () => const _OrdersLoadingSkeleton(),
          error: (Object error, StackTrace stackTrace) => KErrorView(
            message: 'We could not load your orders right now.',
            onRetry: () => ref.invalidate(clientOrdersProvider),
          ),
        ),
      ),
    );
  }
}

/// Renders the grouped sections (or the empty state when there are no orders).
class _OrdersBody extends StatelessWidget {
  const _OrdersBody({required this.orders});

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _OrdersEmptyState();
    }

    // Group orders by display section while preserving lifecycle order.
    final List<Order> pending = <Order>[];
    final List<Order> inProgress = <Order>[];
    final List<Order> completed = <Order>[];
    final List<Order> cancelled = <Order>[];

    for (final Order order in orders) {
      switch (order.status) {
        case OrderStatus.pending:
          pending.add(order);
          break;
        case OrderStatus.inReview:
        case OrderStatus.inProgress:
          inProgress.add(order);
          break;
        case OrderStatus.completed:
          completed.add(order);
          break;
        case OrderStatus.cancelled:
          cancelled.add(order);
          break;
      }
    }

    final List<_OrderSection> sections = <_OrderSection>[
      _OrderSection(title: 'Pending', orders: pending),
      _OrderSection(title: 'In Progress', orders: inProgress),
      _OrderSection(title: 'Completed', orders: completed),
      _OrderSection(title: 'Cancelled', orders: cancelled),
    ].where((_OrderSection s) => s.orders.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.md,
        KSpace.lg,
        KSpace.xxl,
      ),
      children: <Widget>[
        for (final _OrderSection section in sections)
          _OrdersSectionView(section: section),
      ],
    );
  }
}

/// A titled group of orders with its cards.
class _OrdersSectionView extends StatelessWidget {
  const _OrdersSectionView({required this.section});

  final _OrderSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            top: KSpace.md,
            bottom: KSpace.sm,
          ),
          child: Row(
            children: <Widget>[
              Text(section.title, style: KTextStyles.headingMd),
              const SizedBox(width: KSpace.sm),
              Text(
                '${section.orders.length}',
                style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
              ),
            ],
          ),
        ),
        for (int i = 0; i < section.orders.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.md),
            child: StaggeredEntrance(
              index: i,
              child: _OrderCard(order: section.orders[i]),
            ),
          ),
      ],
    );
  }
}

/// A single order card: service title, status chip, and step progress.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: () => context.push(KRoutes.orderDetailPath(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  order.serviceTitle,
                  style: KTextStyles.titleMd,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: KSpace.sm),
              KStatusChip(order.status),
            ],
          ),
          const SizedBox(height: KSpace.xs),
          Text(
            _packageLabel(order.packageTier),
            style: KTextStyles.caption,
          ),
          const SizedBox(height: KSpace.md),
          _OrderProgressBar(status: order.status),
        ],
      ),
    );
  }
}

/// A four-step progress indicator derived from the order [status].
///
/// Steps map to the linear lifecycle Pending -> In Review -> In Progress ->
/// Completed. A cancelled order is rendered as a single full-width danger bar
/// since it left the linear flow.
class _OrderProgressBar extends StatelessWidget {
  const _OrderProgressBar({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) {
      return Row(
        children: <Widget>[
          Expanded(
            child: _StepBar(filled: true, color: KColors.danger),
          ),
        ],
      );
    }

    // Number of completed steps out of four, based on lifecycle position.
    final int reached = switch (status) {
      OrderStatus.pending => 1,
      OrderStatus.inReview => 2,
      OrderStatus.inProgress => 3,
      OrderStatus.completed => 4,
      OrderStatus.cancelled => 0,
    };

    final Color color =
        status == OrderStatus.completed ? KColors.success : KColors.navy600;

    return Row(
      children: <Widget>[
        for (int step = 1; step <= 4; step++) ...<Widget>[
          Expanded(
            child: _StepBar(filled: step <= reached, color: color),
          ),
          if (step < 4) const SizedBox(width: KSpace.xs),
        ],
      ],
    );
  }
}

/// A single rounded progress segment.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.filled, required this.color});

  final bool filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: filled ? color : KColors.slate200,
        borderRadius: BorderRadius.circular(KSpace.rPill),
      ),
    );
  }
}

/// Empty state shown when the client has no orders (Requirement 10.5).
class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.receipt_long_rounded,
              size: 56,
              color: KColors.slate500,
            ),
            const SizedBox(height: KSpace.lg),
            Text(
              'No orders yet',
              textAlign: TextAlign.center,
              style: KTextStyles.headingMd,
            ),
            const SizedBox(height: KSpace.sm),
            Text(
              'Browse our services and place your first pre-order to start '
              'tracking it here.',
              textAlign: TextAlign.center,
              style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
            ),
            const SizedBox(height: KSpace.xl),
            KPrimaryButton(
              label: 'Browse services',
              icon: Icons.search_rounded,
              onPressed: () => context.go(KRoutes.home),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton mirroring the grouped order list while loading.
class _OrdersLoadingSkeleton extends StatelessWidget {
  const _OrdersLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.lg,
        KSpace.lg,
        KSpace.xxl,
      ),
      children: <Widget>[
        const KShimmer.box(height: 24, width: 140),
        const SizedBox(height: KSpace.md),
        for (int i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: KSpace.md),
            child: KShimmer.box(height: 116),
          ),
      ],
    );
  }
}

/// A display grouping of orders under a section title.
class _OrderSection {
  const _OrderSection({required this.title, required this.orders});

  final String title;
  final List<Order> orders;
}

/// Human-readable label for a [PackageTier].
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
