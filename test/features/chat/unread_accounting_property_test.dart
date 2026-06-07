// Property-based test for chat unread-counter accuracy.
//
// Property 6: Unread accuracy
//   For every conversation, after `markRead(conversationId, readerId)` the
//   reader's own unread counter equals 0.
//
// The live rule lives in `FirebaseChatRepository.markRead`, which needs a
// Firestore connection. `lib/features/chat/unread_accounting.dart` factors the
// same accounting into pure functions over an [UnreadState] so the invariant
// can be exercised directly: `applySend` increments the *recipient's* counter
// and `applyMarkRead` zeroes the *reader's own* counter. This test drives those
// pure functions across randomly generated operation sequences (via `glados`),
// which is behaviourally equivalent to running messages/markReads against a
// fake Firestore but without the I/O.
//
// Two facets of the property are checked:
//   1. Sequence invariant — folding a random mix of send/markRead operations,
//      immediately after *any* markRead for a side that side's counter is 0
//      (no matter how many sends preceded it).
//   2. Pointwise invariant — from *any* prior state, a single markRead(reader)
//      drives the reader's counter to exactly 0.
//
// Validates: Requirements 12.2

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart';

import 'package:keyframes_app/features/chat/unread_accounting.dart';

// ---------------------------------------------------------------------------
// Record combinator.
//
// Mirrors the `_rN` tower in test/data/models/serialization_property_test.dart:
// `glados` ships `any.combine2`, which we lift into a 3-field record generator
// so each operation maps cleanly from a positional record onto its fields.
// ---------------------------------------------------------------------------

Generator<(A, B, C)> _r3<A, B, C>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
) =>
    any.combine2(
      any.combine2(a, b, (A x, B y) => (x, y)),
      c,
      ((A, B) p, C z) => (p.$1, p.$2, z),
    );

// ---------------------------------------------------------------------------
// Operation model + generators.
//
// An operation is either a "send" or a "markRead", acting on one of the two
// sides (`isClient == true` => the client side, otherwise the admin side).
// Both flavours are derived from glados' `any.bool` primitive.
// ---------------------------------------------------------------------------

/// A single unread-accounting operation in a generated sequence.
class _Op {
  const _Op({required this.isMarkRead, required this.isClient});

  /// `true` => a `markRead` by [isClient]; `false` => a send by [isClient].
  final bool isMarkRead;

  /// The side performing the operation: `true` => client, `false` => admin.
  final bool isClient;

  @override
  String toString() =>
      '${isMarkRead ? 'markRead' : 'send'}(${isClient ? 'client' : 'admin'})';
}

final Generator<_Op> _anyOp = _r3(any.bool, any.bool, any.bool).map(
  (t) => _Op(isMarkRead: t.$1, isClient: t.$2),
);

final Generator<List<_Op>> _anyOps = any.list(_anyOp);

/// Non-negative starting counters, derived from `any.int` exactly like the
/// `_count` field generator in the serialization property test. Dart's `%`
/// with a positive divisor never yields a negative result, so this stays a
/// valid (non-negative) [UnreadState] even for negative seeds.
final Generator<UnreadState> _anyState = any.combine2(
  any.int,
  any.int,
  (int a, int b) =>
      UnreadState(unreadClient: a % 1000, unreadAdmin: b % 1000),
);

void main() {
  group('Unread accuracy (Property 6, Requirement 12.2)', () {
    Glados2<UnreadState, List<_Op>>(_anyState, _anyOps).test(
      'after any markRead for a side, that side\'s counter is 0',
      (UnreadState start, List<_Op> ops) {
        var state = start;
        for (final op in ops) {
          if (op.isMarkRead) {
            state = applyMarkRead(state, readerIsClient: op.isClient);
            // Immediately after a markRead, the reader's own counter is 0,
            // regardless of how many sends accumulated beforehand.
            expect(
              unreadFor(state, isClient: op.isClient),
              0,
              reason: 'reader counter must be 0 right after $op',
            );
          } else {
            state = applySend(state, senderIsClient: op.isClient);
          }
        }
      },
    );

    Glados2<UnreadState, bool>(_anyState, any.bool).test(
      'markRead(reader) drives the reader\'s counter to 0 from any state',
      (UnreadState start, bool readerIsClient) {
        final after = applyMarkRead(start, readerIsClient: readerIsClient);
        expect(unreadFor(after, isClient: readerIsClient), 0);
      },
    );
  });
}
