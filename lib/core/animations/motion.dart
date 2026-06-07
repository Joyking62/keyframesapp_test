import 'package:flutter/widgets.dart';

/// Shared motion tokens and accessibility-aware helpers for the Keyframes
/// animation system.
///
/// Every reusable animation builder in `core/animations/` routes its timing and
/// curve choices through [KMotion] so the app has a single, consistent motion
/// language. The helpers also honor the platform "disable animations"
/// accessibility setting (`MediaQuery.disableAnimations`) by zeroing out
/// non-essential motion.
///
/// Requirements: 14.1, 14.4 — consistent route motion that respects the
/// platform reduce-motion setting.
abstract final class KMotion {
  /// Quick micro-interactions (press, ripple, chip selection).
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions (most route + list entrances).
  static const Duration medium = Duration(milliseconds: 300);

  /// Expressive transitions (hero/shared-axis, count-up KPIs).
  static const Duration slow = Duration(milliseconds: 450);

  /// Default easing for content entering the screen.
  static const Curve enter = Curves.easeOutCubic;

  /// Default easing for content leaving the screen.
  static const Curve exit = Curves.easeInCubic;

  /// Whether the platform "disable animations" accessibility flag is set.
  ///
  /// Returns `false` when no [MediaQuery] ancestor is available so callers can
  /// be used safely outside a fully built widget tree.
  static bool isDisabled(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [duration] normally, or [Duration.zero] when the user has
  /// requested reduced motion. Use for any non-essential motion so the
  /// animation completes instantly instead of being removed entirely.
  static Duration resolve(BuildContext context, Duration duration) =>
      isDisabled(context) ? Duration.zero : duration;
}

/// A small builder that exposes whether (non-essential) motion is currently
/// enabled, so callers can branch between an animated and a static widget tree.
///
/// ```dart
/// MotionBuilder(
///   builder: (context, motionEnabled) =>
///       motionEnabled ? const _AnimatedHeader() : const _StaticHeader(),
/// );
/// ```
class MotionBuilder extends StatelessWidget {
  const MotionBuilder({required this.builder, super.key});

  /// Receives `true` when non-essential motion should play.
  final Widget Function(BuildContext context, bool motionEnabled) builder;

  @override
  Widget build(BuildContext context) =>
      builder(context, !KMotion.isDisabled(context));
}
