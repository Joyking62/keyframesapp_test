import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/buttons.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide(this.icon, this.title, this.body);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = <_Slide>[
    _Slide(
      Icons.dashboard_customize_rounded,
      'One studio, every service',
      'Mobile & web apps, IoT builds, university projects, logos, posters and video editing — all in one place.',
    ),
    _Slide(
      Icons.bolt_rounded,
      'Pre-order in minutes',
      'Pick a package, share your brief and lock your slot. No long hiring — just fast, reliable delivery.',
    ),
    _Slide(
      Icons.forum_rounded,
      'Chat directly with us',
      'Track every order and message the Keyframes team in real time, from brief to final handover.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _slides.length - 1) {
      widget.onDone();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedAuroraBackground(
        showGrid: false,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: widget.onDone,
                    child: const Text('Skip',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final s = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (i == 0)
                            const BrandLogo(size: 120, glow: true)
                          else
                            Container(
                              width: 116,
                              height: 116,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.amberGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.amber.withOpacity(0.4),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                              child: Icon(s.icon,
                                  size: 52, color: AppColors.navy),
                            ),
                          const SizedBox(height: 44),
                          Text(
                            s.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(color: Colors.white, fontSize: 30),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            s.body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15.5,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
                child: Column(
                  children: [
                    SmoothPageIndicator(
                      controller: _controller,
                      count: _slides.length,
                      effect: const ExpandingDotsEffect(
                        activeDotColor: AppColors.amber,
                        dotColor: Colors.white24,
                        dotHeight: 8,
                        dotWidth: 8,
                        expansionFactor: 3.2,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GradientButton(
                      label: _index == _slides.length - 1
                          ? 'Get Started'
                          : 'Continue',
                      gradient: AppColors.amberGradient,
                      foreground: AppColors.navy,
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
