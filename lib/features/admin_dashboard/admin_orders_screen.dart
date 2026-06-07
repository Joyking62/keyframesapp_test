import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/animations/staggered_entrance.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/features/admin_dashboard/admin_controller.dart';
import 'package:keyframes_app/features/order/default_order_service.dart';

/// The admin orders-management screen (Requirements 11.2, 11.3, 10A.1, 10A.4).
///
/// Lists **all** orders from [allOrdersProvider] and lets the admin narrow the
/// list with status filter chips and a free-text search over the service title
/// and order id. Each order row shows a [KStatusChip] and an "Update status"
/// control that opens a sheet offering only the *valid* next statuses (computed
/// via the order service) plus an optional internal note. Applying a change
/// routes through [OrderRepository.updateStatus] so the order service's
/// transition validation applies (Requirement 11.3); an illegal transition
/// surfaces an [InvalidOrderTransitionException], which is caught and shown as a
/// SnackBar without mutating the order (Requirement 10A.4). Tapping a row opens
/// the order detail screen.
class AdminOrdersScreen extends ConsumerStatefulWidget {
  /// Creates the admin orders-management screen.
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  /// The active status filter; `null` means "All".
  OrderStatus? _statusFilter;

  /// The current lowercase search query (matched against title and id).
  String _query = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Order> _applyFilters(List<Order> orders) {
    Iterable<Order> filtered = orders;
    final OrderStatus? statusFilter = _statusFilter;
    if (statusFilter != null) {
      filtered = filtered.where((Order o) => o.status == statusFilter);
    }
    final String query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((Order o) =>
          o.serviceTitle.toLowerCase().contains(query) ||
          o.id.toLowerCase().contains(query));
    }
    final List<Order> result = filtered.toList()
      ..sort((Order a, Order b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Order>> ordersAsync =
        ref.watch(allOrdersProvider(null));

    return Scaffold(
      backgroundColor: KColors.offWhite,
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: KColors.offWhite,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _SearchField(
              controller: _searchController,
              onChanged: (String value) => setState(() => _query = value),
            ),
            _StatusFilterBar(
              selected: _statusFilter,
              onSelected: (OrderStatus? status) =>
                  setState(() => _statusFilter = status),
            ),
            Expanded(
              child: ordersAsync.when(
                data: (List<Order> orders) {
                  final List<Order> visible = _applyFilters(orders);
                  if (visible.isEmpty) {
                    return const _OrdersEmpty();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.lg,
                      KSpace.md,
                      KSpace.lg,
                      KSpace.xxl,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Order order = visible[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: KSpace.md),
                        child: StaggeredEntrance(
                          index: index,
                          child: _AdminOrderCard(
                            order: order,
                            onUpdateStatus: () => _openStatusSheet(order),
                            onOpen: () => context
                                .push(KRoutes.orderDetailPath(order.id)),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const _OrdersLoading(),
                error: (Object error, StackTrace _) => KErrorView(
                  message: 'We could not load orders right now.',
                  onRetry: () => ref.invalidate(allOrdersProvider(null)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the status-update sheet for [order] and applies the selected change.
  Future<void> _openStatusSheet(Order order) async {
    final DefaultOrderService service = ref.read(orderServiceProvider);
    final List<OrderStatus> validNext = OrderStatus.values
        .where((OrderStatus s) => service.isValidTransition(order.status, s))
        .toList();

    final _StatusUpdateRequest? request =
        await showModalBottomSheet<_StatusUpdateRequest>(
      context: context,
      backgroundColor: KColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpace.rXl)),
      ),
      builder: (BuildContext sheetContext) => _StatusUpdateSheet(
        order: order,
        validNext: validNext,
      ),
    );

    if (request == null || !mounted) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orderRepositoryProvider).updateStatus(
            order.id,
            request.status,
            note: request.note,
          );
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Order updated to ${_statusLabel(request.status)}.'),
            backgroundColor: KColors.success,
          ),
        );
    } on InvalidOrderTransitionException catch (e) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Cannot move from ${_statusLabel(e.from)} to '
              '${_statusLabel(e.to)}.',
            ),
            backgroundColor: KColors.danger,
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not update the order. Please try again.'),
            backgroundColor: KColors.danger,
          ),
        );
    }
  }
}

