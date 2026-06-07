import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/animations/animations.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';

/// Immutable description of a single onboarding page.
///
/// Each page introduces one of the app's three pillars (Requirement 3.1):
/// browsing services, pre-ordering and tracking, and chatting directly with
/// Keyframes. Image assets are intentionally avoided — a brand-colored
/// [icon]/[accent] placeholder illustration is rendered instead so the screen
/// compiles and renders without bundled artwork.
@immutable
class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  /// Placeholder illustration glyph for this page.
  final IconData icon;

  /// Poppins heading text.
  final String title;

  /// Inter body copy.
  final String body;

  /// Amber accent used by the illustration backdrop.
  final Color accent;
}

/// The three-page onboarding flow shown on first launch (Requirement 3).
///
/// Presents three swipeable pages with offset-linked parallax illustrations and
/// an amber-active page indicator (Requirements 3.1, 3.2). A top-right "Skip"
/// action and a primary button ("Next" on the first two pages, "Get Started" on
/// the last) both complete onboarding: they persist `seenOnboarding = true` via
/// the [LocalSource] and navigate to the login route (Requirement 3.3). The
/// router never reaches this screen again once the flag is persisted
/// (Requirement 3.4, enforced by the bootstrap/route guard).
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the onboarding screen.
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const List<_OnboardingPageData> _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      icon: Icons.grid_view_rounded,
      title: 'Browse services',
      body:
          'Explore a curated catalog of Keyframes IT and graphic-design '
          'services — from mobile apps to logo creation — all in one place.',
      accent: KColors.amber500,
    ),
    _OnboardingPageData(
      icon: Icons.timeline_rounded,
      title: 'Pre-order & track',
      body:
          'Place a guided pre-order, share your requirements, and follow every '
          'status update from pending to completed on your dashboard.',
      accent: KColors.amber400,
    ),
    _OnboardingPageData(
      icon: Icons.forum_rounded,
      title: 'Chat directly with Keyframes',
      body:
          'Talk to the Keyframes team in real time — discuss your project, '
          'share files, and stay in the loop without leaving the app.',
      accent: KColors.navy400,
    ),
  ];

  final PageController _controller = PageController();

  /// The live page position (fractional while swiping) that drives both the
  /// parallax illustrations and the page indicator.
  double _page = 0;

  /// Guards against double navigation if Skip/Get Started is tapped twice.
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final double page = _controller.hasClients
        ? (_controller.page ?? _controller.initialPage.toDouble())
        : 0;
    if (page != _page) {
      setState(() => _page = page);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  int get _currentIndex => _page.round().clamp(0, _pages.length - 1);

  bool get _isLastPage => _currentIndex == _pages.length - 1;

  /// Persists the onboarding flag and routes to login (Requirement 3.3).
  Future<void> _complete() async {
    if (_completing) {
      return;
    }
    _completing = true;
    await ref.read(localSourceProvider).setSeenOnboarding(true);
    if (!mounted) {
      return;
    }
    context.go(KRoutes.login);
  }

  void _onPrimaryPressed() {
    if (_isLastPage) {
      _complete();
      return;
    }
    _controller.nextPage(
      duration: KMotion.medium,
      curve: KMotion.enter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.offWhite,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Top bar: Skip action aligned to the right.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpace.sm,
                  vertical: KSpace.xs,
                ),
                child: TextButton(
                  onPressed: _complete,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      KSpace.minTouchTarget,
                      KSpace.minTouchTarget,
                    ),
                    foregroundColor: KColors.slate500,
                  ),
                  child: Text(
                    'Skip',
                    style: KTextStyles.label.copyWith(color: KColors.slate500),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                itemBuilder: (BuildContext context, int index) {
                  // Distance of this page from the current scroll position;
                  // 0 when centered, ±1 when one page away. Drives parallax.
                  final double delta = index - _page;
                  return _OnboardingPageView(
                    data: _pages[index],
                    parallax: delta,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpace.xl,
                KSpace.lg,
                KSpace.xl,
                KSpace.xl,
              ),
              child: Column(
                children: <Widget>[
                  _PageIndicator(
                    count: _pages.length,
                    activeIndex: _currentIndex,
                  ),
                  const SizedBox(height: KSpace.xl),
                  KPrimaryButton(
                    label: _isLastPage ? 'Get Started' : 'Next',
                    expanded: true,
                    onPressed: _onPrimaryPressed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single onboarding page: a parallax illustration above staggered text.
class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({
    required this.data,
    required this.parallax,
  });

  final _OnboardingPageData data;

  /// Signed page-distance from the viewport center (0 = centered).
  final double parallax;

  @override
  Widget build(BuildContext context) {
    // Layers translate at different rates so they appear at different depths.
    final bool motion = !KMotion.isDisabled(context);
    final double backdropShift = motion ? parallax * -60.0 : 0.0;
    final double glyphShift = motion ? parallax * -120.0 : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Center(
              child: _ParallaxIllustration(
                data: data,
                backdropShift: backdropShift,
                glyphShift: glyphShift,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                StaggeredEntrance(
                  index: 0,
                  child: Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: KTextStyles.headingLg,
                  ),
                ),
                const SizedBox(height: KSpace.md),
                StaggeredEntrance(
                  index: 1,
                  child: Text(
                    data.body,
                    textAlign: TextAlign.center,
                    style: KTextStyles.bodyLg.copyWith(
                      color: KColors.slate500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Layered placeholder illustration whose layers move at different rates to
/// create a parallax depth effect (Requirement 3.2).
class _ParallaxIllustration extends StatelessWidget {
  const _ParallaxIllustration({
    required this.data,
    required this.backdropShift,
    required this.glyphShift,
  });

  final _OnboardingPageData data;
  final double backdropShift;
  final double glyphShift;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: 260,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Back layer: soft amber/navy halo (slower parallax).
          Transform.translate(
            offset: Offset(backdropShift, 0),
            child: Container(
              height: 220,
              width: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    data.accent.withOpacity(0.28),
                    data.accent.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Mid layer: rounded brand card backdrop.
          Transform.translate(
            offset: Offset(backdropShift * 0.6, 0),
            child: Container(
              height: 168,
              width: 168,
              decoration: BoxDecoration(
                color: KColors.white,
                borderRadius: BorderRadius.circular(KSpace.rXl),
                boxShadow: KSpace.cardShadow,
              ),
            ),
          ),
          // Front layer: the brand glyph (fastest parallax).
          Transform.translate(
            offset: Offset(glyphShift, 0),
            child: Icon(
              data.icon,
              size: 88,
              color: data.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of page-indicator dots; the active dot is rendered in amber and the
/// inactive dots in slate (Requirement 3.2).
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: KMotion.fast,
            curve: KMotion.enter,
            margin: const EdgeInsets.symmetric(horizontal: KSpace.xs),
            height: 8,
            width: i == activeIndex ? 24 : 8,
            decoration: BoxDecoration(
              color: i == activeIndex ? KColors.amber500 : KColors.slate200,
              borderRadius: BorderRadius.circular(KSpace.rPill),
            ),
          ),
      ],
    );
  }
}
