import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:meta/meta.dart';

import 'package:keyframes_app/core/utils/sanitizer.dart';
import 'package:keyframes_app/data/models/conversation.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/message.dart';
import 'package:keyframes_app/data/models/send_message_input.dart';
import 'package:keyframes_app/data/repositories/chat_repository.dart';
import 'package:keyframes_app/features/chat/message_validation.dart';

// The well-formedness rules (Requirements 9.4, 9.5) live in
// `features/chat/message_validation.dart` as a pure, backend-agnostic module so
// they can be tested in isolation. They are re-exported here so existing
// callers that catch [MessageValidationException] / switch on
// [MessageValidationFailure] from this repository continue to work unchanged.
export 'package:keyframes_app/features/chat/message_validation.dart'
    show MessageValidationException, MessageValidationFailure;

/// The reason an attachment upload was rejected or failed (Requirement 16.5).
enum AttachmentUploadFailure {
  /// The file's content type is not in the allowed set.
  disallowedType,

  /// The file exceeds the maximum allowed size.
  tooLarge,

  /// The upload itself failed (network/permission/storage error).
  uploadFailed,
}

/// Thrown by [FirebaseChatRepository.uploadAttachment] when an attachment
/// violates the allowed file-type or size constraints, or the upload fails.
///
/// Per Requirement 16.5 the upload is rejected rather than silently truncated
/// or coerced; callers should surface a retry affordance (Requirement 9.8).
class AttachmentUploadException implements Exception {
  /// Creates an upload exception describing [failure] with a [message].
  const AttachmentUploadException(this.failure, this.message);

  /// The specific failure category.
  final AttachmentUploadFailure failure;

  /// A human-readable explanation suitable for logging/diagnostics.
  final String message;

  @override
  String toString() => 'AttachmentUploadException: $message';
}

/// Firestore + Firebase Storage backed implementation of [ChatRepository].
///
/// ## Data layout
///
/// * `conversations/{conversationId}` — one document per client. The document
///   id is the owning client's id, which structurally guarantees a single
///   conversation per client ([ensureConversation]). Fields mirror
///   [Conversation]: `clientId`, `clientName`, `lastMessage`, `unreadClient`,
///   `unreadAdmin`, and `updatedAt` (stored as a Firestore [Timestamp]).
/// * `conversations/{conversationId}/messages/{messageId}` — the messages
///   subcollection, ordered by `sentAt`. Fields mirror [Message].
/// * Attachments are uploaded to Firebase Storage under
///   `chat_attachments/{conversationId}/...` by [uploadAttachment].
///
/// ## Unread accounting
///
/// The "company" is presented as a single entity, so unread counts are tracked
/// per side: `unreadClient` and `unreadAdmin`. The sender/reader side is
/// derived by comparing the actor id against the conversation's `clientId`
/// (the client) — anyone else is treated as the admin. On [sendMessage] the
/// recipient's counter is incremented (Requirement 12.1); on [markRead] the
/// reader's counter is reset to zero (Requirement 12.2).
class FirebaseChatRepository implements ChatRepository {
  /// Creates a [FirebaseChatRepository].
  ///
  /// [firestore] and [storage] default to the singleton instances but can be
  /// injected (e.g. with fakes/emulator handles) for testing. The collection
  /// names, allowed attachment content types, and maximum attachment size are
  /// also overridable.
  FirebaseChatRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    this.conversationsCollection = 'conversations',
    this.messagesSubcollection = 'messages',
    this.usersCollection = 'users',
    this.attachmentsFolder = 'chat_attachments',
    Set<String>? allowedContentTypes,
    this.maxAttachmentBytes = defaultMaxAttachmentBytes,
    this.maxMessageLength = defaultMaxMessageLength,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        allowedContentTypes =
            allowedContentTypes ?? defaultAllowedContentTypes;

  /// Default maximum attachment size: 10 MiB.
  static const int defaultMaxAttachmentBytes = 10 * 1024 * 1024;

  /// Default maximum stored length of a text message body.
  static const int defaultMaxMessageLength = 5000;

