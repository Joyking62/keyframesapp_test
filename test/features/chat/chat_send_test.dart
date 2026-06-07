// Tests for the client <-> company chat send flow.
//
// The live send path is `ChatController.send`, which validates a
// [SendMessageInput] for well-formedness (rejecting empty/whitespace-only text,
// Requirement 9.4) before delegating to [ChatRepository.sendMessage]; a
// successful send is what causes a new bubble to be appended to the streamed
// message list and animated in (Requirement 9.7).
//
// To keep these tests robust and Firebase-free, the chat repository is replaced
// with an in-memory [_FakeChatRepository] that records the last
// [SendMessageInput] and appends accepted messages to a [StreamController] the
// screen subscribes to. The current user is pinned to a sample client via
// [currentUserProvider]. The first two tests drive the controller directly
// through a [ProviderContainer]; the third is a light widget test that pumps
// the real [ChatScreen], types text, taps send, and asserts the fake received
// the message (i.e. a bubble would be appended).
//
// Validates: Requirements 9.4, 9.7

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/core/utils/connectivity.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/conversation.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/message.dart';
import 'package:keyframes_app/data/models/send_message_input.dart';
import 'package:keyframes_app/data/repositories/chat_repository.dart';
import 'package:keyframes_app/features/chat/chat_controller.dart';
import 'package:keyframes_app/features/chat/chat_screen.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// A signed-in client. Its id is both the [currentUserProvider] sender id and,
/// by the app's one-conversation-per-client rule, the conversation id.
final AppUser _client = AppUser(
  id: 'client-1',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  createdAt: DateTime(2024, 1, 1),
);

/// The single conversation the fake repository serves for [_client].
final Conversation _conversation = Conversation(
  id: _client.id,
  clientId: _client.id,
  clientName: _client.name,
  updatedAt: DateTime(2024, 1, 1),
);

/// An in-memory [ChatRepository] that records sends and re-emits the
/// conversation's messages through a broadcast stream.
///
/// `sendMessage` performs no validation of its own (validation is the
/// controller's job, under test here): it records [lastInput], appends a
/// derived [Message] to [sentMessages], and pushes the updated list onto the
/// message stream so a subscribing screen would render a new bubble.
class _FakeChatRepository implements ChatRepository {
  final StreamController<List<Message>> _messages =
      StreamController<List<Message>>.broadcast();
  final List<Message> sentMessages = <Message>[];

  /// The most recent input handed to [sendMessage], or `null` if never called.
  SendMessageInput? lastInput;

  /// How many times [sendMessage] has been invoked.
  int sendCount = 0;

  void emitInitial() => _messages.add(List<Message>.unmodifiable(sentMessages));

  Future<void> dispose() => _messages.close();

  @override
  Stream<Conversation> ensureConversation(String clientId) =>
      Stream<Conversation>.value(_conversation);

  @override
  Stream<List<Message>> streamMessages(String conversationId) =>
      _messages.stream;

  @override
  Future<void> sendMessage(SendMessageInput input) async {
    sendCount++;
    lastInput = input;
    final Message message = Message(
      id: 'm${sentMessages.length + 1}',
      conversationId: input.conversationId,
      senderId: input.senderId,
      type: input.type,
      text: input.text,
      mediaUrl: input.mediaUrl,
      sentAt: DateTime(2024, 1, 1, 12, sentMessages.length),
    );
    sentMessages.add(message);
    _messages.add(List<Message>.unmodifiable(sentMessages));
  }

  @override
  Stream<List<Conversation>> watchAllConversations() =>
      Stream<List<Conversation>>.value(<Conversation>[_conversation]);

  @override
  Future<void> markRead(String conversationId, String readerId) async {}

  @override
  Future<String> uploadAttachment({
    required String conversationId,
    required String fileName,
    required Uint8List data,
    required String contentType,
  }) async =>
      'https://example.com/$fileName';
}

/// Builds a [ProviderContainer] wired to [fake] and the signed-in [_client].
ProviderContainer _container(_FakeChatRepository fake) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      chatRepositoryProvider.overrideWithValue(fake),
      currentUserProvider.overrideWithValue(_client),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ChatController.send', () {
    test(
        'rejects empty/whitespace-only text without calling sendMessage '
        '(Requirement 9.4)', () async {
      final _FakeChatRepository fake = _FakeChatRepository();
      addTearDown(fake.dispose);
      final ProviderContainer container = _container(fake);

      final ChatController controller =
          container.read(chatControllerProvider(_conversation.id).notifier);

      await controller.send('   ');

      // The malformed send is rejected up front: the repository is never hit
      // and a user-facing error is surfaced on the state.
      expect(fake.sendCount, 0);
      expect(fake.lastInput, isNull);
      final ChatState state =
          container.read(chatControllerProvider(_conversation.id));
      expect(state.sendError, isNotNull);
      expect(state.sending, isFalse);
    });

    test(
        'sends a well-formed text message to the repository '
        '(Requirement 9.7)', () async {
      final _FakeChatRepository fake = _FakeChatRepository();
      addTearDown(fake.dispose);
      final ProviderContainer container = _container(fake);

      final ChatController controller =
          container.read(chatControllerProvider(_conversation.id).notifier);

      await controller.send('Hello team');

      // The repository recorded exactly one text message authored by the
      // signed-in client; this is what appends a bubble when the stream emits.
      expect(fake.sendCount, 1);
      final SendMessageInput input = fake.lastInput!;
      expect(input.type, MessageType.text);
      expect(input.text, 'Hello team');
      expect(input.senderId, _client.id);
      expect(input.conversationId, _conversation.id);
      expect(fake.sentMessages.single.text, 'Hello team');

      final ChatState state =
          container.read(chatControllerProvider(_conversation.id));
      expect(state.sendError, isNull);
      expect(state.sending, isFalse);
    });
  });

  testWidgets(
      'ChatScreen compose bar sends typed text through the repository '
      '(Requirements 9.4, 9.7)', (WidgetTester tester) async {
    final _FakeChatRepository fake = _FakeChatRepository();
    addTearDown(fake.dispose);
    fake.emitInitial();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatRepositoryProvider.overrideWithValue(fake),
          currentUserProvider.overrideWithValue(_client),
          // Pin connectivity online so the chat streams don't spin up the real
          // polling ConnectivityService (and its timers) during the test.
          isOnlineProvider.overrideWith((ref) => Stream<bool>.value(true)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const ChatScreen(),
            ),
          ),
        ),
      ),
    );
    // Let the conversation + messages streams resolve to their data states.
    await tester.pump();
    await tester.pump();

    // Type a message; the compose bar enables its send button on non-empty text.
    await tester.enterText(find.byType(TextField), 'Hello team');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    // The fake received the typed text as a well-formed message from the client.
    expect(fake.sendCount, 1);
    final SendMessageInput input = fake.lastInput!;
    expect(input.type, MessageType.text);
    expect(input.text, 'Hello team');
    expect(input.senderId, _client.id);
  });
}
