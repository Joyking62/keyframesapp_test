import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation.freezed.dart';
part 'conversation.g.dart';

/// A single client <-> company chat thread.
///
/// Each client has exactly one [Conversation] with the Keyframes team. The
/// company is presented as a single entity, so unread counters are tracked
/// separately for the client ([unreadClient]) and the admin ([unreadAdmin]).
@freezed
class Conversation with _$Conversation {
  const factory Conversation({
    /// Stable document identifier.
    required String id,

    /// The owning client's [AppUser] id.
    required String clientId,

    /// Display name of the client (denormalized for fast list rendering).
    required String clientName,

    /// Preview text of the most recent message, if any.
    String? lastMessage,

    /// Number of messages the client has not yet read.
    @Default(0) int unreadClient,

    /// Number of messages the admin has not yet read.
    @Default(0) int unreadAdmin,

    /// Timestamp of the most recent activity (used for sorting).
    required DateTime updatedAt,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
}
