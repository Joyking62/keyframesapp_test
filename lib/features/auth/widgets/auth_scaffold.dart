import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';

/// Shared chrome for the authentication screens (login & register).
///
/// Composes the design's Auth section layout (Requirement 13.6 logo usage):
/// a **navy gradient header** carrying the Keyframes logo, and a **white,
/// rounded form sheet** that animates upward from the bottom on first build
/// (the "slide-up reveal").
///
/// The supplied [shakeController] drives a horizontal shake applied to the
/// form sheet; screens call `forward(from: 0)` on it to play the error shake on
/// an invalid submit (Requirement 4.5) without this widget needing to know why.
class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.shakeController,
    super.key,
  });

  /// The heading shown at the top of the form sheet (e.g. "Welcome back").
  final String title;

  /// The supporting line shown beneath [title].
  final String subtitle;

  /// The form content (fields, buttons, links) rendered inside the sheet.
  final Widget form;

  /// Controller driving the error-shake animation of the form sheet.
  final AnimationController shakeController;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  late final Animation<Offset> _slideUp = Tween<Offset>(
    begin: const Offset(0, 0.35),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _revealController,
    curve: const Interval(0.1, 1.0, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _revealController.forward();
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.navy900,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: <Widget>[
          // Navy gradient header with the Keyframes logo.
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[KColors.navy900, KColors.navy600],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpace.xl),
                    child: Image.asset(
                      'assets/images/keyframes_logo.png',
                      height: 96,
                      // Graceful fallback if the asset fails to decode so the
                      // header never renders as a broken-image box.
                      errorBuilder: (context, error, stackTrace) => Text(
                        'KEYFRAMES',
                        style: KTextStyles.headingLg.copyWith(
                          color: KColors.white,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // White rounded form sheet rising from the bottom.
          Expanded(
            flex: 3,
            child: SlideTransition(
              position: _slideUp,
              child: FadeTransition(
                opacity: _fadeIn,
                child: _FormSheet(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  shakeController: widget.shakeController,
                  form: widget.form,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The white, top-rounded sheet that hosts the auth form, with the shake
/// transform applied around its scrollable content.
class _FormSheet extends StatelessWidget {
  const _FormSheet({
    required this.title,
    required this.subtitle,
    required this.shakeController,
    required this.form,
  });

  final String title;
  final String subtitle;
  final AnimationController shakeController;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: KColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpace.rXl)),
        boxShadow: KSpace.modalShadow,
      ),
      child: AnimatedBuilder(
        animation: shakeController,
        builder: (BuildContext context, Widget? child) {
          // Damped horizontal oscillation: a few cycles whose amplitude
          // decays to zero as the animation completes.
          final double t = shakeController.value;
          final double dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              KSpace.xl,
              KSpace.xl,
              KSpace.xl,
              KSpace.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: KTextStyles.headingLg),
                const SizedBox(height: KSpace.xs),
                Text(
                  subtitle,
                  style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
                ),
                const SizedBox(height: KSpace.xl),
                form,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
