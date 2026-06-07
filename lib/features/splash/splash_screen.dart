import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/brand_logo.dart';

/// Cinematic 3D preloader.
///
/// Sequence (≈3.2s):
///  1) Logo flies in from depth with perspective Y-rotation + scale.
///  2) Amber glow pulses; subtle continuous float/tilt (parallax 3D feel).
///  3) Wordmark "KEYFRAMES" reveals letter-spacing + fades in.
///  4) Tagline + loading shimmer bar fill, then [onFinish] fires.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro; // one-shot entrance
  late final AnimationController _idle; // looping float/tilt
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotateY;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _wordmark;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _logoOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _logoRotateY = Tween<double>(begin: math.pi, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.05, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _wordmark = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );
    _progress = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
    );

    _intro.forward().whenComplete(() {
      Future.delayed(const Duration(milliseconds: 250), widget.onFinish);
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedAuroraBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // ---- 3D logo ----
              AnimatedBuilder(
                animation: Listenable.merge([_intro, _idle]),
                builder: (context, _) {
                  final floatT = math.sin(_idle.value * math.pi * 2);
                  final idleTilt = floatT * 0.18; // gentle yaw
                  final idleFloat = floatT * 6; // vertical bob
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, idleFloat),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0014) // perspective
                          ..rotateX(0.12 * floatT)
                          ..rotateY(_logoRotateY.value + idleTilt)
                          ..scale(_logoScale.value),
                        child: _LogoStack(glowT: (floatT + 1) / 2),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 34),
              // ---- Wordmark ----
              AnimatedBuilder(
                animation: _wordmark,
                builder: (context, _) {
                  return Opacity(
                    opacity: _wordmark.value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - _wordmark.value)),
                      child: Text(
                        'KEYFRAMES',
                        style: AppTypography.wordmark(
                          size: 28,
                          color: AppColors.white,
                        ).copyWith(
                          letterSpacing: 4 + 6 * _wordmark.value,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _wordmark,
                builder: (context, _) => Opacity(
                  opacity: _wordmark.value,
                  child: Text(
                    'Design · Develop · Deliver',
                    style: TextStyle(
                      color: AppColors.amberBright,
                      fontSize: 12.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 3),
              // ---- Progress bar ----
              AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => _ProgressBar(value: _progress.value),
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => Opacity(
                  opacity: _progress.value,
                  child: const Text(
                    'Crafting your experience…',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

/// Layered logo to emphasise depth: a soft dropped "shadow" copy behind the
/// crisp brand mark, sitting inside an amber glow ring.
class _LogoStack extends StatelessWidget {
  const _LogoStack({required this.glowT});
  final double glowT;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow halo
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber.withOpacity(0.25 + 0.20 * glowT),
                  blurRadius: 60 + 20 * glowT,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: AppColors.navy500.withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: -6,
                ),
              ],
            ),
          ),
          // Depth shadow copy (pushed back)
          Transform.translate(
            offset: const Offset(8, 10),
            child: Opacity(
              opacity: 0.35,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.black54,
                  BlendMode.srcATop,
                ),
                child: const BrandLogo(size: 132, depth: 1.4),
              ),
            ),
          ),
          // Crisp front mark
          const BrandLogo(size: 132, depth: 1.2),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Container(height: 5, color: Colors.white.withOpacity(0.12)),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                height: 5,
                decoration: const BoxDecoration(
                  gradient: AppColors.amberGradient,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
