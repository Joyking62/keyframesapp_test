import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/data/models/conversation.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_status_event.dart';
import 'package:keyframes_app/data/models/service_listing.dart';

/// Presentation-layer providers for the admin dashboard (Requirement 11).
///
/// The dashboard's four areas — overview KPIs, orders management, the chats
/// inbox, and listings CRUD — are driven by a small set of stream providers on
/// top of the existing repositories, plus a handful of derived `int` providers
/// that compute the count-up KPI values (Requirement 11.1, 14.2):
///
/// * [allOrdersProvider] — a `family` keyed by an optional [OrderStatus] filter
///   that streams every order for the admin orders-management view
///   (Requirement 11.2). Passing `null` streams all orders; the orders screen
///   uses the `null` family member and applies status/search filtering
///   client-side so a single live subscription backs both the list and the
///   KPIs.
/// * [adminConversationsProvider] — streams every client [Conversation] for the
///   admin inbox, ordered most-recent-first (Requirements 11.4, 12.3).
/// * [adminServicesProvider] — streams the catalog for listings management
///   (Requirement 11.5). NOTE: the underlying [ServiceRepository.watchServices]
///   surfaces **active-only** listings, so admin listing management shows active
///   listings; toggling a listing inactive removes it from this stream. This is
///   an intentional, documented limitation of the current data layer.
/// * [newPreOrdersCountProvider] / [activeChatsCountProvider] /
///   [completedThisMonthCountProvider] — derived KPI counts for the overview.

// ---------------------------------------------------------------------------
// Streams
// ---------------------------------------------------------------------------

/// Streams all orders for the admin orders-management view, optionally filtered
/// by [OrderStatus] (Requirement 11.2).
///
/// A `family` keyed by an optional status filter. Delegates to
/// [OrderRepository.watchAllOrders]; passing `null` streams every order, which
/// the orders screen and the KPI providers reuse to avoid duplicate
/// subscriptions.
final allOrdersProvider =
    StreamProvider.family<List<Order>, OrderStatus?>((ref, filter) {
  return ref.watch(orderRepositoryProvider).watchAllOrders(filter: filter);
});

/// Streams every client [Conversation] for the admin inbox, most-recent-first
/// (Requirements 11.4, 12.3).
///
/// Delegates to [ChatRepository.watchAllConversations] and sorts a defensive
/// copy by [Conversation.updatedAt] descending so the list ordering is
/// deterministic regardless of backend ordering.
final adminConversationsProvider =
    StreamProvider<List<Conversation>>((ref) {
  return ref.watch(chatRepositoryProvider).watchAllConversations().map(
    (List<Conversation> conversations) {
      final List<Conversation> sorted =
          List<Conversation>.of(conversations)
            ..sort((Conversation a, Conversation b) =>
                b.updatedAt.compareTo(a.updatedAt));
      return sorted;
    },
  );
});

/// Streams the catalog for admin listings management (Requirement 11.5).
///
/// See the file-level note: [ServiceRepository.watchServices] returns
/// active-only listings, so this stream reflects active listings; toggling a
/// listing inactive removes it from the stream.
final adminServicesProvider =
    StreamProvider<List<ServiceListing>>((ref) {
  return ref.watch(serviceRepositoryProvider).watchServices();
});

// ---------------------------------------------------------------------------
// Derived KPI counts (Requirement 11.1, 14.2)
// ---------------------------------------------------------------------------

/// The number of new pre-orders — orders currently in [OrderStatus.pending]
/// (Requirement 11.1). Derived from the unfiltered [allOrdersProvider]; yields
/// `0` while the stream is still loading or has errored.
final newPreOrdersCountProvider = Provider<int>((ref) {
  final List<Order> orders =
      ref.watch(allOrdersProvider(null)).valueOrNull ?? const <Order>[];
  return orders
      .where((Order o) => o.status == OrderStatus.pending)
      .length;
});

/// The number of active chats — client conversations the admin currently has
/// (Requirement 11.1). Derived from [adminConversationsProvider]; yields `0`
/// while loading or on error.
final activeChatsCountProvider = Provider<int>((ref) {
  final List<Conversation> conversations =
      ref.watch(adminConversationsProvider).valueOrNull ??
          const <Conversation>[];
  return conversations.length;
});

/// The number of orders completed during the current calendar month
/// (Requirement 11.1).
///
/// An order counts when its current status is [OrderStatus.completed] and the
/// timestamp of its most recent `completed` timeline event falls within the
/// current year+month. Derived from the unfiltered [allOrdersProvider]; yields
/// `0` while loading or on error.
final completedThisMonthCountProvider = Provider<int>((ref) {
  final List<Order> orders =
      ref.watch(allOrdersProvider(null)).valueOrNull ?? const <Order>[];
  final DateTime now = DateTime.now();
  return orders.where((Order o) {
    if (o.status != OrderStatus.completed) {
      return false;
    }
    final DateTime? completedAt = _completedAt(o);
    return completedAt != null &&
        completedAt.year == now.year &&
        completedAt.month == now.month;
  }).length;
});

/// Returns the timestamp of the most recent [OrderStatus.completed] event in
/// [order]'s timeline, or `null` when the order has never been completed.
DateTime? _completedAt(Order order) {
  DateTime? latest;
  for (final OrderStatusEvent event in order.timeline) {
    if (event.status == OrderStatus.completed) {
      if (latest == null || event.at.isAfter(latest)) {
        latest = event.at;
      }
    }
  }
  return latest;
}
