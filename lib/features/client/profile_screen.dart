import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          // Profile header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    gradient: AppColors.amberGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user?.initials ?? 'K',
                    style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Guest',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)),
                      Text(user?.email ?? '',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _group('Account', [
            _tile(Icons.receipt_long_rounded, 'My orders'),
            _tile(Icons.favorite_border_rounded, 'Saved services'),
            _tile(Icons.payment_rounded, 'Payment methods'),
          ]),
          const SizedBox(height: 16),
          _group('Preferences', [
            _tile(Icons.notifications_none_rounded, 'Notifications'),
            _tile(Icons.dark_mode_outlined, 'Appearance'),
            _tile(Icons.language_rounded, 'Language'),
          ]),
          const SizedBox(height: 16),
          _group('Support', [
            _tile(Icons.help_outline_rounded, 'Help center'),
            _tile(Icons.info_outline_rounded, 'About Keyframes'),
            _tile(Icons.privacy_tip_outlined, 'Privacy policy'),
          ]),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<AppState>().logout(),
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            label: const Text('Log out',
                style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              side: BorderSide(color: AppColors.danger.withOpacity(0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Keyframes v1.0.0',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  color: AppColors.slate,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _tile(IconData icon, String label) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.cloud,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.navy600, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
      onTap: () {},
    );
  }
}
