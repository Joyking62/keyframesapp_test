import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/core/utils/connectivity.dart';
import 'package:keyframes_app/data/models/conversation.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/message.dart';
import 'package:keyframes_app/data/models/send_message_input.dart';
import 'package:keyframes_app/data/repositories/chat_repository.dart';
import 'package:keyframes_app/features/chat/message_validation.dart';

/// Presentation-layer state and controllers for the real-time chat portal
/// (Requirement 9, Requirement 12.1).
///
/// The chat screen is driven by three pieces:
///
/// * [conversationProvider] — ensures and streams the *single* [Conversation]
///   between the signed-in client and the company (Requirement 9.1). The
///   conversation id is the client's [AppUser] id, which structurally
///   guarantees one conversation per client.
/// * [messagesProvider] — a `family` [StreamProvider] keyed by conversation id
///   that streams the conversation's [Message]s in real time so the view
///   rebuilds on every update (Requirement 9.2).
/// * [chatControllerProvider] — a `family` [NotifierProvider] keyed by
///   conversation id exposing [ChatController.send] / [ChatController.sendImage]
///   (well-formedness enforced on the way in, Requirements 9.4, 9.5), an
///   attachment upload/retry lifecycle (Requirement 9.8), and
///   [ChatController.markRead] to clear the reader's unread counter on open
///   (Requirement 12.2).

// ---------------------------------------------------------------------------
// Streams
// ---------------------------------------------------------------------------

/// Ensures a single [Conversation] exists for the signed-in client and streams
/// it in real time (Requirement 9.1).
///
/// The owning client id is taken from [currentUserProvider]; when no user is
/// signed in the stream is empty (the screen handles the signed-out case
/// separately). Delegates to [ChatRepository.ensureConversation], which creates
/// the conversation document on first access and then emits live updates.
final conversationProvider = StreamProvider<Conversation>((ref) {
  // Re-subscribe when connectivity is regained so a dropped conversation stream
  // is automatically retried once the network returns (Requirement 17.2).
  ref.watch(isOnlineProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const Stream<Conversation>.empty();
  }
  return ref.watch(chatRepositoryProvider).ensureConversation(user.id);
});

/// Streams the messages of the conversation identified by [conversationId]
/// in real time, ordered chronologically (Requirement 9.2).
///
/// A `family` provider so each conversation gets its own independently-cached
/// subscription. The chat screen watches
/// `messagesProvider(conversation.id)` and rebuilds on every snapshot.
final messagesProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  // Re-subscribe when connectivity is regained so a dropped message stream is
  // automatically retried once the network returns (Requirement 17.2).
  ref.watch(isOnlineProvider);
  return ref.watch(chatRepositoryProvider).streamMessages(conversationId);
});

// ---------------------------------------------------------------------------
// Controller state
// ---------------------------------------------------------------------------

/// The lifecycle phase of an in-flight image/file attachment.
enum AttachmentPhase {
  /// The attachment is currently being uploaded (and then sent).
  uploading,

  /// The upload (or the follow-up send) failed; a retry control is shown.
  failed,
}

/// A pending attachment being uploaded through the chat repository.
///
/// The raw [data] is retained so a failed upload can be retried without
/// re-picking the image (Requirement 9.8).
class PendingAttachment {
  /// Creates a pending attachment descriptor.
  const PendingAttachment({
    required this.fileName,
    required this.data,
    required this.contentType,
    required this.phase,
    this.error,
  });

  /// The original file name (used to derive the stored object name).
  final String fileName;

  /// The raw bytes to upload; retained to support retry.
  final Uint8List data;

  /// The MIME content type (e.g. `image/jpeg`).
  final String contentType;

  /// The current upload phase.
  final AttachmentPhase phase;

  /// A human-readable failure reason when [phase] is [AttachmentPhase.failed].
  final String? error;

