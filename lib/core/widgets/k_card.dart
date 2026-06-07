import 'package:flutter/material.dart';

import '../theme/k_colors.dart';
import '../theme/k_space.dart';

/// Elevated, rounded surface used for service tiles and dashboard cards.
///
/// Renders a white surface with a large corner radius ([KSpace.rLg]) and the
/// soft navy [KSpace.cardShadow] from the design system (Requirement 13.3).
/// When [onTap] is provided the card exposes a press-scale feedback affordance
/// consistent with the app's micro-interaction language (Requirement 14.3).
class KCard extends StatefulWidget {
  /// Creates an elevated rounded card.
  const KCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(KSpace.lg),
    this.color = KColors.white,
    this.borderRadius,
    super.key,
  });

  /// The card's content.
  final Widget child;

  /// Optional tap handler. When non-null, the card animates on press.
  final VoidCallback? onTap;

  /// Inner padding applied around [child].
  final EdgeInsetsGeometry padding;

  /// Surface color; defaults to [KColors.white].
  final Color color;

  /// Optional override for the corner radius; defaults to [KSpace.rLg].
  final BorderRadius? borderRadius;

  @override
  State<KCard> createState() => _KCardState();
}

class _KCardState extends State<KCard> {
  bool _pressed = false;

  bool get _interactive => widget.onTap != null;

  void _setPressed(bool value) {
    if (!_interactive) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        widget.borderRadius ?? BorderRadius.circular(KSpace.rLg);

    final Widget card = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: radius,
          boxShadow: KSpace.cardShadow,
        ),
        child: widget.child,
      ),
    );

    if (!_interactive) {
      return card;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: card,
    );
  }
}
