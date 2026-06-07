import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../widgets/buttons.dart';
import 'preorder_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({super.key, required this.service});
  final ServiceItem service;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  int _tierIndex = 1; // default to "Standard"

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    final tier = s.tiers[_tierIndex];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: AppColors.navy600,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration:
                        BoxDecoration(gradient: AppColors.heroGradient),
                  ),
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(s.icon,
                        size: 180, color: Colors.white.withOpacity(0.10)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(s.icon, color: AppColors.amberBright),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: AppColors.amber, size: 18),
                            Text(' ${s.rating}  ',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            Text('(${s.reviews} reviews)',
                                style:
                                    const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About this service',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(s.description,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 22),
                  Text("What's included",
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ...s.features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                size: 12, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(f)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Choose a package',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ...List.generate(s.tiers.length, (i) {
                    return _TierCard(
                      tier: s.tiers[i],
                      selected: i == _tierIndex,
                      onTap: () => setState(() => _tierIndex = i),
                    );
                  }),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, 16 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tier.name,
                    style: Theme.of(context).textTheme.bodySmall),
                Text(
                  '\$${tier.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GradientButton(
                label: 'Pre-order now',
                gradient: AppColors.amberGradient,
                foreground: AppColors.navy,
                icon: Icons.shopping_bag_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PreOrderScreen(service: s, tier: tier),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final ServiceTier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy600 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.amber : AppColors.cloud,
            width: selected ? 2 : 1.4,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.navy.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tier.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: selected ? Colors.white : AppColors.navy,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${tier.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: selected ? AppColors.amberBright : AppColors.amberDeep,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              tier.blurb,
              style: TextStyle(
                color: selected ? Colors.white70 : AppColors.slate,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _meta(Icons.schedule_rounded, '${tier.deliveryDays} days',
                    selected),
                const SizedBox(width: 16),
                _meta(Icons.autorenew_rounded, '${tier.revisions} revisions',
                    selected),
              ],
            ),
            if (selected) ...[
              const Divider(color: Colors.white24, height: 22),
              ...tier.includes.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.amberBright, size: 16),
                      const SizedBox(width: 8),
                      Text(e,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label, bool selected) {
    final c = selected ? Colors.white70 : AppColors.slate;
    return Row(
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: c, fontSize: 12.5)),
      ],
    );
  }
}
