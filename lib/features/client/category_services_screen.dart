import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../data/models/models.dart';
import '../../widgets/service_card.dart';
import 'service_detail_screen.dart';

class CategoryServicesScreen extends StatelessWidget {
  const CategoryServicesScreen({super.key, required this.category});
  final ServiceCategory category;

  @override
  Widget build(BuildContext context) {
    final services = MockData.servicesFor(category.id);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.navy600,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 56, vertical: 14),
              title: Text(
                category.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              background: DecoratedBox(
                decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Icon(category.icon,
                        size: 96, color: Colors.white.withOpacity(0.18)),
                  ),
                ),
              ),
            ),
          ),
          if (services.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('More packages coming soon.')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ServiceCard(
                      service: services[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ServiceDetailScreen(service: services[i]),
                        ),
                      ),
                    ),
                  ),
                  childCount: services.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