/// The free-text search field over service title and order id.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.lg, KSpace.md, KSpace.lg, 0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: KTextStyles.bodyMd,
        decoration: InputDecoration(
          hintText: 'Search by service or order id',
          hintStyle: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
          prefixIcon: const Icon(Icons.search_rounded, color: KColors.slate500),
          filled: true,
          fillColor: KColors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: KSpace.md,
            vertical: KSpace.sm,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(KSpace.rLg),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// The horizontal row of status filter chips (All + each [OrderStatus]).
class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onSelected});

  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.lg,
          vertical: KSpace.sm,
        ),
        children: <Widget>[
          _FilterChip(
            label: 'All',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final OrderStatus status in OrderStatus.values)
            Padding(
              padding: const EdgeInsets.only(left: KSpace.sm),
              child: _FilterChip(
                label: _statusLabel(status),
                selected: selected == status,
                onTap: () => onSelected(status),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single selectable filter chip.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: KSpace.lg),
        decoration: BoxDecoration(
          color: selected ? KColors.navy800 : KColors.white,
          borderRadius: BorderRadius.circular(KSpace.rPill),
          border: Border.all(
            color: selected ? KColors.navy800 : KColors.slate200,
          ),
        ),
        child: Text(
          label,
          style: KTextStyles.label.copyWith(
            color: selected ? KColors.white : KColors.slate700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A single admin order row: title, id, status chip, and an update control.
class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({
    required this.order,
    required this.onUpdateStatus,
    required this.onOpen,
  });

  final Order order;
  final VoidCallback onUpdateStatus;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onOpen,
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
            'Placed ${DateFormat.yMMMd().format(order.createdAt.toLocal())}'
            ' · #${_shortId(order.id)}',
            style: KTextStyles.caption,
          ),
          const SizedBox(height: KSpace.md),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onUpdateStatus,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Update status'),
              style: TextButton.styleFrom(
                foregroundColor: KColors.navy800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The bottom sheet for choosing a new status and an optional internal note.
class _StatusUpdateSheet extends StatefulWidget {
  const _StatusUpdateSheet({required this.order, required this.validNext});

  final Order order;
  final List<OrderStatus> validNext;

  @override
  State<_StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends State<_StatusUpdateSheet> {
  OrderStatus? _selected;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: KSpace.lg,
        right: KSpace.lg,
        top: KSpace.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + KSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KColors.slate200,
                borderRadius: BorderRadius.circular(KSpace.rPill),
              ),
            ),
          ),
          const SizedBox(height: KSpace.lg),
          Text('Update status', style: KTextStyles.headingMd),
          const SizedBox(height: KSpace.xs),
          Text(
            'Current: ${_statusLabel(widget.order.status)}',
            style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
          ),
          const SizedBox(height: KSpace.lg),
          if (widget.validNext.isEmpty)
            Text(
              'This order is in a terminal state and cannot be changed.',
              style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
            )
          else
            Wrap(
              spacing: KSpace.sm,
              runSpacing: KSpace.sm,
              children: <Widget>[
                for (final OrderStatus status in widget.validNext)
                  ChoiceChip(
                    label: Text(_statusLabel(status)),
                    selected: _selected == status,
                    onSelected: (_) => setState(() => _selected = status),
                  ),
              ],
            ),
          const SizedBox(height: KSpace.lg),
          TextField(
            controller: _noteController,
            minLines: 1,
            maxLines: 3,
            style: KTextStyles.bodyMd,
            decoration: InputDecoration(
              labelText: 'Internal note (optional)',
              filled: true,
              fillColor: KColors.offWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(KSpace.rLg),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: KSpace.lg),
          KPrimaryButton(
            label: 'Apply update',
            icon: Icons.check_rounded,
            expanded: true,
            onPressed: _selected == null
                ? null
                : () {
                    final String note = _noteController.text.trim();
                    Navigator.of(context).pop(
                      _StatusUpdateRequest(
                        status: _selected!,
                        note: note.isEmpty ? null : note,
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}

/// The result of the status-update sheet: the chosen status and optional note.
class _StatusUpdateRequest {
  const _StatusUpdateRequest({required this.status, this.note});

  final OrderStatus status;
  final String? note;
}

/// Empty state when no orders match the current filter/search.
class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.inbox_rounded,
              size: 56,
              color: KColors.slate500,
            ),
            const SizedBox(height: KSpace.lg),
            Text('No matching orders', style: KTextStyles.headingMd),
            const SizedBox(height: KSpace.sm),
            Text(
              'Try a different status filter or search term.',
              textAlign: TextAlign.center,
              style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton while orders load.
class _OrdersLoading extends StatelessWidget {
  const _OrdersLoading();

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
        for (int i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: KSpace.md),
            child: KShimmer.box(height: 120),
          ),
      ],
    );
  }
}

/// The first 6 characters of an order id, for compact display.
String _shortId(String id) => id.length <= 6 ? id : id.substring(0, 6);

/// Human-readable label for an [OrderStatus].
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
