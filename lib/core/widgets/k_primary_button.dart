import 'package:flutter/material.dart';

import '../theme/k_colors.dart';
import '../theme/k_space.dart';
import '../theme/k_text_styles.dart';

/// Gradient primary button with a press-scale micro-interaction and a
/// morphing loading state.
///
/// The button paints the brand amber gradient ([KColors.amber400] ->
/// [KColors.amber500]) and animates a subtle scale-down while pressed
/// (Requirement 14.3 micro-interaction family). When [loading] is `true`, the
/// label/icon content cross-fades to a compact spinner via [AnimatedSwitcher]
/// and presses are ignored.
///
/// Design references:
/// - Requirement 13.5 (shared design-system widgets, 48px touch target).
/// - Requirement 14.3 (tasteful press/loading micro-interactions).
class KPrimaryButton extends StatefulWidget {
  /// Creates a gradient primary button.
  const KPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expanded = false,
    super.key,
  });

  /// The text rendered on the button when not [loading].
  final String label;

  /// Invoked on tap. When `null` (or while [loading]) the button is disabled.
  final VoidCallback? onPressed;

  /// When `true`, content morphs to a spinner and presses are suppressed.
  final bool loading;

  /// Optional leading icon shown before the [label].
  final IconData? icon;

  /// When `true`, the button stretches to fill the available width.
  final bool expanded;

  @override
  State<KPrimaryButton> createState() => _KPrimaryButtonState();
}

class _KPrimaryButtonState extends State<KPrimaryButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (!_enabled) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: widget.loading
          ? const SizedBox(
              key: ValueKey<String>('loading'),
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(KColors.white),
              ),
            )
          : Row(
              key: const ValueKey<String>('label'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (widget.icon != null) ...<Widget>[
                  Icon(widget.icon, size: 18, color: KColors.white),
                  const SizedBox(width: KSpace.sm),
                ],
                Text(
                  widget.label,
                  style: KTextStyles.label.copyWith(
                    color: KColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );

    final Widget button = AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _enabled ? 1.0 : 0.6,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: KSpace.minTouchTarget,
            minWidth: KSpace.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.xl,
            vertical: KSpace.md,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[KColors.amber400, KColors.amber500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(KSpace.rPill),
            boxShadow: _enabled ? KSpace.cardShadow : const <BoxShadow>[],
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _enabled ? widget.onPressed : null,
        child: widget.expanded
            ? Row(children: <Widget>[Expanded(child: button)])
            : button,
      ),
    );
  }
}
