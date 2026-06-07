import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/section_header.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<AppState>().orders;
    final active = orders
        .where((o) =>
            o.status != OrderStatus.completed &&
            o.status != OrderStatus.cancelled)
        .toList();
    final past = orders
        .where((o) =>
            o.status == OrderStatus.completed ||
            o.status == OrderStatus.cancelled)
        .toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('My orders',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const _EmptyOrders()
          else ...[
            const SectionHeader(title: 'Active'),
            const SizedBox(height: 12),
            if (active.isEmpty)
              const _MutedNote('No active orders right now.')
            else
              ...active.map((o) => _OrderCard(order: o)),
            const SizedBox(height: 20),
            const SectionHeader(title: 'History'),
            const SizedBox(height: 12),
            if (past.isEmpty)
              const _MutedNote('Completed orders will appear here.')
            else
              ...past.map((o) => _OrderCard(order: o)),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final PreOrder order;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: () => _showDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${order.id}',
                    style: const TextStyle(
                        color: AppColors.slate,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                const Spacer(),
                StatusPill(
                  label: order.status.label,
                  color: order.status.color,
                  icon: order.status.icon,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(order.serviceTitle,
                style: Theme.of(context).textTheme.titleMedium),
            Text('${order.tierName} package',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            _ProgressTrack(status: order.status),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.event_rounded,
                    size: 15, color: AppColors.slate),
                const SizedBox(width: 5),
                Text('Due ${df.format(order.dueDate)}',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Text('\$${order.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Order #${order.id}',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                StatusPill(
                    label: order.status.label, color: order.status.color),
              ],
            ),
            const SizedBox(height: 16),
            Text(order.serviceTitle,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('${order.tierName} package · \$${order.amount.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text('Your brief',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(order.brief, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Horizontal milestone tracker mapped to OrderStatus.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.status});
  final OrderStatus status;

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.inProgress,
    OrderStatus.delivered,
    OrderStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    int currentIndex = _steps.indexOf(status);
    if (status == OrderStatus.inReview) currentIndex = 1;
    if (status == OrderStatus.cancelled) currentIndex = 0;
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = (i ~/ 2) < currentIndex;
          return Expanded(
            child: Container(
              height: 3,
              color: done ? AppColors.amber : AppColors.cloud,
            ),
          );
        }
        final idx = i ~/ 2;
        final done = idx <= currentIndex;
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: done ? AppColors.amberGradient : null,
            color: done ? null : AppColors.cloud,
          ),
          child: Icon(
            done ? Icons.check : Icons.circle,
            size: done ? 13 : 6,
            color: done ? AppColors.navy : AppColors.slate,
          ),
        );
      }),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 72, color: AppColors.cloud),
          const SizedBox(height: 16),
          Text('No orders yet',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('Browse services and place your first pre-order.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MutedNote extends StatelessWidget {
  const _MutedNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
