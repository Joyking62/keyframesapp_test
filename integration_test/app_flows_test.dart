// Integration tests for the two end-to-end happy paths from the design
// (Task 24.2):
//
//   1. The full **pre-order happy path** — drive the real [PreOrderController]
//      for a sample [ServiceListing] (set requirements, package tier, and a
//      future deadline), submit, and assert a `pending` [Order] with a single
//      `pending` timeline event was created and stored by the repository. The
//      real [OrderSuccessScreen] is then pumped with that order to assert the
//      "Pre-order placed!" confirmation is shown.
//   2. The **client <-> admin chat round-trip** — a single, shared in-memory
//      [FakeChatRepository] backs BOTH the client and the admin views. Two
//      independent [ProviderContainer]s (one whose `currentUserProvider` is the
//      client, one whose `currentUserProvider` is the admin) talk to the SAME
//      repository instance, exactly as the real app would have two devices talk
//      to the same Firestore conversation. The client sends "Hello", the admin
//      replies "Hi there", and we assert both messages appear in the shared
//      `streamMessages` stream, that their `senderId`s distinguish client from
//      admin, and that they are ordered by `sentAt`.
//
// ## Why fakes instead of the Firebase emulator
//
// The design calls for these flows to run against the Firebase emulator. That
// emulator is NOT available in this sandbox and outbound network access is
// restricted, so instead of `firebase_*` we inject hand-written, in-memory
// FAKE repositories through Riverpod `ProviderScope` / `ProviderContainer`
// overrides. The production providers
// (`orderRepositoryProvider`, `chatRepositoryProvider`, `currentUserProvider`,
// `isOnlineProvider`) are the seams the app already exposes for exactly this
// purpose (see `lib/app/providers.dart`).
//
// When the Firebase emulator + Flutter toolchain are available, the
// EMULATOR VARIANT of these tests would keep the flows below verbatim and only
// swap the fakes for the real Firebase-backed repositories pointed at the
// emulator, e.g.:
//
//   FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
//   await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
//   // ...then drop the `*RepositoryProvider.overrideWithValue(fake)` overrides
//   // and let the default Firebase-backed providers run against the emulator.
//
// `isOnlineProvider` is overridden with `Stream.value(true)` throughout so the
// real connectivity probe (a periodic `dart:io` DNS lookup timer) never starts
// during the tests.
//
// These are written with `package:integration_test` and run as multi-step
// widget/controller flows; they are equally runnable under the standard test
// runner via `flutter test integration_test/app_flows_test.dart`.
//
// Validates: Requirements 8.6, 9.2, 9.6, 10A.5

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/core/utils/connectivity.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/conversation.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/message.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_draft.dart';
import 'package:keyframes_app/data/models/send_message_input.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/data/repositories/chat_repository.dart';
import 'package:keyframes_app/data/repositories/order_repository.dart';
import 'package:keyframes_app/features/chat/chat_controller.dart';
import 'package:keyframes_app/features/order/default_order_service.dart';
import 'package:keyframes_app/features/preorder/order_success_screen.dart';
import 'package:keyframes_app/features/preorder/preorder_controller.dart';

// ===========================================================================
// In-memory fakes (replace these with Firebase-emulator-backed repositories
// when the toolchain is available — see the file header).
// ===========================================================================

/// An in-memory [OrderRepository] standing in for `FirebaseOrderRepository`.
///
/// [createOrder] builds the initial [Order] exactly as the real repository does
/// — delegating to the production [DefaultOrderService] so the created order is
/// `pending` with a single `pending` timeline event (Requirement 8.6) — stores
/// it in [created], and returns it. The streaming/admin methods back the
/// (unused-by-this-flow) read paths from an in-memory list so nothing throws if
/// a future flow exercises them.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({
    required this.clientId,
    DefaultOrderService? service,
  }) : _service = service ?? const DefaultOrderService();

  /// The acting client id stamped onto every created order (the real
  /// repository resolves this from the signed-in Firebase user).
  final String clientId;

  final DefaultOrderService _service;

  /// Every order created through this fake, in creation order.
  final List<Order> created = <Order>[];

  int _seq = 0;

  @override
  Future<Order> createOrder(OrderDraft draft) async {
    _seq++;
    final Order order = _service.buildInitialOrder(
      id: 'order-$_seq',
      clientId: clientId,
      draft: draft,
    );
    created.add(order);
    return order;
  }

  @override
  Stream<List<Order>> watchClientOrders(String clientId) => Stream<List<Order>>.value(
        created.where((Order o) => o.clientId == clientId).toList(),
      );

  @override
  Stream<List<Order>> watchAllOrders({OrderStatus? filter}) => Stream<List<Order>>.value(
        filter == null
            ? List<Order>.unmodifiable(created)
            : created.where((Order o) => o.status == filter).toList(),
      );

  @override
  Future<void> updateStatus(String orderId, OrderStatus status, {String? note}) async {
    final int index = created.indexWhere((Order o) => o.id == orderId);
    if (index == -1) {
      return;
    }
    created[index] = _service.appendStatusEvent(created[index], status, note: note);
  }

  @override
  Stream<Order> watchOrder(String orderId) =>
      Stream<Order>.value(created.firstWhere((Order o) => o.id == orderId));
}

