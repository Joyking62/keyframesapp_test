import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/section_header.dart';

class AdminOrders extends StatefulWidget {
  const AdminOrders({super.key});

  @override
  State<AdminOrders> createState() => _AdminOrdersState();
}

class _AdminOrdersState extends State<AdminOrders> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppState>().orders;
    final orders =
        _filter == null ? all : all.where((o) => o.status == _filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text('Manage orders',
              style: Theme.of(context).textTheme.headlineMedium),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _filterChip('All', _filter == null,
                  () => setState(() => _filter = null)),
              ...OrderStatus.values.map((s) => _filterChip(
                    s.label,
                    _filter == s,
                    () => setState(() => _filter = s),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: orders.length,
            itemBuilder: (context, i) => _AdminOrderCard(order: orders[i]),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.navy,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({required this.order});
  final PreOrder order;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
              StatusPill(label: order.status.label, color: order.status.color),
            ],
          ),
          const SizedBox(height: 8),
          Text(order.serviceTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 14, color: AppColors.slate),
              const SizedBox(width: 4),
              Text(order.clientName,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 12),
              const Icon(Icons.event_rounded, size: 14, color: AppColors.slate),
              const SizedBox(width: 4),
              Text('Due ${df.format(order.dueDate)}',
                  style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text('\$${order.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.navy)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(order.brief,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy600,
                    side: const BorderSide(color: AppColors.cloud),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _changeStatus(context),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy600,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _changeStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Update status · #${order.id}',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ...OrderStatus.values.map((s) => ListTile(
                  leading: Icon(s.icon, color: s.color),
                  title: Text(s.label),
                  trailing: order.status == s
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.success)
                      : null,
                  onTap: () {
                    context.read<AppState>().updateOrderStatus(order.id, s);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
