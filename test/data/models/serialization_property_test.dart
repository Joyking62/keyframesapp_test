// Property-based tests for JSON serialization round-tripping of the Keyframes
// data models.
//
// Property: Serialization round-trip equivalence
//   For every JSON-serializable model `x`, decoding the JSON it encodes
//   reproduces an equal value: `fromJson(toJson(x)) == x`.
//
// This complements the example-based model tests by checking the invariant
// across a large space of randomly generated instances (via `glados`),
// including optional/nullable fields, default-valued collections, enum
// variants, and nested objects (an `Order`'s `OrderStatusEvent` timeline).
//
// Validates: Requirements 16.3
//
// Notes on DateTime handling:
//   The models serialize `DateTime` via `toIso8601String()` and read it back
//   with `DateTime.parse(...)`. To keep `fromJson(toJson(x)) == x` exact, the
//   generated `DateTime`s are UTC and at millisecond precision within a bounded
//   window around the epoch, which ISO-8601 represents and re-parses losslessly
//   (both the microseconds-since-epoch value and the `isUtc` flag are
//   preserved, which is what freezed equality compares).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart';

import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/conversation.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/message.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_status_event.dart';
import 'package:keyframes_app/data/models/service_listing.dart';

// ---------------------------------------------------------------------------
// Record combinators.
//
// `glados` exposes `any.combine2` for building a generator of a pair from two
// generators. The models here have up to 12 fields, so we lift `combine2` into
// fixed-arity record generators `_r2`..`_r12`. Each `_rN` combines the
// `(N-1)`-field record from `_r{N-1}` with one more field, so the whole tower
// rests only on `combine2` + `.map`, which keeps every model generator a flat,
// readable mapping from a positional record onto its constructor.
// ---------------------------------------------------------------------------

Generator<(A, B)> _r2<A, B>(Generator<A> a, Generator<B> b) =>
    any.combine2(a, b, (A x, B y) => (x, y));

Generator<(A, B, C)> _r3<A, B, C>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
) =>
    any.combine2(_r2(a, b), c, ((A, B) p, C z) => (p.$1, p.$2, z));

Generator<(A, B, C, D)> _r4<A, B, C, D>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
) =>
    any.combine2(
      _r3(a, b, c),
      d,
      ((A, B, C) p, D z) => (p.$1, p.$2, p.$3, z),
    );

Generator<(A, B, C, D, E)> _r5<A, B, C, D, E>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
  Generator<E> e,
) =>
    any.combine2(
      _r4(a, b, c, d),
      e,
      ((A, B, C, D) p, E z) => (p.$1, p.$2, p.$3, p.$4, z),
    );

Generator<(A, B, C, D, E, F)> _r6<A, B, C, D, E, F>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
  Generator<E> e,
  Generator<F> f,
) =>
    any.combine2(
      _r5(a, b, c, d, e),
      f,
      ((A, B, C, D, E) p, F z) => (p.$1, p.$2, p.$3, p.$4, p.$5, z),
    );

Generator<(A, B, C, D, E, F, G)> _r7<A, B, C, D, E, F, G>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
  Generator<E> e,
  Generator<F> f,
  Generator<G> g,
) =>
    any.combine2(
      _r6(a, b, c, d, e, f),
      g,
      ((A, B, C, D, E, F) p, G z) => (p.$1, p.$2, p.$3, p.$4, p.$5, p.$6, z),
    );

Generator<(A, B, C, D, E, F, G, H)> _r8<A, B, C, D, E, F, G, H>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
  Generator<E> e,
  Generator<F> f,
  Generator<G> g,
  Generator<H> h,
) =>
    any.combine2(
      _r7(a, b, c, d, e, f, g),
      h,
      ((A, B, C, D, E, F, G) p, H z) =>
          (p.$1, p.$2, p.$3, p.$4, p.$5, p.$6, p.$7, z),
    );

Generator<(A, B, C, D, E, F, G, H, I)> _r9<A, B, C, D, E, F, G, H, I>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
  Generator<E> e,
  Generator<F> f,
  Generator<G> g,
  Generator<H> h,
  Generator<I> i,
) =>
    any.combine2(
      _r8(a, b, c, d, e, f, g, h),
      i,
      ((A, B, C, D, E, F, G, H) p, I z) =>
          (p.$1, p.$2, p.$3, p.$4, p.$5, p.$6, p.$7, p.$8, z),
    );

