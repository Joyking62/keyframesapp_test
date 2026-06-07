import 'dart:typed_data';

import 'package:keyframes_app/data/models/conversation.dart';
import 'package:keyframes_app/data/models/message.dart';
import 'package:keyframes_app/data/models/send_message_input.dart';

/// Domain contract for the real-time client <-> company chat portal.
///
/// Each client has exactly one [Conversation] with the Keyframes team, ensured
/// by [ensureConversation]. Concrete implementations enforce message
/// well-formedness on [sendMessage], maintain per-side unread counters (reset
/// to zero by [markRead]), and keep conversation metadata in sync. The admin
/// inbox is backed by [watchAllConversations].
abstract interface class ChatRepository {
  /// Ensures a single [Conversation] exists for [clientId] and streams it.
  Stream<Conversation> ensureConversation(String clientId);

  /// Streams the messages of the conversation identified by [conversationId]
  /// in real time, ordered chronologically.
  Stream<List<Message>> streamMessages(String conversationId);

  /// Validates and persists a message described by [input], updating the
  /// conversation metadata and the recipient's unread counter.
  Future<void> sendMessage(SendMessageInput input);

  /// Streams every client conversation for the admin inbox.
  Stream<List<Conversation>> watchAllConversations();

  /// Marks the conversation identified by [conversationId] as read for
  /// [readerId], setting that reader's unread counter to zero.
  Future<void> markRead(String conversationId, String readerId);

  /// Uploads an attachment for the conversation identified by [conversationId]
  /// and returns a reference (download URL) suitable for use as a message's
  /// `mediaUrl`.
  ///
  /// Implementations validate the [contentType] against the allowed set and
  /// the [data] length against the maximum size BEFORE uploading, rejecting a
  /// disallowed type or oversize file (Requirement 16.5); a failed upload is
  /// surfaced as an exception so callers can offer a retry control
  /// (Requirement 9.8).
  Future<String> uploadAttachment({
    required String conversationId,
    required String fileName,
    required Uint8List data,
    required String contentType,
  });
}
