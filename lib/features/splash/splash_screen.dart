import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/data/models/bootstrap_result.dart';
import 'package:keyframes_app/features/splash/bootstrap.dart';
import 'package:keyframes_app/features/splash/splash_animator.dart';
import 'package:keyframes_app/features/splash/splash_navigation.dart';

/// The 3D-depth animated splash / preloader (Requirement 2).
///
/// Composes the layered visual stack described in the design's "3D-Depth
/// Animated Splash / Preloader" section:
///
/// 1. [_RadialNavyBackground] — a navy900 -> navy600 radial gradient backdrop.
/// 2. [_ParallaxGlowLayer] — soft amber blur orbs that drift with the idle
///    sway for a parallax depth cue.
/// 3. The 3D logo — `Image.asset('assets/images/keyframes_logo.png')` wrapped
///    in a [Transform] driven by [buildDepthTransform] (perspective scale +
///    translateZ entrance and X/Y tilt sway), with an amber pulsing-nodes
///    [CustomPaint] overlay.
/// 4. The brand wordmark "KEYFRAMES" ([KTextStyles.displayLg], white) that
///    slides up and fades in via the animator's `wordmark` animation.
/// 5. [_ShimmerProgressBar] — a bottom amber shimmer indicating bootstrap
///    progress.
///
/// ## Navigation contract (Requirements 2.5, 2.6 — "splash determinism")
///
/// The splash leaves **exactly once**, and only after BOTH of the following
/// have happened:
///
/// * the entrance animation has completed, AND
/// * [bootstrapProvider] has resolved to a [BootstrapResult].
///
/// A single `_navigated` guard makes the transition idempotent regardless of
/// which event lands last (or whether the widget rebuilds in between). Both
/// triggers funnel through [_tryRedirect], which only proceeds when every
/// precondition is met; the actual navigation happens in [redirectAfterSplash]
/// via `context.go(resolveInitialRoute(result))`.
///
/// If bootstrap resolves to an **error**, the splash stays put (it never
/// navigates) and surfaces a small, non-blocking error indication
/// (Requirement 17.4) while the underlying provider can be retried.
class SplashScreen extends ConsumerStatefulWidget {
  /// Creates the animated splash screen.
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    // Two controllers (entrance + sway) live inside [SplashAnimator], so the
    // State must vend multiple tickers.
    with TickerProviderStateMixin {
  /// Owns the entrance + idle-sway controllers and derived animations.
  late final SplashAnimator _animator;

  /// Slides the wordmark up as it fades in (paired with `_animator.wordmark`).
  late final Animation<Offset> _wordmarkSlide;

  /// Pure state machine that funnels the two navigation triggers (entrance
  /// completion and bootstrap resolution) into a single, idempotent
  /// "navigate exactly once" decision (Requirements 2.5, 2.6). Keeping the
  /// decision here — rather than in loose bools — means the widget and the
  /// property-tested [SplashNavigationGate] can never diverge.
  final SplashNavigationGate _gate = SplashNavigationGate();

  @override
  void initState() {
    super.initState();
    _animator = SplashAnimator(vsync: this);
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(_animator.wordmark);

    // Mark entrance completion and attempt navigation (bootstrap may already
    // be resolved by the time the animation lands).
    _animator.entrance.addStatusListener(_onEntranceStatus);
    _animator.start();
  }

  @override
  void dispose() {
    _animator.entrance.removeStatusListener(_onEntranceStatus);
    _animator.dispose();
    super.dispose();
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_gate.entranceComplete) {
      _gate.onEntranceComplete();
      _tryRedirect();
    }
  }

  /// Funnels both navigation triggers (entrance-complete and bootstrap-resolve)
  /// through a single guarded check so the splash leaves exactly once and only
  /// after both preconditions hold (Requirements 2.5, 2.6).
  void _tryRedirect() {
    if (_gate.navigations > 0 || !_gate.entranceComplete) {
      return;
    }
    final BootstrapResult? result = ref.read(bootstrapProvider).valueOrNull;
    if (result == null) {
      // Bootstrap not resolved yet (still loading) or resolved to an error —
      // either way we stay on the splash.
      return;
    }
    redirectAfterSplash(result);
  }