  /// Default set of content types accepted by [uploadAttachment].
  static const Set<String> defaultAllowedContentTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/pdf',
    'text/plain',
  };

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// Top-level conversations collection name.
  final String conversationsCollection;

  /// Messages subcollection name under each conversation document.
  final String messagesSubcollection;

  /// Users collection name, consulted to denormalize the client display name.
  final String usersCollection;

  /// Storage folder under which chat attachments are uploaded.
  final String attachmentsFolder;

  /// Content types accepted by [uploadAttachment]; anything else is rejected.
  final Set<String> allowedContentTypes;

  /// Maximum attachment size in bytes; larger uploads are rejected.
  final int maxAttachmentBytes;

  /// Maximum stored length of a text message body (sanitized + clamped).
  final int maxMessageLength;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection(conversationsCollection);

  CollectionReference<Map<String, dynamic>> _messagesOf(String conversationId) =>
      _conversations.doc(conversationId).collection(messagesSubcollection);

  // ---------------------------------------------------------------------------
  // ChatRepository
  // ---------------------------------------------------------------------------

  @override
  Stream<Conversation> ensureConversation(String clientId) async* {
    final docRef = _conversations.doc(clientId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      final clientName = await _resolveClientName(clientId);
      await docRef.set(<String, dynamic>{
        'clientId': clientId,
        'clientName': clientName,
        'lastMessage': null,
        'unreadClient': 0,
        'unreadAdmin': 0,
        'updatedAt': Timestamp.now(),
      });
    }

    yield* docRef
        .snapshots()
        .where((snap) => snap.exists)
        .map(_conversationFromDoc);
  }

  @override
  Stream<List<Message>> streamMessages(String conversationId) {
    return _messagesOf(conversationId)
        .orderBy('sentAt')
        .snapshots()
        .map((query) => query.docs.map(_messageFromDoc).toList());
  }

  @override
  Future<void> sendMessage(SendMessageInput input) async {
    // 1. Enforce well-formedness on the raw input (Requirements 9.4, 9.5).
    _validateWellFormedness(input);

    // 2. Sanitize free-text before persistence (Requirement 16.4).
    final isTextual =
        input.type == MessageType.text || input.type == MessageType.system;
    final String? sanitizedText = isTextual
        ? sanitizeText(input.text, maxLength: maxMessageLength)
        : (input.text == null ? null : sanitizeText(input.text));

    // Sanitization must not have emptied a required text body.
    if (isTextual && (sanitizedText == null || sanitizedText.isEmpty)) {
      throw const MessageValidationException(
        MessageValidationFailure.emptyText,
        'Message text was empty after sanitization.',
      );
    }

    final convRef = _conversations.doc(input.conversationId);
    final messageRef = convRef.collection(messagesSubcollection).doc();
    final now = Timestamp.now();

    // 3. Atomically persist the message, update conversation meta, and bump the
    //    recipient's unread counter (Requirements 9.6, 12.1).
    await _firestore.runTransaction<void>((txn) async {
      final convSnap = await txn.get(convRef);
      if (!convSnap.exists) {
        throw StateError(
          'Conversation "${input.conversationId}" does not exist.',
        );
      }

      final clientId = convSnap.data()?['clientId'] as String?;
      // Increment the OTHER side's unread counter (Requirement 12.1).
      final recipientUnreadField = recipientUnreadFieldFor(
        conversationClientId: clientId,
        senderId: input.senderId,
      );

      txn.set(messageRef, <String, dynamic>{
        'conversationId': input.conversationId,
        'senderId': input.senderId,
        'type': input.type.name,
        'text': sanitizedText,
        'mediaUrl': input.mediaUrl,
        'attachments': input.attachments,
        'sentAt': now,
        'read': false,
      });

      txn.update(convRef, <String, dynamic>{
        'lastMessage': _previewFor(input, sanitizedText),
        'updatedAt': now,
        recipientUnreadField: FieldValue.increment(1),
      });
    });
  }

  @override
  Stream<List<Conversation>> watchAllConversations() {
    return _conversations
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((query) => query.docs.map(_conversationFromDoc).toList());
  }

  @override
  Future<void> markRead(String conversationId, String readerId) async {
    final convRef = _conversations.doc(conversationId);
    final convSnap = await convRef.get();
    if (!convSnap.exists) return;

    final clientId = convSnap.data()?['clientId'] as String?;
    // Reset the reader's own unread counter (Requirement 12.2).
    final readerUnreadField = readerUnreadFieldFor(
      conversationClientId: clientId,
      readerId: readerId,
    );

    // Mark messages authored by the other party as read (read receipts).
    final unread =
        await convRef.collection(messagesSubcollection).where('read', isEqualTo: false).get();

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      final senderId = doc.data()['senderId'] as String?;
      if (senderId != readerId) {
        batch.update(doc.reference, <String, dynamic>{'read': true});
      }
    }
    batch.update(convRef, <String, dynamic>{readerUnreadField: 0});

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Attachment upload
  // ---------------------------------------------------------------------------

  /// Uploads an attachment to Firebase Storage and returns its download URL.
  ///
  /// Validates the [contentType] against [allowedContentTypes] and the
  /// [data] length against [maxAttachmentBytes] BEFORE attempting the upload,
  /// rejecting a disallowed type or oversize file with an
  /// [AttachmentUploadException] (Requirement 16.5). A failed upload is also
  /// surfaced as an [AttachmentUploadException] so callers can show a retry
  /// control (Requirement 9.8).
  @override
  Future<String> uploadAttachment({
    required String conversationId,
    required String fileName,
    required Uint8List data,
    required String contentType,
  }) async {
    final normalizedType = contentType.trim().toLowerCase();
    if (!allowedContentTypes.contains(normalizedType)) {
      throw AttachmentUploadException(
        AttachmentUploadFailure.disallowedType,
        'Content type "$contentType" is not an allowed attachment type.',
      );
    }

    if (data.lengthInBytes > maxAttachmentBytes) {
      throw AttachmentUploadException(
        AttachmentUploadFailure.tooLarge,
        'Attachment is ${data.lengthInBytes} bytes, which exceeds the '
        '$maxAttachmentBytes byte limit.',
      );
    }

    try {
      final safeName = _sanitizeFileName(fileName);
      final objectName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final ref = _storage
          .ref()
          .child(attachmentsFolder)
          .child(conversationId)
          .child(objectName);

      final task = await ref.putData(
        data,
        SettableMetadata(contentType: normalizedType),
      );
      return await task.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw AttachmentUploadException(
        AttachmentUploadFailure.uploadFailed,
        'Attachment upload failed: ${e.code} ${e.message ?? ''}'.trim(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// The conversation unread field that must be incremented when [senderId]
  /// sends a message in the conversation owned by [conversationClientId].
  ///
  /// Unread is tracked per side (`unreadClient` / `unreadAdmin`). The recipient
  /// is always the *other* party: a message from the client bumps the admin's
  /// counter, and a message from anyone else (the admin) bumps the client's
  /// counter (Requirement 12.1). A `null` [conversationClientId] is treated as
  /// "sender is not the client", so the client's counter is incremented.
  ///
  /// This mirrors the side-selection in `unread_accounting.dart`'s `applySend`
  /// but returns the Firestore *field name* the repository increments. Exposed
  /// for testing so the pure recipient-routing decision can be verified without
  /// a live Firestore transaction.
  @visibleForTesting
  static String recipientUnreadFieldFor({
    required String? conversationClientId,
    required String senderId,
  }) {
    final senderIsClient =
        conversationClientId != null && senderId == conversationClientId;
    return senderIsClient ? 'unreadAdmin' : 'unreadClient';
  }

  /// The conversation unread field reset to zero when [readerId] reads the
  /// conversation owned by [conversationClientId] (Requirement 12.2).
  ///
  /// The reader resets *their own* counter: the client clears `unreadClient`,
  /// while anyone else (the admin) clears `unreadAdmin`. Exposed for testing
  /// alongside [recipientUnreadFieldFor].
  @visibleForTesting
  static String readerUnreadFieldFor({
    required String? conversationClientId,
    required String readerId,
  }) {
    final readerIsClient =
        conversationClientId != null && readerId == conversationClientId;
    return readerIsClient ? 'unreadClient' : 'unreadAdmin';
  }

  void _validateWellFormedness(SendMessageInput input) =>
      MessageValidation.validate(input);

  String _previewFor(SendMessageInput input, String? sanitizedText) {
    switch (input.type) {
      case MessageType.text:
      case MessageType.system:
        return sanitizedText ?? '';
      case MessageType.image:
        return '[Image]';
      case MessageType.file:
        return '[File]';
    }
  }

  Future<String> _resolveClientName(String clientId) async {
    try {
      final userSnap = await _firestore.collection(usersCollection).doc(clientId).get();
      final name = userSnap.data()?['name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } on FirebaseException {
      // Best-effort denormalization; fall through to a placeholder.
    }
    return 'Client';
  }

  String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    final base = trimmed.isEmpty ? 'attachment' : trimmed;
    // Replace any character that isn't alphanumeric, dot, dash or underscore.
    return base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  Conversation _conversationFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Conversation(
      id: doc.id,
      clientId: data['clientId'] as String? ?? doc.id,
      clientName: data['clientName'] as String? ?? '',
      lastMessage: data['lastMessage'] as String?,
      unreadClient: (data['unreadClient'] as num?)?.toInt() ?? 0,
      unreadAdmin: (data['unreadAdmin'] as num?)?.toInt() ?? 0,
      updatedAt: _dateFrom(data['updatedAt']),
    );
  }

  Message _messageFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Message(
      id: doc.id,
      conversationId: data['conversationId'] as String? ??
          doc.reference.parent.parent?.id ??
          '',
      senderId: data['senderId'] as String? ?? '',
      type: _messageTypeFromName(data['type'] as String?),
      text: data['text'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
      sentAt: _dateFrom(data['sentAt']),
      read: data['read'] as bool? ?? false,
    );
  }

  MessageType _messageTypeFromName(String? name) {
    return MessageType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => MessageType.text,
    );
  }

  DateTime _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
