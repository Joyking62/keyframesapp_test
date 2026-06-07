import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/animations/staggered_entrance.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/features/catalog/catalog_controller.dart';

/// The client home / service-catalog screen (Requirement 6).
///
/// Composes the catalog experience from the design's "Home / Service Catalog"
/// section:
///
/// * a greeting header personalized with the signed-in user's name,
/// * a (tap-to-search) search bar,
/// * category chips for *All*, *IT Services*, and *Graphic Design* that toggle
///   the [selectedCategoryProvider] filter,
/// * a featured carousel of 3D-tilt cards built from the first few listings,
/// * and a grid of service cards (thumbnail, title, tagline, "from" price, and
///   a category badge) that navigate to the service-detail route on tap.
///
/// The catalog body watches `catalogControllerProvider(selectedCategory)` and
/// renders its `data` / `loading` / `error` states. Loading shows a polished
/// shimmer skeleton (featured carousel + card grid) that mirrors the real
/// layout; cards animate in with a capped [StaggeredEntrance] fade+slide; an
/// empty filter/catalog shows a friendly illustration with a refresh/browse
/// CTA; and an amber offline banner is shown above the catalog (driven by
/// [catalogOfflineProvider]) whenever listings are served from the offline
/// cache (Requirements 6.4–6.7, 17.1, 17.2).
class HomeScreen extends ConsumerWidget {
  /// Creates the home / service-catalog screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ServiceCategory? selectedCategory =
        ref.watch(selectedCategoryProvider);
    final AsyncValue<List<ServiceListing>> catalog =
        ref.watch(catalogControllerProvider(selectedCategory));
    final bool isOffline = ref.watch(catalogOfflineProvider);

    void refreshCatalog() {
      // Re-subscribe to the catalog stream for the active filter.
      ref.invalidate(catalogControllerProvider(selectedCategory));
    }

    return Scaffold(
      backgroundColor: KColors.offWhite,
      body: SafeArea(
        child: RefreshIndicator(
          color: KColors.navy800,
          onRefresh: () async => refreshCatalog(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              const SliverToBoxAdapter(child: _GreetingHeader()),
              const SliverToBoxAdapter(child: _SearchBar()),
              SliverToBoxAdapter(
                child: _CategoryChips(selected: selectedCategory),
              ),
              // Offline banner shown above the catalog whenever data is being
              // served from the cache / the network is unavailable
              // (Requirements 6.6, 17.1).
              if (isOffline)
                SliverToBoxAdapter(
                  child: _OfflineBanner(onRetry: refreshCatalog),
                ),
              ...catalog.when(
                data: (List<ServiceListing> listings) =>
                    _buildCatalogSlivers(context, listings),
                loading: () => const <Widget>[
                  SliverToBoxAdapter(
                    child: _CatalogLoadingSkeleton(
                      key: ValueKey<String>('catalogLoading'),
                    ),
                  ),
                ],
                error: (Object error, StackTrace stackTrace) => <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: KErrorView(
                      message: 'We could not load the catalog right now.',
                      onRetry: refreshCatalog,
                    ),
                  ),
                ],
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: KSpace.xl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the data-state slivers: a featured carousel (when listings exist)
  /// followed by the service-card grid, or an empty state when there are none.
  List<Widget> _buildCatalogSlivers(
    BuildContext context,
    List<ServiceListing> listings,
  ) {
    if (listings.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _CatalogEmptyState(),
        ),
      ];
    }

    final List<ServiceListing> featured = listings.take(5).toList();

    return <Widget>[
      const SliverToBoxAdapter(
        child: _SectionHeader(title: 'Featured'),
      ),
      SliverToBoxAdapter(
        child: _FeaturedCarousel(listings: featured),
      ),
      const SliverToBoxAdapter(
        child: _SectionHeader(title: 'All services'),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          KSpace.lg,
          KSpace.sm,
          KSpace.lg,
          KSpace.lg,
        ),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisSpacing: KSpace.lg,
            crossAxisSpacing: KSpace.lg,
            childAspectRatio: 0.72,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final ServiceListing listing = listings[index];
              return StaggeredEntrance(
                index: index,
                child: _ServiceCard(listing: listing),
              );
            },
            childCount: listings.length,
          ),
        ),
      ),
    ];
  }
}

