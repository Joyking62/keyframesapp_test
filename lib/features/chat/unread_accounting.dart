/// Pure, Firestore-free model of the chat unread-counter accounting.
///
/// The Keyframes "company" is presented as a single entity, so each
/// conversation tracks two unread counters: one for the client
/// ([UnreadState.unreadClient]) and one for the admin/company side
/// ([UnreadState.unreadAdmin]). The sender/reader side is derived by comparing
/// the actor id against the conversation's `clientId` — the client is whoever
/// matches `clientId`, and anyone else is treated as the admin.
///
/// [FirebaseChatRepository] performs the same accounting against Firestore
/// (incrementing the recipient's counter on `sendMessage`, zeroing the
/// reader's counter on `markRead`). Because that repository needs a live
/// Firestore connection, this file factors the *rules* out into pure functions
/// over a plain [UnreadState] so they can be exercised directly — including by
/// the Property 6 (unread accuracy) property-based test.
///
/// Invariants enforced here mirror the repository:
///   * `sendMessage` increments the **recipient's** counter
///     (sender is client => `unreadAdmin++`; otherwise `unreadClient++`).
///   * `markRead` sets the **reader's own** counter to `0`
///     (reader is client => `unreadClient = 0`; otherwise `unreadAdmin = 0`).
///
/// Validates: Requirements 12.1, 12.2
library;

import 'package:meta/meta.dart';

/// An immutable snapshot of a conversation's two unread counters.
///
/// This is the minimal slice of [Conversation] the unread accounting cares
/// about; keeping it separate lets the rules be tested without constructing a
/// full conversation (which carries ids, timestamps, etc.).
@immutable
class UnreadState {
  /// Creates an [UnreadState] with the given non-negative counters.
  const UnreadState({this.unreadClient = 0, this.unreadAdmin = 0})
      : assert(unreadClient >= 0, 'unreadClient must be non-negative'),
        assert(unreadAdmin >= 0, 'unreadAdmin must be non-negative');

  /// The starting state for a fresh conversation: nothing unread on either side.
  static const UnreadState initial = UnreadState();

  /// Number of messages the client has not yet read.
  final int unreadClient;

  /// Number of messages the admin/company has not yet read.
  final int unreadAdmin;

  /// Returns a copy of this state with the provided fields replaced.
  UnreadState copyWith({int? unreadClient, int? unreadAdmin}) => UnreadState(
        unreadClient: unreadClient ?? this.unreadClient,
        unreadAdmin: unreadAdmin ?? this.unreadAdmin,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnreadState &&
          runtimeType == other.runtimeType &&
          unreadClient == other.unreadClient &&
          unreadAdmin == other.unreadAdmin;

  @override
  int get hashCode => Object.hash(unreadClient, unreadAdmin);

  @override
  String toString() =>
      'UnreadState(unreadClient: $unreadClient, unreadAdmin: $unreadAdmin)';
}

/// Applies a "message sent" event, incrementing the **recipient's** counter.
///
/// When the sender is the client ([senderIsClient] == `true`) the message is
/// addressed to the admin, so [UnreadState.unreadAdmin] is incremented;
/// otherwise the client's counter is incremented. This mirrors
/// `FirebaseChatRepository.sendMessage`'s `FieldValue.increment(1)` on the
/// recipient's field (Requirement 12.1).
UnreadState applySend(
  UnreadState state, {
  required bool senderIsClient,
}) {
  return senderIsClient
      ? state.copyWith(unreadAdmin: state.unreadAdmin + 1)
      : state.copyWith(unreadClient: state.unreadClient + 1);
}

/// Applies a "conversation read" event, zeroing the **reader's own** counter.
///
/// When the reader is the client ([readerIsClient] == `true`)
/// [UnreadState.unreadClient] is reset to `0`; otherwise the admin's counter is
/// reset. This mirrors `FirebaseChatRepository.markRead`, which sets the
/// reader's unread field to `0` (Requirement 12.2). The other side's counter is
/// left untouched.
UnreadState applyMarkRead(
  UnreadState state, {
  required bool readerIsClient,
}) {
  return readerIsClient
      ? state.copyWith(unreadClient: 0)
      : state.copyWith(unreadAdmin: 0);
}

/// Returns the unread counter belonging to the given side.
///
/// `isClient == true` selects [UnreadState.unreadClient]; otherwise
/// [UnreadState.unreadAdmin]. Useful for asserting "the reader's counter" after
/// a [applyMarkRead] without duplicating the side-selection logic.
int unreadFor(UnreadState state, {required bool isClient}) =>
    isClient ? state.unreadClient : state.unreadAdmin;
