import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Applies a staggered **fade-in + vertical-slide** entrance to a single list
/// or grid child, offsetting the start of the animation by the child's [index].
///
/// The stagger delay is capped via [maxStaggerSlots] so that long lists do not
/// accumulate large delays (which would feel sluggish and risk jank on the
/// last items). Children beyond the cap all start together at the maximum
/// delay.
///
/// When the platform reduce-motion setting is enabled, the child is shown
/// immediately at its final position with no delay or motion.
///
/// Typically used by mapping a list of children:
///
/// ```dart
/// GridView(
///   children: StaggeredEntrance.wrap(serviceCards),
/// );
/// ```
///
/// Requirements: 14.4, 6.5 (staggered catalog card entrance).
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 55),
    this.duration = KMotion.medium,
    this.curve = KMotion.enter,
    this.slideOffset = 24.0,
    this.maxStaggerSlots = 12,
    super.key,
  });

  /// Zero-based position of this child in its list/grid.
  final int index;

  /// The content to reveal.
  final Widget child;

  /// Per-index delay applied before this child starts animating.
  final Duration baseDelay;

  /// How long the fade/slide itself takes.
  final Duration duration;

  /// Easing applied to both the fade and the slide.
  final Curve curve;

  /// Initial downward offset (logical pixels) the child slides up from.
  final double slideOffset;

  /// Maximum number of staggered slots; the effective delay uses
  /// `min(index, maxStaggerSlots)` to cap total delay on long lists.
  final int maxStaggerSlots;

  /// Convenience helper that wraps each widget in [children] with a
  /// [StaggeredEntrance] using its position as the [index].
  static List<Widget> wrap(
    List<Widget> children, {
    Duration baseDelay = const Duration(milliseconds: 55),
    Duration duration = KMotion.medium,
    Curve curve = KMotion.enter,
    double slideOffset = 24.0,
    int maxStaggerSlots = 12,
  }) {
    return <Widget>[
      for (int i = 0; i < children.length; i++)
        StaggeredEntrance(
          index: i,
          baseDelay: baseDelay,
          duration: duration,
          curve: curve,
          slideOffset: slideOffset,
          maxStaggerSlots: maxStaggerSlots,
          child: children[i],
        ),
    ];
  }

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;

    if (KMotion.isDisabled(context)) {
      // Reduced motion: reveal instantly with no slide or delay.
      _controller.value = 1.0;
      return;
    }

    final int slots = widget.index.clamp(0, widget.maxStaggerSlots);
    final Duration delay = widget.baseDelay * slots;
    Future<void>.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      builder: (BuildContext context, Widget? child) {
        final double t = _curved.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0.0, widget.slideOffset * (1.0 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