/// Personalized greeting at the top of the catalog (Requirement 6.1).
class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? name = ref.watch(currentUserProvider)?.name;
    final String greeting = _greetingForNow();
    final String displayName = (name != null && name.trim().isNotEmpty)
        ? name.trim().split(' ').first
        : 'there';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.lg,
        KSpace.lg,
        KSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$greeting,',
            style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
          ),
          const SizedBox(height: KSpace.xs),
          Text(
            displayName,
            style: KTextStyles.headingLg,
          ),
        ],
      ),
    );
  }

  String _greetingForNow() {
    final int hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 17) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }
}

/// A non-functional search bar; tapping it will open the search screen in a
/// later task. Rendered as a button so it is keyboard/screen-reader reachable.
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.sm,
        KSpace.lg,
        KSpace.sm,
      ),
      child: Material(
        color: KColors.white,
        borderRadius: BorderRadius.circular(KSpace.rLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(KSpace.rLg),
          onTap: () {
            // TODO(task-16): Navigate to the dedicated search screen.
          },
          child: Container(
            height: KSpace.minTouchTarget,
            padding: const EdgeInsets.symmetric(horizontal: KSpace.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KSpace.rLg),
              border: Border.all(color: KColors.slate200),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.search_rounded,
                  color: KColors.slate500,
                ),
                const SizedBox(width: KSpace.sm),
                Text(
                  'Search services',
                  style:
                      KTextStyles.bodyMd.copyWith(color: KColors.slate500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The category filter chips: *All*, *IT Services*, *Graphic Design*
/// (Requirements 6.1, 6.3). Selecting a chip toggles
/// [selectedCategoryProvider]; tapping the active chip clears the filter.
class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.selected});

  final ServiceCategory? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(ServiceCategory? category) {
      ref.read(selectedCategoryProvider.notifier).state = category;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KSpace.lg),
        child: Row(
          children: <Widget>[
            _CategoryChip(
              label: 'All',
              selected: selected == null,
              onTap: () => select(null),
            ),
            const SizedBox(width: KSpace.sm),
            _CategoryChip(
              label: categoryLabel(ServiceCategory.itServices),
              selected: selected == ServiceCategory.itServices,
              onTap: () => select(
                selected == ServiceCategory.itServices
                    ? null
                    : ServiceCategory.itServices,
              ),
            ),
            const SizedBox(width: KSpace.sm),
            _CategoryChip(
              label: categoryLabel(ServiceCategory.graphicDesign),
              selected: selected == ServiceCategory.graphicDesign,
              onTap: () => select(
                selected == ServiceCategory.graphicDesign
                    ? null
                    : ServiceCategory.graphicDesign,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? KColors.navy800 : KColors.white,
      borderRadius: BorderRadius.circular(KSpace.rPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(KSpace.rPill),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.lg,
            vertical: KSpace.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KSpace.rPill),
            border: Border.all(
              color: selected ? KColors.navy800 : KColors.slate200,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: KTextStyles.label.copyWith(
              color: selected ? KColors.white : KColors.slate700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small left-aligned section title used above the carousel and grid.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.lg,
        KSpace.lg,
        KSpace.xs,
      ),
      child: Text(title, style: KTextStyles.headingMd),
    );
  }
}

/// A horizontally-paged, optionally auto-scrolling carousel of 3D-tilt feature
/// cards built from the first few listings (Requirement 6.1).
class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({required this.listings});

  final List<ServiceListing> listings;

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  static const double _viewportFraction = 0.86;

  final PageController _controller =
      PageController(viewportFraction: _viewportFraction);
  Timer? _autoScrollTimer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _maybeStartAutoScroll();
  }

  void _maybeStartAutoScroll() {
    _autoScrollTimer?.cancel();
    if (widget.listings.length < 2) {
      return;
    }
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (Timer _) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      final int next = (_page + 1) % widget.listings.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.listings.length,
        onPageChanged: (int index) => _page = index,
        itemBuilder: (BuildContext context, int index) {
          final ServiceListing listing = widget.listings[index];
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpace.sm,
              vertical: KSpace.sm,
            ),
            child: KTilt3D(
              child: _FeaturedCard(listing: listing),
            ),
          );
        },
      ),
    );
  }
}

