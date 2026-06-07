// Property-based test for chat message well-formedness.
//
// Property 5: Message well-formedness
//   For every message-send request `x`:
//     * a `text`/`system` message is accepted iff its text is non-empty;
//     * an `image`/`file` message is accepted iff it carries a media reference;
//     * any other shape is rejected.
//
// This checks the pure, backend-agnostic rule in
// `features/chat/message_validation.dart` (which `FirebaseChatRepository`
// delegates to) across a large space of randomly generated `SendMessageInput`s
// — every `MessageType`, with `text`/`mediaUrl` independently null, empty,
// whitespace-only, or non-blank — so neither a live Firestore nor Storage is
// required to exercise the invariant.
//
// Validates: Requirements 9.4, 9.5
//
// Notes on generation:
//   Field generators are derived deterministically from `any.int` (mirroring
//   the existing serialization property test) so we depend only on glados' core
//   primitives. Dart's `%` with a positive divisor is always non-negative, so
//   the case selectors below are safe even for negative seeds.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart';

import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/send_message_input.dart';
import 'package:keyframes_app/features/chat/message_validation.dart';

// ---------------------------------------------------------------------------
// Record combinator.
//
// glados exposes `any.combine2` for a generator of a pair; we lift it to the
// 5-field record we need so the model generator stays a flat mapping from a
// positional record onto the constructor (same approach as the serialization
// property test).
// ---------------------------------------------------------------------------

Generator<(A, B)> _r2<A, B>(Generator<A> a, Generator<B> b) =>
    any.combine2(a, b, (A x, B y) => (x, y));

Generator<(A, B, C)> _r3<A, B, C>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
) =>
    any.combine2(_r2(a, b), c, ((A, B) p, C z) => (p.$1, p.$2, z));

Generator<(A, B, C, D)> _r4<A, B, C, D>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
) =>
    any.combine2(
      _r3(a, b, c),
      d,
      ((A, B, C) p, D z) => (p.$1, p.$2, p.$3, z),
    );

Generator<(A, B, C, D, E)> _r5<A, B, C, D, E>(
  Generator<A> a,
  Generator<B> b,
  Generator<C> c,
  Generator<D> d,
  Generator<E> e,
) =>
    any.combine2(
      _r4(a, b, c, d),
      e,
      ((A, B, C, D) p, E z) => (p.$1, p.$2, p.$3, p.$4, z),
    );

// ---------------------------------------------------------------------------
// Field generators.
// ---------------------------------------------------------------------------

final Generator<String> _id = any.int.map((int i) => 'id_$i');

final Generator<MessageType> _messageType =
    any.int.map((int i) => MessageType.values[i % MessageType.values.length]);

/// A nullable string spanning the four interesting shapes for well-formedness:
/// `null`, empty, whitespace-only (must be treated as empty after trimming),
/// and a non-blank value.
final Generator<String?> _maybeBlankString = any.int.map((int i) {
  switch (i % 4) {
    case 0:
      return null;
    case 1:
      return '';
    case 2:
      return '   ';
    default:
      return 'value_$i';
  }
});

final Generator<SendMessageInput> _anySendMessageInput = _r5(
  _id,
  _id,
  _messageType,
  _maybeBlankString,
  _maybeBlankString,
).map(
  (t) => SendMessageInput(
    conversationId: t.$1,
    senderId: t.$2,
    type: t.$3,
    text: t.$4,
    mediaUrl: t.$5,
  ),
);

// ---------------------------------------------------------------------------
// Independent oracle for the well-formedness rule.
//
// Recomputed here (rather than calling the production predicate) so the test
// is a genuine specification of Requirements 9.4/9.5 rather than a tautology.
// ---------------------------------------------------------------------------

bool _present(String? s) => s != null && s.trim().isNotEmpty;

bool _expectedAccepted(SendMessageInput input) {
  switch (input.type) {
    case MessageType.text:
    case MessageType.system:
      return _present(input.text);
    case MessageType.image:
    case MessageType.file:
      return _present(input.mediaUrl);
  }
}

MessageValidationFailure? _expectedFailure(SendMessageInput input) {
  if (_expectedAccepted(input)) return null;
  switch (input.type) {
    case MessageType.text:
    case MessageType.system:
      return MessageValidationFailure.emptyText;
    case MessageType.image:
    case MessageType.file:
      return MessageValidationFailure.missingMedia;
  }
}

void main() {
  group('Message well-formedness (Requirements 9.4, 9.5)', () {
    Glados<SendMessageInput>(_anySendMessageInput).test(
      'accepted iff (text/system => non-empty text) '
      '& (image/file => media reference)',
      (SendMessageInput input) {
        final expectedAccepted = _expectedAccepted(input);

        // 1. The pure predicate agrees with the specification oracle.
        expect(MessageValidation.isWellFormed(input), expectedAccepted);

        // 2. `validate` accepts well-formed input and rejects everything else
        //    with the precise failure category.
        if (expectedAccepted) {
          expect(() => MessageValidation.validate(input), returnsNormally);
          expect(MessageValidation.failureFor(input), isNull);
        } else {
          expect(
            () => MessageValidation.validate(input),
            throwsA(
              isA<MessageValidationException>().having(
                (e) => e.failure,
                'failure',
                _expectedFailure(input),
              ),
            ),
          );
        }
      },
    );
  });
}
