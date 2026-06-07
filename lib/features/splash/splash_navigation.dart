/// Pure decision model for the splash screen's "navigate exactly once"
/// contract (Requirements 2.5, 2.6 — design Correctness Property 7,
/// "Splash determinism").
///
/// The [SplashScreen] must leave the splash **exactly once**, and only after
/// BOTH of these have happened:
///
/// * the one-shot entrance animation has completed, AND
/// * `bootstrap()` has resolved.
///
/// Those two triggers can land in any order (and either may fire more than
/// once as the widget rebuilds), so the screen funnels them through a single
/// guarded check. [SplashNavigationGate] extracts that decision logic into a
/// tiny, Flutter-free state machine so it can be reasoned about — and property
/// tested — without pumping widgets, tickers, or timers.
///
/// It tracks the two triggers as latched booleans ([entranceComplete],
/// [bootstrapResolved]) and counts how many times navigation has fired
/// ([navigations]). [evaluate] (invoked automatically by [onEntranceComplete]
/// and [onBootstrapResolved]) increments the counter exactly once, the first
/// time both triggers are present, and never again — making the transition
/// idempotent no matter how the events interleave or repeat.
class SplashNavigationGate {
  bool _entranceComplete = false;
  bool _bootstrapResolved = false;
  int _navigations = 0;

  /// Whether the entrance animation has completed at least once.
  bool get entranceComplete => _entranceComplete;

  /// Whether `bootstrap()` has resolved at least once.
  bool get bootstrapResolved => _bootstrapResolved;

  /// The number of times navigation has been triggered. By construction this
  /// is only ever `0` or `1` (Requirement 2.5 — "navigate exactly once").
  int get navigations => _navigations;

  /// Whether both preconditions are now satisfied (Requirement 2.5). While
  /// this is `false` the splash must stay put (Requirement 2.6).
  bool get ready => _entranceComplete && _bootstrapResolved;

  /// Whether a navigation should be performed *right now*: both triggers are
  /// present and we have not navigated yet. Becomes `false` the instant the
  /// single navigation has fired, guaranteeing idempotency.
  bool get shouldNavigateNow => ready && _navigations == 0;

  /// Latches the entrance-complete trigger and re-evaluates the gate.
  void onEntranceComplete() {
    _entranceComplete = true;
    evaluate();
  }

  /// Latches the bootstrap-resolved trigger and re-evaluates the gate.
  void onBootstrapResolved() {
    _bootstrapResolved = true;
    evaluate();
  }

  /// Increments [navigations] exactly once, the first time both triggers are
  /// present. Calling this repeatedly (or after navigation has already fired)
  /// is a no-op, so the splash can never navigate twice.
  void evaluate() {
    if (shouldNavigateNow) {
      _navigations += 1;
    }
  }
}