/// A single featured card: full-bleed thumbnail with a navy gradient scrim and
/// the service title/tagline overlaid.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.listing});

  final ServiceListing listing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(KRoutes.serviceDetailPath(listing.id)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KSpace.rLg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _Thumbnail(url: listing.thumbnailUrl),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x00000000),
                    Color(0xCC0A1A3F),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(KSpace.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _CategoryBadge(category: listing.category),
                  const SizedBox(height: KSpace.sm),
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KTextStyles.titleMd.copyWith(color: KColors.white),
                  ),
                  const SizedBox(height: KSpace.xs),
                  Text(
                    listing.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KTextStyles.bodyMd.copyWith(
                      // white @ ~85% alpha (0xD9 = 217/255).
                      color: const Color(0xD9FFFFFF),
                    ),
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

/// A catalog service card rendered inside a [KCard] (Requirement 6.2):
/// thumbnail, title, tagline, "from" price, and a category badge. Tapping it
/// navigates to the service-detail route (Requirement 6 → service detail).
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.listing});

  final ServiceListing listing;

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go(KRoutes.serviceDetailPath(listing.id)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KSpace.rLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Hero(
                    tag: 'service-thumb-${listing.id}',
                    child: _Thumbnail(url: listing.thumbnailUrl),
                  ),
                  Positioned(
                    top: KSpace.sm,
                    left: KSpace.sm,
                    child: _CategoryBadge(category: listing.category),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(KSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KTextStyles.titleMd,
                  ),
                  const SizedBox(height: KSpace.xs),
                  Text(
                    listing.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        KTextStyles.bodyMd.copyWith(color: KColors.slate500),
                  ),
                  const SizedBox(height: KSpace.sm),
                  Text(
                    'from ${formatPrice(listing.basePrice)}',
                    style: KTextStyles.label.copyWith(
                      color: KColors.navy800,
                      fontWeight: FontWeight.w700,
                    ),
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

/// A thumbnail image with a graceful placeholder/fallback when the listing has
/// no `thumbnailUrl` or the network image fails to load.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const _ThumbnailPlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (BuildContext context, String _) =>
          const KShimmer(child: _ThumbnailPlaceholder()),
      errorWidget: (BuildContext context, String _, Object __) =>
          const _ThumbnailPlaceholder(),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KColors.slate200,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: KColors.slate500,
        size: 40,
      ),
    );
  }
}

/// A small pill badge showing the listing's [ServiceCategory].
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final ServiceCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpace.sm,
        vertical: KSpace.xs,
      ),
      decoration: BoxDecoration(
        color: KColors.amber500,
        borderRadius: BorderRadius.circular(KSpace.rPill),
      ),
      child: Text(
        categoryLabel(category),
        style: KTextStyles.caption.copyWith(
          color: KColors.navy900,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Polished loading skeleton for the catalog (Requirement 6.4).
///
/// Mirrors the real catalog layout so the transition to loaded content is
/// visually stable: a featured-carousel placeholder, a section header line,
/// and a grid of card skeletons whose internal structure (thumbnail block +
/// title / tagline / price lines) matches [_ServiceCard]. The whole tree is
/// wrapped in a single [KShimmer] so one gradient sweep animates across every
/// placeholder block in unison.
class _CatalogLoadingSkeleton extends StatelessWidget {
  const _CatalogLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return KShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Featured carousel placeholder.
          const Padding(
            padding: EdgeInsets.fromLTRB(
              KSpace.lg,
              KSpace.lg,
              KSpace.lg,
              KSpace.xs,
            ),
            child: _SkeletonBlock(width: 120, height: 22),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpace.lg,
              vertical: KSpace.sm,
            ),
            child: _SkeletonBlock(
              height: 184,
              borderRadius: BorderRadius.circular(KSpace.rLg),
            ),
          ),
          // "All services" section header placeholder.
          const Padding(
            padding: EdgeInsets.fromLTRB(
              KSpace.lg,
              KSpace.lg,
              KSpace.lg,
              KSpace.xs,
            ),
            child: _SkeletonBlock(width: 140, height: 22),
          ),
          // Service-card grid placeholder.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpace.lg,
              KSpace.sm,
              KSpace.lg,
              KSpace.lg,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: KSpace.lg,
                crossAxisSpacing: KSpace.lg,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (BuildContext context, int index) =>
                  const _ServiceCardSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single card skeleton whose structure matches [_ServiceCard]: a large
/// thumbnail block above stacked title / tagline / price lines.
class _ServiceCardSkeleton extends StatelessWidget {
  const _ServiceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(KSpace.rLg),
      child: Container(
        color: KColors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Expanded(child: _SkeletonBlock()),
            Padding(
              padding: const EdgeInsets.all(KSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SkeletonBlock(height: 14),
                  const SizedBox(height: KSpace.sm),
                  const _SkeletonBlock(height: 10),
                  const SizedBox(height: KSpace.xs),
                  _SkeletonBlock(height: 10, width: 90),
                  const SizedBox(height: KSpace.sm),
                  _SkeletonBlock(height: 12, width: 64),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A solid rounded placeholder block used inside the loading skeleton. The
/// opaque fill is what the wrapping [KShimmer] sweeps its gradient mask over.
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    this.height,
    this.width,
    this.borderRadius,
  });

  final double? height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: KColors.slate200,
        borderRadius: borderRadius ?? BorderRadius.circular(KSpace.rSm),
      ),
    );
  }
}