Generator<(A, B, C, D, E, F, G, H, I, J)> _r10<A, B, C, D, E, F, G, H, I, J>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
  Generator<E> e,
  Generator<F> f,
  Generator<G> g,
  Generator<H> h,
  Generator<I> i,
  Generator<J> j,
) =>
    any.combine2(
      _r9(a, b, c, d, e, f, g, h, i),
      j,
      ((A, B, C, D, E, F, G, H, I) p, J z) =>
          (p.$1, p.$2, p.$3, p.$4, p.$5, p.$6, p.$7, p.$8, p.$9, z),
    );

Generator<(A, B, C, D, E, F, G, H, I, J, K)>
    _r11<A, B, C, D, E, F, G, H, I, J, K>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
  Generator<E> e,
  Generator<F> f,
  Generator<G> g,
  Generator<H> h,
  Generator<I> i,
  Generator<J> j,
  Generator<K> k,
) =>
        any.combine2(
          _r10(a, b, c, d, e, f, g, h, i, j),
          k,
          ((A, B, C, D, E, F, G, H, I, J) p, K z) =>
              (p.$1, p.$2, p.$3, p.$4, p.$5, p.$6, p.$7, p.$8, p.$9, p.$10, z),
        );

Generator<(A, B, C, D, E, F, G, H, I, J, K, L)>
    _r12<A, B, C, D, E, F, G, H, I, J, K, L>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
  Generator<E> e,
  Generator<F> f,
  Generator<G> g,
  Generator<H> h,
  Generator<I> i,
  Generator<J> j,
  Generator<K> k,
  Generator<L> l,
) =>
        any.combine2(
          _r11(a, b, c, d, e, f, g, h, i, j, k),
          l,
          ((A, B, C, D, E, F, G, H, I, J, K) p, L z) => (
            p.$1,
            p.$2,
            p.$3,
            p.$4,
            p.$5,
            p.$6,
            p.$7,
            p.$8,
            p.$9,
            p.$10,
            p.$11,
            z,
          ),
        );

// ---------------------------------------------------------------------------
// Field generators.
//
// String / numeric / DateTime fields are derived deterministically from
// `any.int` (and `any.bool`) so we depend only on glados' core primitives while
// still exploring a wide value space. Dart's `%` with a positive divisor always
// yields a non-negative result, so enum indices and bounded counts are safe
// even for negative seeds.
// ---------------------------------------------------------------------------

/// ~60 years expressed in milliseconds; bounds the generated DateTime window.
const int _dateSpanMs = 1000 * 60 * 60 * 24 * 365 * 60;

final Generator<String> _id = any.int.map((int i) => 'id_$i');
final Generator<String> _str = any.int.map((int i) => 'str_$i');
final Generator<String?> _maybeStr =
    any.int.map((int i) => i % 3 == 0 ? null : 'opt_$i');
final Generator<bool> _flag = any.bool;
final Generator<int> _count = any.int.map((int i) => i % 1000);
final Generator<double> _price =
    any.int.map((int i) => (i % 1000000) / 100.0);
final Generator<double?> _maybePrice =
    any.int.map((int i) => i % 3 == 0 ? null : (i % 1000000) / 100.0);
final Generator<List<String>> _strList = any.list(_str);

final Generator<DateTime> _dateTime = any.int.map(
  (int i) =>
      DateTime.fromMillisecondsSinceEpoch(i % _dateSpanMs, isUtc: true),
);
final Generator<DateTime?> _maybeDateTime = any.int.map(
  (int i) => i % 3 == 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(i % _dateSpanMs, isUtc: true),
);

final Generator<UserRole> _userRole =
    any.int.map((int i) => UserRole.values[i % UserRole.values.length]);
final Generator<ServiceCategory> _serviceCategory = any.int
    .map((int i) => ServiceCategory.values[i % ServiceCategory.values.length]);
final Generator<OrderStatus> _orderStatus =
    any.int.map((int i) => OrderStatus.values[i % OrderStatus.values.length]);
final Generator<PackageTier> _packageTier =
    any.int.map((int i) => PackageTier.values[i % PackageTier.values.length]);
final Generator<MessageType> _messageType =
    any.int.map((int i) => MessageType.values[i % MessageType.values.length]);

// ---------------------------------------------------------------------------
// Model generators.
// ---------------------------------------------------------------------------

final Generator<OrderStatusEvent> _anyOrderStatusEvent =
    _r3(_orderStatus, _maybeStr, _dateTime).map(
  (t) => OrderStatusEvent(status: t.$1, note: t.$2, at: t.$3),
);

