import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// A single chat message within a [Conversation].
///
/// Well-formedness (enforced in the chat layer): a [MessageType.text] message
/// must carry non-empty [text]; a [MessageType.image] or [MessageType.file]
/// message must carry a [mediaUrl].
@freezed
class Message with _$Message {
  const factory Message({
    /// Stable document identifier.
    required String id,

    /// The parent [Conversation] id.
    required String conversationId,

    /// The [AppUser] id of the sender.
    required String senderId,

    /// The kind of content carried by this message.
    required MessageType type,

    /// Text body (required for [MessageType.text]).
    String? text,

    /// Reference to an uploaded image/file (required for image/file types).
    String? mediaUrl,

    /// When the message was sent.
    required DateTime sentAt,

    /// Whether the recipient has read the message.
    @Default(false) bool read,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
