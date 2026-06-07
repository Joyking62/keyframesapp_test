import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/section_header.dart';
import '../../widgets/service_card.dart';
import 'category_services_screen.dart';
import 'service_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final name = context.select<AppState, String>(
        (s) => s.user?.name.split(' ').first ?? 'there');

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _HeroHeader(name: name)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          sliver: SliverToBoxAdapter(
            child: const SectionHeader(title: 'What do you need?'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _CategoryTile(category: MockData.categories[i]),
              childCount: MockData.categories.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Featured services',
              actionLabel: 'See all',
              onAction: () {},
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 188,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 14, 4, 0),
              itemCount: MockData.services.length,
              itemBuilder: (context, i) {
                final s = MockData.services[i];
                return FeaturedServiceCard(
                  service: s,
                  onTap: () => _openService(context, s),
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
          sliver: SliverToBoxAdapter(
            child: const SectionHeader(title: 'Popular right now'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final s = MockData.services[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ServiceCard(
                    service: s,
                    onTap: () => _openService(context, s),
                  ),
                );
              },
              childCount: MockData.services.length,
            ),
          ),
        ),
      ],
    );
  }

  void _openService(BuildContext context, ServiceItem s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ServiceDetailScreen(service: s),
    ));
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 26),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandLogo(size: 40),
              const SizedBox(width: 10),
              const Text(
                'KEYFRAMES',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              _circleIcon(Icons.notifications_none_rounded),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Hi $name 👋',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'What are we\nbuilding today?',
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(color: Colors.white, fontSize: 28, height: 1.15),
          ),
          const SizedBox(height: 18),
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const TextField(
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search services, e.g. logo, app…',
                icon: Icon(Icons.search_rounded, color: AppColors.slate),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});
  final ServiceCategory category;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CategoryServicesScreen(category: category),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: category.gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                category.icon,
                color: category.id == 'design' || category.id == 'video'
                    ? AppColors.navy
                    : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                category.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
