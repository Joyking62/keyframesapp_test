import 'package:flutter/material.dart';

/// Wraps [child] in a subtle 3D perspective tilt that responds to pointer
/// drag, satisfying the featured-carousel tilt interaction (Requirement 14.3).
///
/// The widget tracks the local pointer position over its bounds and maps it to
/// rotation about the X and Y axes, clamped to +/-[maxTilt] radians. A small
/// perspective entry on the [Matrix4] gives the rotation depth. On release the
/// tilt animates back to rest.
class KTilt3D extends StatefulWidget {
  /// Creates a 3D-tilt wrapper around [child].
  const KTilt3D({
    required this.child,
    this.maxTilt = 0.12,
    this.perspective = 0.0015,
    super.key,
  });

  /// The content to tilt.
  final Widget child;

  /// Maximum rotation about each axis, in radians (default ~6.9 degrees).
  final double maxTilt;

  /// Perspective factor applied to `Matrix4` entry (3, 2).
  final double perspective;

  @override
  State<KTilt3D> createState() => _KTilt3DState();
}

class _KTilt3DState extends State<KTilt3D> {
  // Normalized tilt in the range [-1, 1] about each axis.
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  bool _active = false;

  void _updateFromPosition(Offset localPosition, Size size) {
    if (size.width == 0 || size.height == 0) {
      return;
    }
    // Map position to [-1, 1] with center as the rest point.
    final double dx = (localPosition.dx / size.width) * 2 - 1;
    final double dy = (localPosition.dy / size.height) * 2 - 1;
    setState(() {
      _active = true;
      // Horizontal drag rotates about Y; vertical drag rotates about X.
      _tiltY = dx.clamp(-1.0, 1.0);
      _tiltX = -dy.clamp(-1.0, 1.0);
    });
  }

  void _reset() {
    setState(() {
      _active = false;
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        final Matrix4 transform = Matrix4.identity()
          ..setEntry(3, 2, widget.perspective)
          ..rotateX(_tiltX * widget.maxTilt)
          ..rotateY(_tiltY * widget.maxTilt);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (DragStartDetails d) =>
              _updateFromPosition(d.localPosition, size),
          onPanUpdate: (DragUpdateDetails d) =>
              _updateFromPosition(d.localPosition, size),
          onPanEnd: (_) => _reset(),
          onPanCancel: _reset,
          child: AnimatedContainer(
            duration: Duration(milliseconds: _active ? 60 : 320),
            curve: _active ? Curves.linear : Curves.easeOutBack,
            transform: transform,
            transformAlignment: Alignment.center,
            child: widget.child,
          ),
        );
      },
    );
  }
}
