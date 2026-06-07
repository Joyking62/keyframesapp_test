import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Animates a numeric value upward from 0 to [value] using a
/// [TweenAnimationBuilder]. Intended for dashboard KPI cards
/// (e.g. "new pre-orders", "active chats", "completed this month").
///
/// When the value changes, the count-up re-runs from the previously displayed
/// value to the new target. When the platform reduce-motion setting is enabled
/// the final value is shown instantly.
///
/// Requirements: 14.2 (animate KPI values upward from 0).
class CountUpText extends StatelessWidget {
  const CountUpText({
    required this.value,
    this.duration = KMotion.slow,
    this.curve = KMotion.enter,
    this.formatter,
    this.style,
    this.textAlign,
    super.key,
  });

  /// The target value to count up to.
  final double value;

  /// How long the count-up takes (zeroed when reduce-motion is enabled).
  final Duration duration;

  /// Easing applied to the count-up.
  final Curve curve;

  /// Optional formatter for the intermediate values. Defaults to rounding to
  /// the nearest whole number.
  final String Function(double value)? formatter;

  /// Text style for the rendered number.
  final TextStyle? style;

  /// Optional text alignment.
  final TextAlign? textAlign;

  /// Convenience constructor for an integer KPI that renders whole numbers.
  factory CountUpText.integer(
    int value, {
    Duration duration = KMotion.slow,
    Curve curve = KMotion.enter,
    TextStyle? style,
    TextAlign? textAlign,
    String Function(int value)? formatter,
    Key? key,
  }) {
    return CountUpText(
      key: key,
      value: value.toDouble(),
      duration: duration,
      curve: curve,
      style: style,
      textAlign: textAlign,
      formatter: (double v) =>
          formatter != null ? formatter(v.round()) : v.round().toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value),
      duration: KMotion.resolve(context, duration),
      curve: curve,
      builder: (BuildContext context, double current, Widget? _) {
        final String label =
            formatter?.call(current) ?? current.round().toString();
        return Text(label, style: style, textAlign: textAlign);
      },
    );
  }
}