final Generator<AppUser> _anyAppUser = _r7(
  _id,
  _str,
  _str,
  _maybeStr,
  _maybeStr,
  _userRole,
  _dateTime,
).map(
  (t) => AppUser(
    id: t.$1,
    name: t.$2,
    email: t.$3,
    phone: t.$4,
    photoUrl: t.$5,
    role: t.$6,
    createdAt: t.$7,
  ),
);

final Generator<ServiceListing> _anyServiceListing = _r11(
  _id,
  _str,
  _str,
  _str,
  _serviceCategory,
  _price,
  _strList,
  _strList,
  _maybeStr,
  _flag,
  _count,
).map(
  (t) => ServiceListing(
    id: t.$1,
    title: t.$2,
    tagline: t.$3,
    description: t.$4,
    category: t.$5,
    basePrice: t.$6,
    deliverables: t.$7,
    gallery: t.$8,
    thumbnailUrl: t.$9,
    active: t.$10,
    estimatedDays: t.$11,
  ),
);

final Generator<Order> _anyOrder = _r12(
  _id,
  _id,
  _id,
  _str,
  _packageTier,
  _str,
  _strList,
  _maybePrice,
  _maybeDateTime,
  _orderStatus,
  any.list(_anyOrderStatusEvent),
  _dateTime,
).map(
  (t) => Order(
    id: t.$1,
    clientId: t.$2,
    serviceId: t.$3,
    serviceTitle: t.$4,
    packageTier: t.$5,
    requirements: t.$6,
    attachments: t.$7,
    budget: t.$8,
    deadline: t.$9,
    status: t.$10,
    timeline: t.$11,
    createdAt: t.$12,
  ),
);

final Generator<Conversation> _anyConversation = _r7(
  _id,
  _id,
  _str,
  _maybeStr,
  _count,
  _count,
  _dateTime,
).map(
  (t) => Conversation(
    id: t.$1,
    clientId: t.$2,
    clientName: t.$3,
    lastMessage: t.$4,
    unreadClient: t.$5,
    unreadAdmin: t.$6,
    updatedAt: t.$7,
  ),
);

final Generator<Message> _anyMessage = _r8(
  _id,
  _id,
  _id,
  _messageType,
  _maybeStr,
  _maybeStr,
  _dateTime,
  _flag,
).map(
  (t) => Message(
    id: t.$1,
    conversationId: t.$2,
    senderId: t.$3,
    type: t.$4,
    text: t.$5,
    mediaUrl: t.$6,
    sentAt: t.$7,
    read: t.$8,
  ),
);

/// Encodes [map] to a JSON string and decodes it back, mirroring how the models
/// travel to/from Firestore/JSON so the round-trip exercises real text
/// (de)serialization rather than just the in-memory `Map`.
Map<String, dynamic> _throughJson(Map<String, dynamic> map) =>
    jsonDecode(jsonEncode(map)) as Map<String, dynamic>;

void main() {
  group('Model serialization round-trip equivalence (Requirement 16.3)', () {
    Glados<AppUser>(_anyAppUser).test(
      'AppUser: fromJson(toJson(x)) == x',
      (AppUser x) {
        expect(AppUser.fromJson(_throughJson(x.toJson())), equals(x));
      },
    );

    Glados<ServiceListing>(_anyServiceListing).test(
      'ServiceListing: fromJson(toJson(x)) == x',
      (ServiceListing x) {
        expect(ServiceListing.fromJson(_throughJson(x.toJson())), equals(x));
      },
    );

    Glados<OrderStatusEvent>(_anyOrderStatusEvent).test(
      'OrderStatusEvent: fromJson(toJson(x)) == x',
      (OrderStatusEvent x) {
        expect(OrderStatusEvent.fromJson(_throughJson(x.toJson())), equals(x));
      },
    );

    Glados<Order>(_anyOrder).test(
      'Order (with OrderStatusEvent timeline): fromJson(toJson(x)) == x',
      (Order x) {
        expect(Order.fromJson(_throughJson(x.toJson())), equals(x));
      },
    );

    Glados<Conversation>(_anyConversation).test(
      'Conversation: fromJson(toJson(x)) == x',
      (Conversation x) {
        expect(Conversation.fromJson(_throughJson(x.toJson())), equals(x));
      },
    );

    Glados<Message>(_anyMessage).test(
      'Message: fromJson(toJson(x)) == x',
      (Message x) {
        expect(Message.fromJson(_throughJson(x.toJson())), equals(x));
      },
    );
  });
}
