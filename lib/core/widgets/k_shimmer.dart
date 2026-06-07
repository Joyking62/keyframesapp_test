import 'package:flutter/material.dart';

import '../theme/k_colors.dart';
import '../theme/k_space.dart';

/// Animated shimmer skeleton placeholder for loading lists and cards.
///
/// Sweeps a soft gradient horizontally across a neutral block to signal
/// loading state for the catalog and dashboards (Requirement 17.3 loading
/// rendering; Requirement 14.3 motion). Use [KShimmer.box] to render a single
/// rounded placeholder block, or the default constructor to wrap an arbitrary
/// [child] whose painted pixels are masked by the moving gradient.
class KShimmer extends StatefulWidget {
  /// Wraps [child] with a shimmer sweep mask.
  const KShimmer({
    this.child,
    this.height,
    this.width,
    this.borderRadius,
    super.key,
  });

  /// Convenience constructor for a single rounded placeholder block.
  const KShimmer.box({
    double height = 16,
    double? width,
    BorderRadius? borderRadius,
    Key? key,
  }) : this(
          height: height,
          width: width,
          borderRadius: borderRadius,
          key: key,
        );

  /// Optional content to mask. When null, a solid placeholder box is shown.
  final Widget? child;

  /// Placeholder block height (used when [child] is null).
  final double? height;

  /// Placeholder block width (used when [child] is null).
  final double? width;

  /// Corner radius of the placeholder block; defaults to [KSpace.rMd].
  final BorderRadius? borderRadius;

  @override
  State<KShimmer> createState() => _KShimmerState();
}

class _KShimmerState extends State<KShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget base = widget.child ??
        Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: KColors.slate200,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(KSpace.rMd),
          ),
        );

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            // Sweep position travels from off-left to off-right.
            final double t = _controller.value;
            final double start = -1.0 + 2.0 * t;
            return LinearGradient(
              begin: Alignment(start - 0.6, 0),
              end: Alignment(start + 0.6, 0),
              colors: const <Color>[
                KColors.slate200,
                KColors.offWhite,
                KColors.slate200,
              ],
              stops: const <double>[0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: base,
    );
  }
}