  /// Returns a copy with the given fields replaced.
  PendingAttachment copyWith({
    AttachmentPhase? phase,
    String? error,
    bool clearError = false,
  }) {
    return PendingAttachment(
      fileName: fileName,
      data: data,
      contentType: contentType,
      phase: phase ?? this.phase,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Immutable view-state for a single conversation's compose/send experience.
class ChatState {
  /// Creates a chat compose state.
  const ChatState({
    this.sending = false,
    this.sendError,
    this.attachment,
  });

  /// Whether a text message send is currently in flight.
  final bool sending;

  /// The most recent send/validation error, or `null` when there is none.
  ///
  /// Surfaced transiently by the screen (e.g. a snackbar) then cleared via
  /// [ChatController.clearError].
  final String? sendError;

  /// The current pending attachment, or `null` when none is in flight.
  final PendingAttachment? attachment;

  /// Returns a copy with the given fields replaced.
  ///
  /// [clearError] / [clearAttachment] explicitly reset their respective
  /// nullable fields to `null` (since `copyWith(field: null)` cannot be
  /// distinguished from "leave unchanged").
  ChatState copyWith({
    bool? sending,
    String? sendError,
    PendingAttachment? attachment,
    bool clearError = false,
    bool clearAttachment = false,
  }) {
    return ChatState(
      sending: sending ?? this.sending,
      sendError: clearError ? null : (sendError ?? this.sendError),
      attachment: clearAttachment ? null : (attachment ?? this.attachment),
    );
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Live chat controller for one [Conversation] (keyed by its id).
///
/// Enforces message well-formedness before delegating to
/// [ChatRepository.sendMessage] (Requirements 9.4, 9.5); the repository in turn
/// persists the message, updates conversation metadata, and bumps the
/// recipient's unread counter (Requirements 9.6, 12.1). Image attachments are
/// uploaded through [ChatRepository.uploadAttachment] with an explicit
/// uploading/failed lifecycle so the UI can offer a retry control on failure
/// (Requirement 9.8).
class ChatController extends FamilyNotifier<ChatState, String> {
  @override
  ChatState build(String arg) => const ChatState();

  /// The conversation id this controller acts on.
  String get _conversationId => arg;

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  /// The signed-in user's id, used as the message [SendMessageInput.senderId].
  String? get _senderId => ref.read(currentUserProvider)?.id;

  /// Validates and sends a text message (Requirements 9.4, 9.6).
  ///
  /// Rejects empty/whitespace-only text up front via [MessageValidation] so the
  /// UI can keep the send button disabled and surface a clear error rather than
  /// writing a malformed message.
  Future<void> send(String text) async {
    final senderId = _senderId;
    if (senderId == null) {
      state = state.copyWith(sendError: 'You must be signed in to send messages.');
      return;
    }

    final input = SendMessageInput(
      conversationId: _conversationId,
      senderId: senderId,
      type: MessageType.text,
      text: text,
    );

    // Enforce text well-formedness before attempting the write (R9.4).
    if (!MessageValidation.isWellFormed(input)) {
      state = state.copyWith(sendError: 'Enter a message before sending.');
      return;
    }

    state = state.copyWith(sending: true, clearError: true);
    try {
      await _repository.sendMessage(input);
      state = state.copyWith(sending: false);
    } on MessageValidationException catch (e) {
      state = state.copyWith(sending: false, sendError: e.message);
    } catch (_) {
      state = state.copyWith(
        sending: false,
        sendError: 'Message could not be sent. Please try again.',
      );
    }
  }

  /// Uploads an image attachment and sends it as an [MessageType.image] message
  /// (Requirements 9.5, 9.6, 9.8).
  ///
  /// The bytes are retained in [ChatState.attachment] so a failed upload can be
  /// retried via [retryAttachment] without re-picking the image.
  Future<void> sendImage({
    required String fileName,
    required Uint8List data,
    required String contentType,
  }) async {
    state = state.copyWith(
      attachment: PendingAttachment(
        fileName: fileName,
        data: data,
        contentType: contentType,
        phase: AttachmentPhase.uploading,
      ),
    );
    await _uploadAndSend();
  }

  /// Retries the most recent failed attachment upload (Requirement 9.8).
  ///
  /// No-op when there is no pending attachment.
  Future<void> retryAttachment() async {
    final pending = state.attachment;
    if (pending == null) {
      return;
    }
    state = state.copyWith(
      attachment: pending.copyWith(
        phase: AttachmentPhase.uploading,
        clearError: true,
      ),
    );
    await _uploadAndSend();
  }

  /// Discards the current pending/failed attachment without sending it.
  void cancelAttachment() {
    state = state.copyWith(clearAttachment: true);
  }

  Future<void> _uploadAndSend() async {
    final pending = state.attachment;
    if (pending == null) {
      return;
    }

    final senderId = _senderId;
    if (senderId == null) {
      state = state.copyWith(
        attachment: pending.copyWith(
          phase: AttachmentPhase.failed,
          error: 'You must be signed in to send attachments.',
        ),
      );
      return;
    }

    try {
      // The upload itself goes through the repository (Firebase Storage in the
      // Firebase implementation); the returned download URL becomes the
      // message's mediaUrl.
      final mediaUrl = await _repository.uploadAttachment(
        conversationId: _conversationId,
        fileName: pending.fileName,
        data: pending.data,
        contentType: pending.contentType,
      );

      await _repository.sendMessage(
        SendMessageInput(
          conversationId: _conversationId,
          senderId: senderId,
          type: MessageType.image,
          mediaUrl: mediaUrl,
        ),
      );

      // Success: clear the pending attachment.
      state = state.copyWith(clearAttachment: true);
    } catch (_) {
      // Mark the attachment failed and keep its bytes so the user can retry
      // (Requirement 9.8).
      state = state.copyWith(
        attachment: pending.copyWith(
          phase: AttachmentPhase.failed,
          error: 'Upload failed. Tap retry to try again.',
        ),
      );
    }
  }

  /// Marks the conversation as read for the signed-in reader, resetting their
  /// unread counter to zero (Requirement 12.2). Best-effort; failures are
  /// swallowed so opening the screen never throws.
  Future<void> markRead() async {
    final readerId = _senderId;
    if (readerId == null) {
      return;
    }
    try {
      await _repository.markRead(_conversationId, readerId);
    } catch (_) {
      // Best-effort: ignore mark-read failures.
    }
  }

  /// Clears any transient send/validation error after it has been shown.
  void clearError() {
    if (state.sendError != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

/// The chat controller for a conversation, keyed by its id.
final chatControllerProvider =
    NotifierProvider.family<ChatController, ChatState, String>(
  ChatController.new,
);
