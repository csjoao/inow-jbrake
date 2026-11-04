import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Abas da navegação inferior.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.yellow,
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler),
            label: 'Veículo',
          ),
          NavigationDestination(
            icon: Icon(Icons.electric_bike_outlined),
            selectedIcon: Icon(Icons.electric_bike),
            label: 'Bicicletas',
          ),
        ],
      ),
    );
  }
}
