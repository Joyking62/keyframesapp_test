import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/brand_logo.dart';
import 'admin_dashboard.dart';
import 'admin_orders.dart';
import 'admin_chat.dart';

/// Admin experience uses a rail-style bottom bar on a darker chrome.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  final _pages = const [
    AdminDashboard(),
    AdminOrders(),
    AdminChat(),
  ];

  static const _items = [
    (Icons.insights_rounded, 'Overview'),
    (Icons.inventory_2_rounded, 'Orders'),
    (Icons.forum_rounded, 'Inbox'),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      drawer: _AdminDrawer(name: app.user?.name ?? 'Admin'),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const BrandLogo(size: 30),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Keyframes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text('Admin console',
                    style: TextStyle(
                        color: AppColors.amberBright.withOpacity(0.9),
                        fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.white),
          ),
        ],
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.amber.withOpacity(0.25),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          height: 70,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: _items
              .map((e) => NavigationDestination(
                    icon: Icon(e.$1, color: AppColors.slate),
                    selectedIcon: Icon(e.$1, color: AppColors.navy),
                    label: e.$2,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.navy,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const BrandLogo(size: 44, glow: true),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      const Text('Administrator',
                          style: TextStyle(color: AppColors.amberBright,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            _drawerItem(Icons.dashboard_rounded, 'Dashboard'),
            _drawerItem(Icons.inventory_2_rounded, 'Manage orders'),
            _drawerItem(Icons.grid_view_rounded, 'Services & pricing'),
            _drawerItem(Icons.people_alt_rounded, 'Clients'),
            _drawerItem(Icons.forum_rounded, 'Inbox'),
            _drawerItem(Icons.bar_chart_rounded, 'Reports'),
            _drawerItem(Icons.settings_rounded, 'Settings'),
            const Spacer(),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: AppColors.amberBright),
              title: const Text('Log out',
                  style: TextStyle(color: Colors.white)),
              onTap: () => context.read<AppState>().logout(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label) => ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: () {},
      );
}
