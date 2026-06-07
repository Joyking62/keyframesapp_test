import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'send_message_input.freezed.dart';

/// Immutable input value object for [ChatRepository.sendMessage].
///
/// Well-formedness enforced by the chat layer: a [MessageType.text] message
/// requires non-empty [text]; an image/file message requires a [mediaUrl].
@freezed
class SendMessageInput with _$SendMessageInput {
  const factory SendMessageInput({
    /// The target [Conversation] id.
    required String conversationId,

    /// The sending [AppUser] id.
    required String senderId,

    /// The kind of message being sent.
    required MessageType type,

    /// Text body (required for [MessageType.text]).
    String? text,

    /// Primary media reference (required for image/file types).
    String? mediaUrl,

    /// Additional uploaded attachment references.
    @Default(<String>[]) List<String> attachments,
  }) = _SendMessageInput;
}
