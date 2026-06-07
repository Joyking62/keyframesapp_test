import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Animated aurora-style background of slowly drifting blurred blobs over a
/// navy gradient. Used on the splash, auth and admin-dashboard surfaces.
class AnimatedAuroraBackground extends StatefulWidget {
  const AnimatedAuroraBackground({
    super.key,
    this.child,
    this.showGrid = true,
  });

  final Widget? child;
  final bool showGrid;

  @override
  State<AnimatedAuroraBackground> createState() =>
      _AnimatedAuroraBackgroundState();
}

class _AnimatedAuroraBackgroundState extends State<AnimatedAuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: CustomPaint(
            painter: _AuroraPainter(_c.value, widget.showGrid),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.grid);
  final double t;
  final bool grid;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void blob(Offset c, double r, Color color) {
      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
      canvas.drawCircle(c, r, paint);
    }

    final a = t * 2 * math.pi;
    blob(
      Offset(w * (0.2 + 0.08 * math.sin(a)), h * (0.22 + 0.05 * math.cos(a))),
      w * 0.42,
      AppColors.amber.withOpacity(0.20),
    );
    blob(
      Offset(w * (0.85 + 0.06 * math.cos(a)), h * (0.7 + 0.05 * math.sin(a))),
      w * 0.5,
      AppColors.navy300.withOpacity(0.35),
    );
    blob(
      Offset(w * (0.6 + 0.05 * math.sin(a * 1.3)), h * (0.95)),
      w * 0.4,
      AppColors.amberDeep.withOpacity(0.12),
    );

    if (grid) {
      final line = Paint()
        ..color = AppColors.white.withOpacity(0.04)
        ..strokeWidth = 1;
      const gap = 38.0;
      for (double x = 0; x < w; x += gap) {
        canvas.drawLine(Offset(x, 0), Offset(x, h), line);
      }
      for (double y = 0; y < h; y += gap) {
        canvas.drawLine(Offset(0, y), Offset(w, y), line);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.t != t;
}