  /// Performs the one-and-only navigation to the resolved initial route.
  ///
  /// Mirrors the design's `redirectAfterSplash(BootstrapResult r)`: it maps the
  /// bootstrap result to a route via the pure [resolveInitialRoute] and issues
  /// a single `context.go`. Both the early-return guard and the
  /// [SplashNavigationGate] make repeated calls no-ops.
  void redirectAfterSplash(BootstrapResult result) {
    if (_gate.navigations > 0) {
      return;
    }
    // Record the bootstrap-resolve trigger; the gate increments its navigation
    // count exactly once now that both preconditions hold.
    _gate.onBootstrapResolved();
    if (_gate.navigations == 1 && mounted) {
      context.go(resolveInitialRoute(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    // React to bootstrap resolving *after* the entrance completes. `listen`
    // (not `watch`) keeps navigation a one-shot side effect.
    ref.listen<AsyncValue<BootstrapResult>>(bootstrapProvider, (_, next) {
      if (next.hasValue) {
        _tryRedirect();
      }
    });

    final bool hasError = ref.watch(bootstrapProvider).hasError;

    return Scaffold(
      backgroundColor: KColors.navy900,
      body: Stack(
        children: <Widget>[
          // 1. Navy radial gradient backdrop.
          const Positioned.fill(child: _RadialNavyBackground()),

          // 2. Parallax amber glow orbs driven by the idle sway.
          Positioned.fill(
            child: _ParallaxGlowLayer(sway: _animator.sway),
          ),

          // 3. The 3D-transformed logo with pulsing amber nodes.
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                _animator.entrance,
                _animator.sway,
              ]),
              builder: (BuildContext context, Widget? child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: buildDepthTransform(
                    depth: _animator.depth.value,
                    tiltX: _animator.tiltX.value,
                    tiltY: _animator.tiltY.value,
                  ),
                  child: child,
                );
              },
              child: _LogoWithPulsingNodes(
                reveal: _animator.reveal,
                pulse: _animator.sway,
              ),
            ),
          ),

          // 4. Brand wordmark — slides up + fades in near the end of entrance.
          Positioned(
            left: 0,
            right: 0,
            bottom: 150,
            child: FadeTransition(
              opacity: _animator.wordmark,
              child: SlideTransition(
                position: _wordmarkSlide,
                child: Text(
                  'KEYFRAMES',
                  textAlign: TextAlign.center,
                  style: KTextStyles.displayLg.copyWith(
                    color: KColors.white,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),
          ),

          // 5. Bottom shimmer progress + (optional) error indication.
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _ShimmerProgressBar(),
                if (hasError) ...<Widget>[
                  const SizedBox(height: KSpace.md),
                  Text(
                    'Something went wrong. Retrying…',
                    textAlign: TextAlign.center,
                    style: KTextStyles.caption.copyWith(
                      color: KColors.amber300,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The deep-navy radial gradient backdrop (navy900 -> navy600).
///
/// The lighter navy is focused slightly above center so the logo appears to
/// emerge from a soft pool of light in otherwise-deep navy space.
class _RadialNavyBackground extends StatelessWidget {
  const _RadialNavyBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.1,
          colors: <Color>[KColors.navy600, KColors.navy900],
          stops: <double>[0.0, 1.0],
        ),
      ),
    );
  }
}

/// Soft amber glow orbs that drift with the idle [sway] for a parallax cue.
///
/// Two blurred amber radial orbs translate in opposite directions as the sway
/// controller oscillates, giving the static logo a sense of floating depth.
class _ParallaxGlowLayer extends StatelessWidget {
  const _ParallaxGlowLayer({required this.sway});

  /// The looping idle-sway controller (value 0..1).
  final Animation<double> sway;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sway,
      builder: (BuildContext context, _) {
        // Map the 0..1 sway value to a small symmetric drift.
        final double drift = (sway.value - 0.5) * 2; // -1..1
        return Stack(
          children: <Widget>[
            Align(
              alignment: Alignment(-0.6 + drift * 0.1, -0.5 + drift * 0.08),
              child: const _GlowOrb(
                diameter: 240,
                color: KColors.amber500,
                opacity: 0.18,
              ),
            ),
            Align(
              alignment: Alignment(0.7 - drift * 0.1, 0.4 - drift * 0.08),
              child: const _GlowOrb(
                diameter: 300,
                color: KColors.amber400,
                opacity: 0.12,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single soft, blurred amber orb used by [_ParallaxGlowLayer].
class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.diameter,
    required this.color,
    required this.opacity,
  });

  final double diameter;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withOpacity(opacity),
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }
}

/// The Keyframes logo with an amber "circuit node" pulse overlay.
///
/// The logo image fades in via [reveal]; the [pulse] controller staggers a set
/// of amber nodes (and the lines connecting them) so they shimmer along the
/// logo like a powering-up circuit.
class _LogoWithPulsingNodes extends StatelessWidget {
  const _LogoWithPulsingNodes({required this.reveal, required this.pulse});

  /// Logo opacity reveal (0 -> 1).
  final Animation<double> reveal;

  /// Drives the staggered amber node pulse (looping 0..1).
  final Animation<double> pulse;

  static const double _size = 168;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: reveal,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Image.asset(
              'assets/images/keyframes_logo.png',
              width: _size,
              height: _size,
              fit: BoxFit.contain,
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: pulse,
                builder: (BuildContext context, _) {
                  return CustomPaint(
                    painter: _PulsingNodesPainter(progress: pulse.value),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints amber circuit nodes (with connecting lines) that pulse in a staggered
/// loop driven by [progress] (0..1).
class _PulsingNodesPainter extends CustomPainter {
  _PulsingNodesPainter({required this.progress});

  /// Loop phase in `[0, 1)` (typically the idle-sway controller value).
  final double progress;

  /// Node positions expressed as fractions of the paint box.
  static const List<Offset> _nodes = <Offset>[
    Offset(0.50, 0.10),
    Offset(0.84, 0.34),
    Offset(0.80, 0.74),
    Offset(0.50, 0.92),
    Offset(0.20, 0.74),
    Offset(0.16, 0.34),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final List<Offset> points = <Offset>[
      for (final Offset n in _nodes) Offset(n.dx * size.width, n.dy * size.height),
    ];

    // Faint connecting lines forming a ring (the "circuit").
    final Paint linePaint = Paint()
      ..color = KColors.amber500.withOpacity(0.16)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < points.length; i++) {
      canvas.drawLine(points[i], points[(i + 1) % points.length], linePaint);
    }

    // Staggered pulsing nodes.
    for (int i = 0; i < points.length; i++) {
      final double phase = (progress + i / points.length) % 1.0;
      final double t = (math.sin(phase * 2 * math.pi) + 1) / 2; // 0..1
      final double radius = 2.0 + 2.5 * t;

      final Paint glowPaint = Paint()
        ..color = KColors.amber400.withOpacity(0.25 * t)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(points[i], radius + 3, glowPaint);

      final Paint dotPaint = Paint()
        ..color = KColors.amber500.withOpacity(0.4 + 0.6 * t);
      canvas.drawCircle(points[i], radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_PulsingNodesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// A bottom progress bar with an amber gradient that sweeps left-to-right,
/// indicating bootstrap progress while the splash is active.
class _ShimmerProgressBar extends StatefulWidget {
  const _ShimmerProgressBar();

  @override
  State<_ShimmerProgressBar> createState() => _ShimmerProgressBarState();
}

class _ShimmerProgressBarState extends State<_ShimmerProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 4,
      decoration: BoxDecoration(
        color: KColors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(KSpace.rPill),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          final double start = -1.0 + 2.0 * _controller.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(start - 0.6, 0),
                end: Alignment(start + 0.6, 0),
                colors: <Color>[
                  KColors.amber500.withOpacity(0.12),
                  KColors.amber400,
                  KColors.amber500.withOpacity(0.12),
                ],
                stops: const <double>[0.25, 0.5, 0.75],
              ),
            ),
          );
        },
      ),
    );
  }
}
