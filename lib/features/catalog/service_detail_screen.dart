import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keyframes_app/app/routes.dart';
import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';
import 'package:keyframes_app/core/widgets/widgets.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/features/catalog/catalog_controller.dart';
// Reuses the public `categoryLabel` and `formatPrice` formatting helpers that
// the catalog cards already share, keeping price/category rendering identical
// across the catalog and detail screens.
import 'package:keyframes_app/features/catalog/home_screen.dart';

/// The service-detail screen (Requirement 7).
///
/// Presents a single [ServiceListing] in full: a collapsing [SliverAppBar] with
/// a Hero hero-image (matching the catalog card's `service-thumb-<id>` tag), the
/// title and category badge, the description, a deliverables checklist, a
/// horizontal sample gallery, the estimated timeline, and the starting price.
/// A sticky bottom bar hosts the gradient "Pre-Order" call-to-action that opens
/// the pre-order flow for this listing (Requirements 7.1–7.4).
///
/// The screen watches [serviceByIdProvider] (a `family` future keyed by
/// [serviceId]) and renders its `loading` (shimmer), `data`, and `error`
/// ([KErrorView] with retry) states via [AsyncValue.when]. Retry re-runs the
/// fetch by invalidating the keyed provider.
class ServiceDetailScreen extends ConsumerWidget {
  /// Creates the service-detail screen for the listing identified by
  /// [serviceId].
  const ServiceDetailScreen({required this.serviceId, super.key});

  /// The id of the [ServiceListing] to display (route path parameter `id`).
  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ServiceListing> listingAsync =
        ref.watch(serviceByIdProvider(serviceId));

    return Scaffold(
      backgroundColor: KColors.offWhite,
      body: listingAsync.when(
        data: (ServiceListing listing) => _DetailBody(listing: listing),
        loading: () => _DetailLoading(serviceId: serviceId),
        error: (Object error, StackTrace _) => SafeArea(
          child: KErrorView(
            message: 'We could not load this service right now.',
            onRetry: () => ref.invalidate(serviceByIdProvider(serviceId)),
          ),
        ),
      ),
      bottomNavigationBar: listingAsync.maybeWhen(
        data: (ServiceListing listing) => _PreOrderBar(listing: listing),
        orElse: () => null,
      ),
    );
  }
}

/// The scrollable detail content rendered once the listing has loaded.
class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.listing});

  final ServiceListing listing;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        _HeroAppBar(listing: listing),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpace.lg,
              KSpace.lg,
              KSpace.lg,
              KSpace.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _CategoryBadge(category: listing.category),
                const SizedBox(height: KSpace.md),
                Text(listing.title, style: KTextStyles.headingLg),
                if (listing.tagline.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: KSpace.xs),
                  Text(
                    listing.tagline,
                    style: KTextStyles.bodyLg.copyWith(color: KColors.slate500),
                  ),
                ],
                const SizedBox(height: KSpace.lg),
                _MetaRow(listing: listing),
                const SizedBox(height: KSpace.xl),
                _Section(
                  title: 'About this service',
                  child: Text(
                    listing.description,
                    style: KTextStyles.bodyMd.copyWith(color: KColors.slate700),
                  ),
                ),
                if (listing.deliverables.isNotEmpty) ...<Widget>[
                  const SizedBox(height: KSpace.xl),
                  _Section(
                    title: 'What you get',
                    child: _DeliverablesList(items: listing.deliverables),
                  ),
                ],
                if (listing.gallery.isNotEmpty) ...<Widget>[
                  const SizedBox(height: KSpace.xl),
                  _Section(
                    title: 'Sample work',
                    child: _Gallery(urls: listing.gallery),
                  ),
                ],
                // Trailing breathing room so the sticky CTA never overlaps the
                // last block of content.
                const SizedBox(height: KSpace.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The collapsing hero app bar holding the Hero-shared listing image
/// (Requirements 7.1, 7.2).
class _HeroAppBar extends StatelessWidget {
  const _HeroAppBar({required this.listing});

  final ServiceListing listing;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 280,
      backgroundColor: KColors.navy900,
      foregroundColor: KColors.white,
      iconTheme: const IconThemeData(color: KColors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'service-thumb-${listing.id}',
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _HeroImage(url: listing.thumbnailUrl),
              // Navy scrim so the back button and status bar stay legible over
              // bright imagery.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x660A1A3F),
                      Color(0x00000000),
                      Color(0x4D0A1A3F),
                    ],
                    stops: <double>[0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-bleed hero image with a graceful placeholder/fallback.
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const _ImagePlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (BuildContext context, String _) =>
          const KShimmer(child: _ImagePlaceholder()),
      errorWidget: (BuildContext context, String _, Object __) =>
          const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KColors.slate200,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: KColors.slate500,
        size: 48,
      ),
    );
  }
}