/// A compact amber/navy banner shown above the catalog when listings are being
/// served from the offline cache or the network is unavailable
/// (Requirements 6.6, 17.1). Offers a retry affordance so the user can attempt
/// to reconnect without leaving the screen (Requirement 17.4).
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        KSpace.sm,
        KSpace.lg,
        KSpace.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.md,
          vertical: KSpace.sm,
        ),
        decoration: BoxDecoration(
          color: KColors.amber500,
          borderRadius: BorderRadius.circular(KSpace.rMd),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.cloud_off_rounded,
              color: KColors.navy900,
              size: 20,
            ),
            const SizedBox(width: KSpace.sm),
            Expanded(
              child: Text(
                "You're offline — showing saved services.",
                style: KTextStyles.label.copyWith(
                  color: KColors.navy900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: KSpace.sm),
            InkWell(
              borderRadius: BorderRadius.circular(KSpace.rSm),
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpace.sm,
                  vertical: KSpace.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.refresh_rounded,
                      color: KColors.navy900,
                      size: 18,
                    ),
                    const SizedBox(width: KSpace.xs),
                    Text(
                      'Retry',
                      style: KTextStyles.label.copyWith(
                        color: KColors.navy900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Friendly empty state with an illustration and a call to action
/// (Requirement 6.7). When a category filter is active, the CTA clears the
/// filter to browse all services; otherwise it refreshes the catalog.
class _CatalogEmptyState extends ConsumerWidget {
  const _CatalogEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ServiceCategory? selected = ref.watch(selectedCategoryProvider);
    final bool filtered = selected != null;

    final String message = filtered
        ? 'No ${categoryLabel(selected)} services match right now.'
        : 'Check back soon — new services are on the way.';
    final String ctaLabel = filtered ? 'Browse all services' : 'Refresh';

    void onCta() {
      if (filtered) {
        // Clear the filter so the user sees the full catalog.
        ref.read(selectedCategoryProvider.notifier).state = null;
      } else {
        ref.invalidate(catalogControllerProvider(selected));
      }
    }

    return Padding(
      padding: const EdgeInsets.all(KSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: KColors.slate200,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.storefront_outlined,
              size: 48,
              color: KColors.navy800,
            ),
          ),
          const SizedBox(height: KSpace.lg),
          Text(
            'No services available yet',
            textAlign: TextAlign.center,
            style: KTextStyles.headingMd,
          ),
          const SizedBox(height: KSpace.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
          ),
          const SizedBox(height: KSpace.xl),
          KPrimaryButton(
            label: ctaLabel,
            icon: filtered ? Icons.grid_view_rounded : Icons.refresh_rounded,
            onPressed: onCta,
          ),
        ],
      ),
    );
  }
}

/// Human-readable label for a [ServiceCategory].
String categoryLabel(ServiceCategory category) {
  switch (category) {
    case ServiceCategory.itServices:
      return 'IT Services';
    case ServiceCategory.graphicDesign:
      return 'Graphic Design';
  }
}

/// Formats a base price as a compact "from"-style currency string.
String formatPrice(double price) {
  final bool whole = price == price.roundToDouble();
  return whole ? '\$${price.toStringAsFixed(0)}' : '\$${price.toStringAsFixed(2)}';
}
