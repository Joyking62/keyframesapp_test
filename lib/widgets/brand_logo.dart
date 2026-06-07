import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Keyframes brand mark.
///
/// Renders a hand-painted circuit-style "K" with two diamond nodes so the app
/// always has a crisp, resolution-independent logo with a subtle 3D offset
/// between the amber (back) and navy (front) layers.
///
/// To use your real PNG instead:
///   1. Add `assets/images/keyframes_logo.png`.
///   2. Set `useImageAsset: true`.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 96,
    this.useImageAsset = false,
    this.depth = 1.0,
    this.glow = false,
  });

  final double size;

  /// When true, shows assets/images/keyframes_logo.png instead of the painter.
  final bool useImageAsset;

  /// Multiplier for the 3D layer offset (0 = flat, 1 = default depth).
  final double depth;

  /// Adds an amber glow behind the mark (used on dark backgrounds).
  final bool glow;

  @override
  Widget build(BuildContext context) {
    Widget mark;
    if (useImageAsset) {
      mark = Image.asset(
        'assets/images/keyframes_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    } else {
      mark = CustomPaint(
        size: Size.square(size),
        painter: _KeyframesLogoPainter(depth: depth),
      );
    }

    if (!glow) return mark;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withOpacity(0.35),
            blurRadius: size * 0.5,
            spreadRadius: size * 0.05,
          ),
        ],
      ),
      child: mark,
    );
  }
}

class _KeyframesLogoPainter extends CustomPainter {
  _KeyframesLogoPainter({required this.depth});

  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    double sx(double v) => v / 512 * s;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sx(22)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Connector lines.
    stroke.color = AppColors.navy600;
    final topLine = Path()
      ..moveTo(sx(120), sx(120))
      ..lineTo(sx(230), sx(120))
      ..lineTo(sx(230), sx(200));
    canvas.drawPath(topLine, stroke);

    stroke.color = AppColors.amber;
    canvas.drawLine(Offset(sx(300), sx(330)), Offset(sx(392), sx(392)), stroke);

    final off = sx(10) * depth;

    // Amber K (back layer).
    final amberK = Path()
      ..moveTo(sx(170), sx(150))
      ..lineTo(sx(170), sx(362))
      ..lineTo(sx(210), sx(362))
      ..lineTo(sx(210), sx(285))
      ..lineTo(sx(300), sx(362))
      ..lineTo(sx(352), sx(362))
      ..lineTo(sx(250), sx(256))
      ..lineTo(sx(348), sx(150))
      ..lineTo(sx(300), sx(150))
      ..lineTo(sx(210), sx(235))
      ..lineTo(sx(210), sx(150))
      ..close();
    canvas.drawPath(
      amberK.shift(Offset(off, off)),
      Paint()..color = AppColors.amber,
    );

    // Navy K (front layer).
    final navyK = Path()
      ..moveTo(sx(200), sx(130))
      ..lineTo(sx(200), sx(300))
      ..lineTo(sx(320), sx(180))
      ..lineTo(sx(372), sx(180))
      ..lineTo(sx(268), sx(286))
      ..lineTo(sx(378), sx(392))
      ..lineTo(sx(322), sx(392))
      ..lineTo(sx(226), sx(300))
      ..lineTo(sx(226), sx(392))
      ..lineTo(sx(186), sx(392))
      ..lineTo(sx(186), sx(130))
      ..close();
    canvas.drawPath(navyK, Paint()..color = AppColors.navy600);

    // Diamond nodes.
    _diamond(canvas, Offset(sx(94), sx(122)), sx(50), AppColors.amber,
        AppColors.navy);
    _diamond(canvas, Offset(sx(418), sx(390)), sx(50), AppColors.navy600,
        AppColors.amber);
  }

  void _diamond(
      Canvas canvas, Offset center, double r, Color outer, Color inner) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.785398); // 45deg
    final rrectOuter = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: r, height: r),
      Radius.circular(r * 0.2),
    );
    canvas.drawRRect(rrectOuter, Paint()..color = outer);
    final rrectInner = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: r * 0.5, height: r * 0.5),
      Radius.circular(r * 0.12),
    );
    canvas.drawRRect(rrectInner, Paint()..color = inner);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KeyframesLogoPainter oldDelegate) =>
      oldDelegate.depth != depth;
}
