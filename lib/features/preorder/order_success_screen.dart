import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/animations/animations.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/data/models/order.dart';

/// The post-submission order-success screen (Requirements 8.6–8.8).
///
/// Celebrates a successfully-created [Order] with a lightweight confetti burst
/// and an animated success badge, then offers the two primary follow-up
/// actions from the design: **Track Order** (opens the order-detail/tracking
/// screen for the new order) and **Chat with us** (opens the chat portal).
///
/// The celebration honors the platform reduce-motion setting via [KMotion]:
/// when animations are disabled it renders the final, static state instead of
/// playing the confetti/badge animations.
class OrderSuccessScreen extends StatefulWidget {
  /// Creates the success screen for the just-created [order].
  const OrderSuccessScreen({required this.order, super.key});

  /// The order that was successfully created (passed via GoRouter `extra`).
  final Order order;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _badgeController;
  late final AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start (or skip) the celebration based on the reduce-motion setting.
    if (!KMotion.isDisabled(context)) {
      _badgeController.forward();
      _confettiController.forward();
    } else {
      _badgeController.value = 1.0;
      _confettiController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _badgeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Order order = widget.order;
    return Scaffold(
      backgroundColor: KColors.navy900,
      body: Stack(
        children: <Widget>[
          // Confetti behind the content.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (BuildContext context, Widget? _) {
                  return CustomPaint(
                    painter: _ConfettiPainter(progress: _confettiController.value),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(KSpace.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(child: _SuccessBadge(controller: _badgeController)),
                  const SizedBox(height: KSpace.xl),
                  Text(
                    'Pre-order placed!',
                    textAlign: TextAlign.center,
                    style: KTextStyles.headingLg.copyWith(color: KColors.white),
                  ),
                  const SizedBox(height: KSpace.sm),
                  Text(
                    'We received your pre-order for "${order.serviceTitle}". '
                    'Our team will review it and reach out shortly.',
                    textAlign: TextAlign.center,
                    style: KTextStyles.bodyMd.copyWith(color: KColors.amber300),
                  ),
                  const SizedBox(height: KSpace.xxl),
                  KPrimaryButton(
                    label: 'Track Order',
                    icon: Icons.local_shipping_outlined,
                    expanded: true,
                    onPressed: () =>
                        context.go(KRoutes.orderDetailPath(order.id)),
                  ),
                  const SizedBox(height: KSpace.md),
                  OutlinedButton.icon(
                    onPressed: () => context.go(KRoutes.chat),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Chat with us'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(KSpace.minTouchTarget),
                      foregroundColor: KColors.white,
                      side: const BorderSide(color: KColors.navy400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KSpace.rPill),
                      ),
                    ),
                  ),
                  const SizedBox(height: KSpace.lg),
                  TextButton(
                    onPressed: () => context.go(KRoutes.home),
                    child: Text(
                      'Back to home',
                      style:
                          KTextStyles.label.copyWith(color: KColors.amber400),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An amber success badge that springs into view with a scale animation.
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final Animation<double> scale = CurvedAnimation(
      parent: controller,
      curve: Curves.elasticOut,
    );
    return ScaleTransition(
      scale: scale,
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: <Color>[KColors.amber400, KColors.amber500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 56,
          color: KColors.white,
        ),
      ),
    );
  }
}

/// A deterministic, lightweight confetti painter.
///
/// Renders a fixed set of pseudo-random particles that fall and fade as
/// [progress] advances from 0 to 1. Uses a fixed seed so the burst looks the
/// same on every rebuild within a frame and never depends on external packages.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  static const int _count = 60;
  static const List<Color> _palette = <Color>[
    KColors.amber500,
    KColors.amber400,
    KColors.amber300,
    KColors.white,
    KColors.navy400,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    final math.Random random = math.Random(7);
    final Paint paint = Paint();

    for (int i = 0; i < _count; i++) {
      final double startX = random.nextDouble() * size.width;
      final double drift = (random.nextDouble() - 0.5) * 80;
      final double delay = random.nextDouble() * 0.3;
      final double t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) {
        continue;
      }

      final double y = -20 + t * (size.height + 40);
      final double x = startX + drift * t;
      final double opacity = (1.0 - t).clamp(0.0, 1.0);
      final double rotation = t * (random.nextDouble() * 6 + 2);
      final double side = 5 + random.nextDouble() * 5;

      paint.color =
          _palette[i % _palette.length].withOpacity(0.2 + 0.8 * opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: side, height: side * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
