import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/order.dart';

/// Presentation-layer providers for the client dashboard (Requirement 10).
///
/// The dashboard's order views are driven by two small stream providers that
/// sit on top of the [OrderRepository]:
///
/// * [clientOrdersProvider] — the live list of orders belonging to the
///   currently signed-in client. It resolves the acting client id from
///   [currentUserProvider] and subscribes to
///   [OrderRepository.watchClientOrders], so the orders view always shows only
///   the current user's orders (Requirement 10.3) and updates in real time.
///   When no user is signed in it emits an empty list rather than throwing, so
///   the empty-state CTA (Requirement 10.5) renders cleanly during sign-out.
/// * [orderByIdProvider] — a `family` keyed by order id that streams a single
///   order for the order-detail / tracking screen (Requirement 10.2). Each
///   distinct id gets its own independently-cached subscription.
///
/// Keeping these as standalone providers (rather than folding them into the
/// widgets) lets widget tests override them with synchronous fakes and lets the
/// UI render the standard `AsyncValue` loading / error / data states.

/// Streams the current client's orders in real time (Requirements 10.1, 10.3).
///
/// Resolves the acting client id from [currentUserProvider]. While signed out
/// (or before the auth stream resolves) it yields a single empty list so the
/// orders view can show its empty state without error. Otherwise it delegates
/// to [OrderRepository.watchClientOrders], which already scopes the query to
/// the given `clientId` on the data layer.
final clientOrdersProvider = StreamProvider<List<Order>>((ref) {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream<List<Order>>.value(const <Order>[]);
  }
  return ref.watch(orderRepositoryProvider).watchClientOrders(user.id);
});

/// Streams a single [Order] by its [orderId] in real time (Requirement 10.2).
///
/// Backs the order-detail / tracking screen. Delegates to
/// [OrderRepository.watchOrder]; the `family` argument is the order id.
final orderByIdProvider = StreamProvider.family<Order, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).watchOrder(orderId);
});
