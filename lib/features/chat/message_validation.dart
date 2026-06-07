import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/send_message_input.dart';

/// The reason a [SendMessageInput] was rejected as not well-formed.
enum MessageValidationFailure {
  /// A `text`/`system` message was missing non-empty text.
  emptyText,

  /// An `image`/`file` message was missing a media reference.
  missingMedia,
}

/// Thrown when a message is not well-formed (Requirements 9.4, 9.5).
///
/// A [MessageType.text] (or [MessageType.system]) message must carry non-empty
/// text; a [MessageType.image] or [MessageType.file] message must carry a
/// media reference. The offending [failure] is included for precise handling.
class MessageValidationException implements Exception {
  /// Creates a validation exception describing [failure] with a [message].
  const MessageValidationException(this.failure, this.message);

  /// The specific well-formedness rule that was violated.
  final MessageValidationFailure failure;

  /// A human-readable explanation suitable for logging/diagnostics.
  final String message;

  @override
  String toString() => 'MessageValidationException: $message';
}

/// Pure, backend-agnostic well-formedness rules for a [SendMessageInput]
/// (Requirements 9.4, 9.5).
///
/// These rules are deliberately decoupled from Firestore/Firebase Storage so
/// they can be exercised in isolation (e.g. by property-based tests) and reused
/// by any transport. The single source of truth is:
///
/// * a [MessageType.text] or [MessageType.system] message is well-formed iff
///   its [SendMessageInput.text] is non-empty after trimming;
/// * a [MessageType.image] or [MessageType.file] message is well-formed iff
///   its [SendMessageInput.mediaUrl] is non-empty after trimming.
///
/// A message is *accepted* iff it is well-formed and *rejected* otherwise.
abstract final class MessageValidation {
  /// Returns the [MessageValidationFailure] that makes [input] not well-formed,
  /// or `null` when [input] is well-formed.
  ///
  /// This is the pure core both [isWellFormed] and [validate] are defined in
  /// terms of, so all three agree on a single rule.
  static MessageValidationFailure? failureFor(SendMessageInput input) {
    switch (input.type) {
      case MessageType.text:
      case MessageType.system:
        final text = input.text?.trim() ?? '';
        if (text.isEmpty) return MessageValidationFailure.emptyText;
        return null;
      case MessageType.image:
      case MessageType.file:
        final media = input.mediaUrl?.trim() ?? '';
        if (media.isEmpty) return MessageValidationFailure.missingMedia;
        return null;
    }
  }

  /// Whether [input] satisfies the message well-formedness rules.
  static bool isWellFormed(SendMessageInput input) => failureFor(input) == null;

  /// Throws a [MessageValidationException] if [input] is not well-formed;
  /// otherwise returns normally.
  static void validate(SendMessageInput input) {
    final failure = failureFor(input);
    if (failure == null) return;
    switch (failure) {
      case MessageValidationFailure.emptyText:
        throw MessageValidationException(
          failure,
          'A ${input.type.name} message requires non-empty text.',
        );
      case MessageValidationFailure.missingMedia:
        throw MessageValidationException(
          failure,
          'A ${input.type.name} message requires a media reference.',
        );
    }
  }
}
