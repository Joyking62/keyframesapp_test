import 'dart:ui' show lerpDouble;

// `package:flutter/widgets.dart` provides the animation primitives
// (AnimationController, CurvedAnimation, Curves, Interval, Tween, Animation,
// TickerProvider) and re-exports `Matrix4` from vector_math_64.
import 'package:flutter/widgets.dart';

/// Builds the perspective [Matrix4] applied to the Keyframes logo on the
/// 3D-depth splash / preloader.
///
/// The transform composes four effects, in the exact order required for a
/// believable 3D depth emerge:
///
/// 1. **Perspective** — `setEntry(3, 2, 0.0015)` installs the perspective
///    divisor that turns the otherwise-orthographic `translateZ` into a real
///    depth cue (closer = larger).
/// 2. **translateZ** — interpolated from `-400` (far away) to `0` (at the
///    screen plane) as [depth] runs `0 -> 1`.
/// 3. **rotateX / rotateY** — the idle sway tilt (radians).
/// 4. **scale** — interpolated from `0.6` to `1.0` as [depth] runs `0 -> 1`.
///
/// This is a pure function of its inputs (no widget/state dependencies) so it
/// can be exercised directly by unit and property-based tests.
///
/// Requirements: 2.1 (Matrix4 perspective 3D depth), 2.2 (scale 0.6->1.0 and
/// translateZ -400->0), 2.3 (X/Y tilt sway).
Matrix4 buildDepthTransform({
  required double depth, // 0..1 entrance progress
  required double tiltX, // radians
  required double tiltY, // radians
}) {
  final double translateZ = lerpDouble(-400.0, 0.0, depth)!;
  final double scale = lerpDouble(0.6, 1.0, depth)!;
  return Matrix4.identity()
    ..setEntry(3, 2, 0.0015) // perspective (the key to 3D depth)
    ..translate(0.0, 0.0, translateZ)
    ..rotateX(tiltX)
    ..rotateY(tiltY)
    ..scale(scale);
}

/// Orchestrates the two animation controllers behind the splash screen:
///
/// * [entrance] — a one-shot controller driving the depth emerge (scale +
///   translateZ), the logo opacity reveal, and the wordmark slide/fade.
/// * [sway] — a looping (`repeat(reverse: true)`) controller driving the subtle
///   idle 3D tilt once the entrance has settled.
///
/// The class is intentionally UI-logic only: it owns no widgets and performs no
/// navigation (that lives with the `SplashScreen` widget / `redirectAfterSplash`
/// in task 13.2). A [TickerProvider] is injected so the owning `State` controls
/// the controllers' lifecycle.
///
/// Requirements: 2.2 (ease-out entrance: scale 0.6->1.0, translateZ -400->0),
/// 2.3 (looping idle sway, tilt within -0.08..0.08 radians).
class SplashAnimator {
  /// Creates the animator, wiring both controllers to [vsync].
  ///
  /// [entranceDuration] defaults to ~800ms (refined R2 entrance timing) and
  /// [swayDuration] to ~4000ms for a slow, premium idle oscillation.
  SplashAnimator({
    required TickerProvider vsync,
    Duration entranceDuration = const Duration(milliseconds: 800),
    Duration swayDuration = const Duration(milliseconds: 4000),
  })  : entrance = AnimationController(vsync: vsync, duration: entranceDuration),
        sway = AnimationController(vsync: vsync, duration: swayDuration) {
    // Eased depth: logo scales from 0.6 -> 1.0 with translateZ from -400 -> 0.
    depth = CurvedAnimation(parent: entrance, curve: Curves.easeOutCubic);

    // Logo opacity 0 -> 1 over the middle of the entrance.
    reveal = CurvedAnimation(
      parent: entrance,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    );

    // Wordmark slide + fade near the end of the entrance.
    wordmark = CurvedAnimation(
      parent: entrance,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    // Idle X/Y tilt in radians, oscillating within ~[-0.08, 0.08]. The two
    // axes use slightly different easing so the sway feels organic rather than
    // a perfectly synchronized wobble.
    tiltX = Tween<double>(begin: -_tiltAmplitude, end: _tiltAmplitude).animate(
      CurvedAnimation(parent: sway, curve: Curves.easeInOut),
    );
    tiltY = Tween<double>(begin: _tiltAmplitude, end: -_tiltAmplitude).animate(
      CurvedAnimation(parent: sway, curve: Curves.easeInOutSine),
    );
  }

  /// Maximum idle tilt magnitude in radians (Requirement 2.3: -0.08..0.08).
  static const double _tiltAmplitude = 0.08;

  /// Drives the one-shot entrance (depth emerge + reveal).
  final AnimationController entrance;

  /// Drives the looping idle sway (3D rotation), repeated with reverse.
  final AnimationController sway;

  /// Eased depth progress `0 -> 1` (Curves.easeOutCubic). Feeds the `depth`
  /// argument of [buildDepthTransform].
  late final Animation<double> depth;

  /// Logo opacity reveal `0 -> 1` (Interval 0.2..0.7).
  late final Animation<double> reveal;

  /// Wordmark slide + fade progress `0 -> 1` (Interval 0.6..1.0).
  late final Animation<double> wordmark;

  /// Idle tilt about the X axis in radians, within `[-0.08, 0.08]`.
  late final Animation<double> tiltX;

  /// Idle tilt about the Y axis in radians, within `[-0.08, 0.08]`.
  late final Animation<double> tiltY;

  /// Plays the entrance once, then starts the looping idle sway as soon as the
  /// entrance completes.
  void start() {
    entrance.forward().whenCompleteOrCancel(() {
      // Only begin the idle sway if the entrance actually finished (not if the
      // controller was disposed/cancelled mid-flight).
      if (entrance.status == AnimationStatus.completed) {
        sway.repeat(reverse: true);
      }
    });
  }

  /// Disposes both controllers. Must be called from the owning `State.dispose`.
  void dispose() {
    entrance.dispose();
    sway.dispose();
  }
}
