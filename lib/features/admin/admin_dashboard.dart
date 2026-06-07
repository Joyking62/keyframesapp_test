import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/section_header.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('Overview', style: Theme.of(context).textTheme.headlineMedium),
        Text('Here is how Keyframes is performing this week.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 18),
        // KPI grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _KpiCard(
              label: 'Revenue',
              value: '\$${app.totalRevenue.toStringAsFixed(0)}',
              icon: Icons.payments_rounded,
              gradient: AppColors.amberGradient,
              dark: true,
            ),
            _KpiCard(
              label: 'Active orders',
              value: '${app.activeOrders}',
              icon: Icons.timelapse_rounded,
              gradient: AppColors.navyGradient,
            ),
            _KpiCard(
              label: 'Completed',
              value: '${app.completedOrders}',
              icon: Icons.verified_rounded,
              gradient: AppColors.navyGradient,
            ),
            _KpiCard(
              label: 'Total orders',
              value: '${app.orders.length}',
              icon: Icons.receipt_long_rounded,
              gradient: AppColors.navyGradient,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Weekly revenue'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SizedBox(
            height: 180,
            child: _RevenueBarChart(
              values: MockData.weeklyRevenue,
              labels: MockData.weekDays,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Recent orders',
          actionLabel: 'Manage',
          onAction: () {},
        ),
        const SizedBox(height: 12),
        ...app.orders.take(4).map((o) => _MiniOrderRow(order: o)),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    this.dark = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.navy : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const Spacer(),
              Icon(Icons.trending_up_rounded, color: fg.withOpacity(0.7),
                  size: 18),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: fg,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(
                      color: fg.withOpacity(0.85), fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lightweight animated bar chart (no external chart dependency).
class _RevenueBarChart extends StatefulWidget {
  const _RevenueBarChart({required this.values, required this.labels});
  final List<double> values;
  final List<String> labels;

  @override
  State<_RevenueBarChart> createState() => _RevenueBarChartState();
}

class _RevenueBarChartState extends State<_RevenueBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxV = widget.values.reduce((a, b) => a > b ? a : b);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.values.length, (i) {
            final t = Curves.easeOutCubic.transform(
                (_c.value * widget.values.length - i).clamp(0.0, 1.0));
            final h = (widget.values[i] / maxV) * 130 * t;
            final isPeak = widget.values[i] == maxV;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '\$${widget.values[i].toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 9,
                      color: isPeak ? AppColors.amberDeep : AppColors.slate,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 16,
                    height: h,
                    decoration: BoxDecoration(
                      gradient: isPeak
                          ? AppColors.amberGradient
                          : AppColors.navyGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(widget.labels[i],
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.slate)),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class _MiniOrderRow extends StatelessWidget {
  const _MiniOrderRow({required this.order});
  final PreOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.navy600,
            child: Text(
              order.clientName.characters.first,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.serviceTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('${order.clientName} · #${order.id}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          StatusPill(label: order.status.label, color: order.status.color),
        ],
      ),
    );
  }
}