/// A single, shared in-memory [ChatRepository] standing in for
/// `FirebaseChatRepository`.
///
/// One instance backs BOTH the client and the admin containers in the chat
/// round-trip, mirroring two clients talking to the same Firestore document.
/// It maintains one [Conversation] plus a broadcast [StreamController] of the
/// message list, appends accepted messages with strictly-increasing [sentAt]
/// timestamps (so ordering is deterministic), and performs the same unread
/// accounting as the real repository: a send increments the *recipient's*
/// counter and [markRead] zeroes the *reader's* counter (Requirement 9.6).
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({required this.clientId, required String clientName})
      : _conversation = Conversation(
          id: clientId,
          clientId: clientId,
          clientName: clientName,
          updatedAt: _epoch,
        );

  /// The owning client's id; also the single conversation's id (one
  /// conversation per client).
  final String clientId;

  static final DateTime _epoch = DateTime.utc(2024, 1, 1, 12);

  final StreamController<List<Message>> _messagesController =
      StreamController<List<Message>>.broadcast();
  final StreamController<Conversation> _conversationController =
      StreamController<Conversation>.broadcast();

  final List<Message> messages = <Message>[];
  Conversation _conversation;

  /// Every [SendMessageInput] accepted, newest last (for assertions).
  final List<SendMessageInput> sent = <SendMessageInput>[];

  Future<void> dispose() async {
    await _messagesController.close();
    await _conversationController.close();
  }

  @override
  Stream<Conversation> ensureConversation(String clientId) async* {
    yield _conversation;
    yield* _conversationController.stream;
  }

  @override
  Stream<List<Message>> streamMessages(String conversationId) async* {
    // Replay the current backlog to each new subscriber (the real Firestore
    // snapshot stream is also seeded with the existing documents), then follow
    // live updates.
    yield List<Message>.unmodifiable(messages);
    yield* _messagesController.stream;
  }

  @override
  Future<void> sendMessage(SendMessageInput input) async {
    sent.add(input);
    final Message message = Message(
      id: 'm${messages.length + 1}',
      conversationId: input.conversationId,
      senderId: input.senderId,
      type: input.type,
      text: input.text,
      mediaUrl: input.mediaUrl,
      // Strictly increasing so ordering-by-sentAt is unambiguous.
      sentAt: _epoch.add(Duration(seconds: messages.length + 1)),
    );
    messages.add(message);

    // Unread accounting: the sender is the client iff their id matches the
    // conversation's clientId; the *recipient's* counter is bumped.
    final bool senderIsClient = input.senderId == clientId;
    _conversation = _conversation.copyWith(
      lastMessage: input.text ?? input.mediaUrl,
      updatedAt: message.sentAt,
      unreadAdmin: senderIsClient
          ? _conversation.unreadAdmin + 1
          : _conversation.unreadAdmin,
      unreadClient: senderIsClient
          ? _conversation.unreadClient
          : _conversation.unreadClient + 1,
    );

    _messagesController.add(List<Message>.unmodifiable(messages));
    _conversationController.add(_conversation);
  }

  @override
  Stream<List<Conversation>> watchAllConversations() async* {
    yield <Conversation>[_conversation];
    yield* _conversationController.stream.map((Conversation c) => <Conversation>[c]);
  }

  @override
  Future<void> markRead(String conversationId, String readerId) async {
    final bool readerIsClient = readerId == clientId;
    _conversation = _conversation.copyWith(
      unreadClient: readerIsClient ? 0 : _conversation.unreadClient,
      unreadAdmin: readerIsClient ? _conversation.unreadAdmin : 0,
    );
    _conversationController.add(_conversation);
  }

  @override
  Future<String> uploadAttachment({
    required String conversationId,
    required String fileName,
    required Uint8List data,
    required String contentType,
  }) async =>
      'https://example.com/$conversationId/$fileName';
}

