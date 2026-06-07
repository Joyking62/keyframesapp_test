import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/core/animations/count_up.dart';
import 'package:keyframes_app/core/animations/staggered_entrance.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/features/admin_dashboard/admin_controller.dart';

/// The admin overview tab with count-up KPI cards (Requirements 11.1, 14.2).
///
/// Renders three KPI cards — **New pre-orders**, **Active chats**, and
/// **Completed this month** — whose values are pulled from the derived count
/// providers in [admin_controller] and animated upward from zero with the
/// shared [CountUpText.integer] builder (Requirement 14.2). The cards enter
/// with a staggered fade/slide for a polished first impression.
class AdminOverviewScreen extends ConsumerWidget {
  /// Creates the admin overview screen.
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int newPreOrders = ref.watch(newPreOrdersCountProvider);
    final int activeChats = ref.watch(activeChatsCountProvider);
    final int completedThisMonth = ref.watch(completedThisMonthCountProvider);

    final List<_Kpi> kpis = <_Kpi>[
      _Kpi(
        label: 'New pre-orders',
        value: newPreOrders,
        icon: Icons.inbox_rounded,
        color: KColors.amber500,
      ),
      _Kpi(
        label: 'Active chats',
        value: activeChats,
        icon: Icons.forum_rounded,
        color: KColors.navy600,
      ),
      _Kpi(
        label: 'Completed this month',
        value: completedThisMonth,
        icon: Icons.task_alt_rounded,
        color: KColors.success,
      ),
    ];

    return Scaffold(
      backgroundColor: KColors.offWhite,
      appBar: AppBar(
        title: const Text('Overview'),
        backgroundColor: KColors.offWhite,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KSpace.lg,
            KSpace.md,
            KSpace.lg,
            KSpace.xxl,
          ),
          children: <Widget>[
            Text('Welcome back', style: KTextStyles.headingLg),
            const SizedBox(height: KSpace.xs),
            Text(
              'Here\'s how the Keyframes operation is doing today.',
              style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
            ),
            const SizedBox(height: KSpace.lg),
            for (int i = 0; i < kpis.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpace.md),
                child: StaggeredEntrance(
                  index: i,
                  child: _KpiCard(kpi: kpis[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Immutable description of a single KPI tile.
class _Kpi {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

/// A KPI card rendering an icon, the count-up value, and a label.
class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final _Kpi kpi;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kpi.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(KSpace.rMd),
            ),
            alignment: Alignment.center,
            child: Icon(kpi.icon, color: kpi.color, size: 28),
          ),
          const SizedBox(width: KSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CountUpText.integer(
                  kpi.value,
                  style: KTextStyles.displayLg.copyWith(color: kpi.color),
                ),
                const SizedBox(height: KSpace.xs),
                Text(
                  kpi.label,
                  style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
