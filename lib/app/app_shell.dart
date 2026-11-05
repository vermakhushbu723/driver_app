import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_bottom_nav.dart';
import '../features/tracking/presentation/tracking_screens.dart';

const List<NavTab> _tabs = [
  (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
  (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Orders'),
  (icon: Icons.factory_outlined, activeIcon: Icons.factory, label: 'Pickup'),
  (icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'Collection'),
  (icon: Icons.menu, activeIcon: Icons.menu, label: 'Menu'),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LocationRecorder(child: shell),
      bottomNavigationBar: AppBottomNav(
        tabs: _tabs,
        currentIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
