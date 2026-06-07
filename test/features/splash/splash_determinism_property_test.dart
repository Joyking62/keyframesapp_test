// Property-based test for the splash screen's "navigate exactly once"
// contract (design Correctness Property 7, "Splash determinism").
//
// Property 7: Splash determinism
//   The app always leaves the splash EXACTLY ONCE, and only after BOTH the
//   entrance animation has completed AND `bootstrap()` has resolved — never
//   before both have happened, and never more than once (no infinite
//   preloader, no double navigation).
//
// Validates: Requirements 2.5, 2.6
//
// What is under test:
//   The decision is extracted from `SplashScreen` into the pure, Flutter-free
//   `SplashNavigationGate` (the screen wires both of its triggers through that
//   gate, so the two cannot diverge). Because the gate is pure, we can replay
//   arbitrary interleavings of the two events WITHOUT pumping the widget tree,
//   tickers, or timers.
//
// Strategy:
//   We generate a random-length list of integers and map each one onto one of
//   the two trigger events ({entrance, bootstrap}) via `any.int` + modulo. The
//   sequence deliberately allows DUPLICATES (the same trigger firing many
//   times) and ANY ORDER, mirroring how the real widget may receive repeated
//   animation-status callbacks and provider rebuilds.
//
//   An independent oracle walks the same sequence using plain booleans
//   (`sawEntrance`, `sawBootstrap`) so it shares no logic with the gate. After
//   feeding EACH event we assert the gate's navigation count equals the oracle:
//     navigations == 1  iff  (sawEntrance && sawBootstrap)   else 0
//   That single invariant, checked at every prefix of the sequence, captures
//   every facet of the property:
//     * before both have occurred            -> navigations == 0  (Req 2.6)
//     * the first moment both have occurred  -> navigations == 1  (Req 2.5)
//     * any further events once navigated     -> still 1 (idempotent, no
//       double navigation)
//     * navigations is never > 1 and never fires early.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart';

import 'package:keyframes_app/features/splash/splash_navigation.dart';

/// The two triggers that gate the splash's single navigation.
enum _SplashEvent { entrance, bootstrap }

/// Maps a raw generated integer onto a [_SplashEvent]. Dart's `%` with a
/// positive divisor is always non-negative, so negative seeds are safe and the
/// two events are reachable with roughly equal probability.
_SplashEvent _eventFor(int raw) =>
    _SplashEvent.values[raw % _SplashEvent.values.length];

/// Applies a single [event] to the [gate], mirroring how `SplashScreen` funnels
/// its entrance-status and bootstrap-resolution callbacks into the gate.
void _apply(SplashNavigationGate gate, _SplashEvent event) {
  switch (event) {
    case _SplashEvent.entrance:
      gate.onEntranceComplete();
    case _SplashEvent.bootstrap:
      gate.onBootstrapResolved();
  }
}

/// A random-length sequence of raw event seeds (any order, possibly repeated).
final Generator<List<int>> _eventSeqGen = any.list(any.int);

void main() {
  group('Splash determinism (Property 7, Requirements 2.5, 2.6)', () {
    Glados<List<int>>(_eventSeqGen).test(
      'navigates exactly once, and only after BOTH triggers have occurred',
      (List<int> rawEvents) {
        final SplashNavigationGate gate = SplashNavigationGate();

        // Independent oracle: plain latches that share no code with the gate.
        bool sawEntrance = false;
        bool sawBootstrap = false;

        // A brand-new gate has not navigated and is not ready.
        expect(gate.navigations, equals(0));
        expect(gate.ready, isFalse);

        for (final int raw in rawEvents) {
          final _SplashEvent event = _eventFor(raw);

          _apply(gate, event);
          if (event == _SplashEvent.entrance) {
            sawEntrance = true;
          } else {
            sawBootstrap = true;
          }

          final bool bothOccurred = sawEntrance && sawBootstrap;
          final int expectedNavigations = bothOccurred ? 1 : 0;

          // The core invariant, asserted at every prefix of the sequence:
          //   * 0 navigations until both triggers have fired (Req 2.6), and
          //   * exactly 1 once both have fired — never more, regardless of how
          //     many further (duplicate) events arrive (Req 2.5).
          expect(
            gate.navigations,
            equals(expectedNavigations),
            reason: 'after events $rawEvents (sawEntrance=$sawEntrance, '
                'sawBootstrap=$sawBootstrap) navigations should be '
                '$expectedNavigations',
          );

          // The gate's latched flags must agree with the oracle's view.
          expect(gate.entranceComplete, equals(sawEntrance));
          expect(gate.bootstrapResolved, equals(sawBootstrap));
          expect(gate.ready, equals(bothOccurred));

          // Once navigated, there is never anything left to do.
          expect(gate.shouldNavigateNow, isFalse);
        }

        // Final state: navigation happened iff both triggers occurred, and the
        // count is capped at one (no double navigation, no infinite preloader).
        final bool bothOccurred = sawEntrance && sawBootstrap;
        expect(gate.navigations, equals(bothOccurred ? 1 : 0));
        expect(gate.navigations, lessThanOrEqualTo(1));
      },
    );

    // A focused regression for the trailing-idempotency clause: once both
    // triggers have fired, an arbitrary burst of further events must never
    // bump the navigation count past one.
    Glados<List<int>>(_eventSeqGen).test(
      'further events after navigation never increment the count',
      (List<int> rawTrailingEvents) {
        final SplashNavigationGate gate = SplashNavigationGate();

        // Drive the gate to its single navigation.
        gate.onEntranceComplete();
        gate.onBootstrapResolved();
        expect(gate.navigations, equals(1));

        // Replay any further interleaving of the two triggers.
        for (final int raw in rawTrailingEvents) {
          _apply(gate, _eventFor(raw));
          gate.evaluate(); // explicit re-evaluation must also stay idempotent
          expect(gate.navigations, equals(1));
          expect(gate.shouldNavigateNow, isFalse);
        }
      },
    );
  });
}