/// The estimated-timeline + starting-price summary row (Requirement 7.1).
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.listing});

  final ServiceListing listing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _MetaTile(
            icon: Icons.schedule_rounded,
            label: 'Timeline',
            value: _timelineLabel(listing.estimatedDays),
          ),
        ),
        const SizedBox(width: KSpace.md),
        Expanded(
          child: _MetaTile(
            icon: Icons.sell_rounded,
            label: 'Starting from',
            value: formatPrice(listing.basePrice),
          ),
        ),
      ],
    );
  }

  String _timelineLabel(int days) {
    if (days <= 0) {
      return 'Flexible';
    }
    return '~$days ${days == 1 ? 'day' : 'days'}';
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: KColors.white,
        borderRadius: BorderRadius.circular(KSpace.rLg),
        border: Border.all(color: KColors.slate200),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: KColors.navy600, size: 22),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: KTextStyles.caption.copyWith(color: KColors.slate500),
                ),
                const SizedBox(height: KSpace.xs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KTextStyles.titleMd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled content section with consistent spacing.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: KTextStyles.headingMd),
        const SizedBox(height: KSpace.md),
        child,
      ],
    );
  }
}

/// Checkmark-bulleted list of listing deliverables (Requirement 7.1).
class _DeliverablesList extends StatelessWidget {
  const _DeliverablesList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.check_circle_rounded,
                  color: KColors.success,
                  size: 20,
                ),
                const SizedBox(width: KSpace.sm),
                Expanded(
                  child: Text(item, style: KTextStyles.bodyMd),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Horizontally-scrolling gallery of sample images (Requirement 7.1).
class _Gallery extends StatelessWidget {
  const _Gallery({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (BuildContext context, int _) =>
            const SizedBox(width: KSpace.md),
        itemBuilder: (BuildContext context, int index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(KSpace.rLg),
            child: SizedBox(
              width: 220,
              child: _HeroImage(url: urls[index]),
            ),
          );
        },
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
        horizontal: KSpace.md,
        vertical: KSpace.xs,
      ),
      decoration: BoxDecoration(
        color: KColors.amber300,
        borderRadius: BorderRadius.circular(KSpace.rPill),
      ),
      child: Text(
        categoryLabel(category),
        style: KTextStyles.label.copyWith(
          color: KColors.navy900,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The sticky bottom "Pre-Order" call-to-action bar (Requirements 7.3, 7.4).
///
/// Wraps a gradient [KPrimaryButton] in a subtle, looping pulse/glow to draw
/// attention to the primary action. Tapping pushes the pre-order flow with the
/// selected [ServiceListing] as GoRouter `extra`, using `push` so the back
/// gesture returns to this detail screen.
class _PreOrderBar extends StatefulWidget {
  const _PreOrderBar({required this.listing});

  final ServiceListing listing;

  @override
  State<_PreOrderBar> createState() => _PreOrderBarState();
}

class _PreOrderBarState extends State<_PreOrderBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KColors.white,
        boxShadow: KSpace.modalShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpace.lg,
            KSpace.md,
            KSpace.lg,
            KSpace.md,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Starting from',
                      style: KTextStyles.caption
                          .copyWith(color: KColors.slate500),
                    ),
                    Text(
                      formatPrice(widget.listing.basePrice),
                      style: KTextStyles.titleMd.copyWith(
                        color: KColors.navy800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KSpace.lg),
              AnimatedBuilder(
                animation: _pulse,
                builder: (BuildContext context, Widget? child) {
                  // Subtle amber glow that breathes in and out behind the CTA.
                  final double glow = 6.0 + 10.0 * _pulse.value;
                  final double spread = 0.5 + 1.5 * _pulse.value;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(KSpace.rPill),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          // amber500 with a soft, animated alpha.
                          color: KColors.amber500.withOpacity(0.45),
                          blurRadius: glow,
                          spreadRadius: spread,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: KPrimaryButton(
                  label: 'Pre-Order',
                  icon: Icons.bolt_rounded,
                  onPressed: () => context.push(
                    KRoutes.preorder,
                    extra: widget.listing,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading skeleton shown while the listing is being fetched (Requirement
/// 17.3). Keeps the Hero target alive so the card→detail transition stays
/// smooth even before the data resolves.
class _DetailLoading extends StatelessWidget {
  const _DetailLoading({required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          expandedHeight: 280,
          backgroundColor: KColors.navy900,
          foregroundColor: KColors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: Hero(
              tag: 'service-thumb-$serviceId',
              child: const KShimmer(child: _ImagePlaceholder()),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(KSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                KShimmer.box(height: 24, width: 120),
                SizedBox(height: KSpace.md),
                KShimmer.box(height: 28, width: 220),
                SizedBox(height: KSpace.lg),
                KShimmer.box(height: 64),
                SizedBox(height: KSpace.xl),
                KShimmer.box(height: 16),
                SizedBox(height: KSpace.sm),
                KShimmer.box(height: 16),
                SizedBox(height: KSpace.sm),
                KShimmer.box(height: 16, width: 200),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