// ===========================================================================
// Shared fixtures
// ===========================================================================

/// A sample listing the pre-order flow is scoped to. No remote imagery is
/// referenced so nothing touches the network.
const ServiceListing _listing = ServiceListing(
  id: 'svc-1',
  title: 'Logo Creation',
  tagline: 'A mark that sticks',
  description: 'Three concepts, unlimited revisions, vector delivery.',
  category: ServiceCategory.graphicDesign,
  basePrice: 199,
);

/// The signed-in client. Its id doubles as the chat conversation id.
final AppUser _client = AppUser(
  id: 'client-1',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  createdAt: DateTime.utc(2024, 1, 1),
);

/// The signed-in admin replying from the company side.
final AppUser _admin = AppUser(
  id: 'admin-1',
  name: 'Keyframes Team',
  email: 'team@keyframes.app',
  role: UserRole.admin,
  createdAt: DateTime.utc(2024, 1, 1),
);

/// Lets queued microtasks/stream events drain between steps.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // Flow 1 — Pre-order happy path (Requirements 8.6, 10A.5)
  // -------------------------------------------------------------------------
  group('Integration: pre-order happy path', () {
    test(
        'submitting a valid pre-order creates a pending order with a single '
        'pending timeline event and stores it in the repository', () async {
      final FakeOrderRepository orders =
          FakeOrderRepository(clientId: _client.id);

      // Real DefaultOrderService (default provider) + fake OrderRepository.
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          orderRepositoryProvider.overrideWithValue(orders),
          currentUserProvider.overrideWithValue(_client),
          isOnlineProvider.overrideWith((ref) => Stream<bool>.value(true)),
        ],
      );
      addTearDown(container.dispose);

      // Keep the autoDispose family controller alive across reads.
      final ProviderSubscription<PreOrderState> sub =
          container.listen<PreOrderState>(
        preOrderControllerProvider(_listing),
        (_, __) {},
      );
      addTearDown(sub.close);

      final PreOrderController controller =
          container.read(preOrderControllerProvider(_listing).notifier);

      // Step 1: requirements (must be >= 10 chars).
      controller.setRequirements(
        'A detailed 60-second animated promo video for my brand launch.',
      );
      expect(controller.tryAdvance(), isTrue);

      // Step 2: package tier + a future deadline.
      controller.setPackage(PackageTier.standard);
      controller.setDeadline(DateTime.now().add(const Duration(days: 14)));
      expect(controller.tryAdvance(), isTrue);

      // Step 3: submit.
      final Order? order = await controller.submit();

      // An order was created and returned.
      expect(order, isNotNull);
      // Created as pending with exactly one pending timeline event (R8.6).
      expect(order!.status, OrderStatus.pending);
      expect(order.timeline, hasLength(1));
      expect(order.timeline.single.status, OrderStatus.pending);
      expect(order.clientId, _client.id);
      expect(order.serviceId, _listing.id);

      // The fake repository actually stored it (createOrder was reached).
      expect(orders.created, hasLength(1));
      expect(orders.created.single, same(order));

      // The controller settled to a success state carrying the order (R8.8),
      // which is what the screen reads to route to OrderSuccessScreen.
      final PreOrderState state =
          container.read(preOrderControllerProvider(_listing));
      expect(state.submission, isA<AsyncData<Order?>>());
      expect(state.submission.value, same(order));
      expect(state.submission.hasError, isFalse);
    });

    testWidgets(
        'OrderSuccessScreen shows the "Pre-order placed!" confirmation for the '
        'created order', (WidgetTester tester) async {
      // Build a representative created order via the real order service.
      final Order order = const DefaultOrderService().buildInitialOrder(
        id: 'order-1',
        clientId: _client.id,
        draft: const OrderDraft(
          serviceId: 'svc-1',
          serviceTitle: 'Logo Creation',
          packageTier: PackageTier.standard,
          requirements: 'A detailed 60-second animated promo video.',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => MediaQuery(
                // Render the final, static celebration state (no timers).
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: OrderSuccessScreen(order: order),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pre-order placed!'), findsOneWidget);
      // The created service title is echoed back to the client.
      expect(find.textContaining(order.serviceTitle), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  // Flow 2 — Client <-> admin chat round-trip (Requirements 9.2, 9.6)
  // -------------------------------------------------------------------------
  group('Integration: client <-> admin chat round-trip', () {
    test(
        'client send + admin reply both appear in the shared stream, with '
        'sender ids distinguishing the sides and ordered by sentAt', () async {
      // ONE shared repository instance, as if both sides hit the same Firestore
      // conversation document.
      final FakeChatRepository chat = FakeChatRepository(
        clientId: _client.id,
        clientName: _client.name,
      );
      addTearDown(chat.dispose);

      final String conversationId = _client.id;

      // Two containers sharing the SAME repository: one acting as the client,
      // one as the admin (distinguished only by currentUserProvider).
      final ProviderContainer clientSide = ProviderContainer(
        overrides: <Override>[
          chatRepositoryProvider.overrideWithValue(chat),
          currentUserProvider.overrideWithValue(_client),
          isOnlineProvider.overrideWith((ref) => Stream<bool>.value(true)),
        ],
      );
      addTearDown(clientSide.dispose);

      final ProviderContainer adminSide = ProviderContainer(
        overrides: <Override>[
          chatRepositoryProvider.overrideWithValue(chat),
          currentUserProvider.overrideWithValue(_admin),
          isOnlineProvider.overrideWith((ref) => Stream<bool>.value(true)),
        ],
      );
      addTearDown(adminSide.dispose);

      // Subscribe to the streamed message list on the CLIENT side so it stays
      // live and accumulates emissions (Requirement 9.2: real-time updates).
      final ProviderSubscription<AsyncValue<List<Message>>> clientMessagesSub =
          clientSide.listen<AsyncValue<List<Message>>>(
        messagesProvider(conversationId),
        (_, __) {},
      );
      addTearDown(clientMessagesSub.close);
      // Same on the admin side so the admin view also sees both messages.
      final ProviderSubscription<AsyncValue<List<Message>>> adminMessagesSub =
          adminSide.listen<AsyncValue<List<Message>>>(
        messagesProvider(conversationId),
        (_, __) {},
      );
      addTearDown(adminMessagesSub.close);
      await _settle();

      // 1) Client sends "Hello".
      final ChatController clientController =
          clientSide.read(chatControllerProvider(conversationId).notifier);
      await clientController.send('Hello');
      await _settle();

      // 2) Admin replies "Hi there".
      final ChatController adminController =
          adminSide.read(chatControllerProvider(conversationId).notifier);
      await adminController.send('Hi there');
      await _settle();

      // Both messages are present in the shared stream, observed from the
      // client side.
      final AsyncValue<List<Message>> clientView =
          clientSide.read(messagesProvider(conversationId));
      final List<Message> clientMessages = clientView.value ?? <Message>[];
      expect(clientMessages, hasLength(2));

      // ...and from the admin side (same shared conversation).
      final List<Message> adminMessages =
          adminSide.read(messagesProvider(conversationId)).value ?? <Message>[];
      expect(adminMessages, hasLength(2));

      // Sender ids distinguish client from admin.
      expect(clientMessages[0].senderId, _client.id);
      expect(clientMessages[0].text, 'Hello');
      expect(clientMessages[1].senderId, _admin.id);
      expect(clientMessages[1].text, 'Hi there');
      expect(clientMessages[0].senderId, isNot(clientMessages[1].senderId));

      // Ordered by sentAt (non-decreasing, strictly increasing here).
      expect(
        clientMessages[0].sentAt.isBefore(clientMessages[1].sentAt),
        isTrue,
      );

      // Unread accounting (Requirement 9.6): the client's "Hello" bumped the
      // admin's unread; the admin's reply bumped the client's unread. After the
      // admin reads the thread, the admin's unread resets to zero.
      await adminController.markRead();
      await _settle();
      final Conversation convo =
          await chat.watchAllConversations().first.then((List<Conversation> c) => c.single);
      expect(convo.unreadAdmin, 0);
      expect(convo.unreadClient, greaterThan(0));

      // Both sends were recorded by the single shared repository.
      expect(chat.sent, hasLength(2));
      expect(chat.sent[0].senderId, _client.id);
      expect(chat.sent[1].senderId, _admin.id);
    });
  });
}
