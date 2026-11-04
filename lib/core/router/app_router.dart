import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_settings/presentation/screens/app_settings_screen.dart';
import '../../features/bike/presentation/screens/console_screen.dart';
import '../../features/bike/presentation/screens/dashboard_screen.dart';
import '../../features/bike/presentation/screens/home_screen.dart';
import '../../features/bike/presentation/screens/info_screen.dart';
import '../../features/bike/presentation/screens/nfc_screen.dart';
import '../../features/bike/presentation/screens/scan_screen.dart';
import '../../features/bike/presentation/screens/security_screen.dart';
import '../../features/bike/presentation/screens/settings_screen.dart';
import '../../features/fleet/presentation/screens/fleet_screen.dart';
import '../widgets/swipe_back.dart';
import 'app_shell.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const scan = '/scan';
  static const bike = '/bike';
  static const settings = '/bike/settings';
  static const console = '/bike/console';
  static const info = '/bike/info';
  static const nfc = '/bike/nfc';
  static const security = '/bike/security';
  static const bikes = '/bikes';
  static const appSettings = '/bikes/settings';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Telas abertas em cima das abas (sem a navegação inferior) usam a raiz.
  final root = GlobalKey<NavigatorState>();

  GoRoute fullScreen(String path, Widget Function() page) => GoRoute(
    path: path,
    parentNavigatorKey: root,
    builder: (_, _) => SwipeBack(child: page()),
  );

  return GoRouter(
    navigatorKey: root,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const HomeScreen(),
                routes: [
                  fullScreen('scan', () => const ScanScreen()),
                  GoRoute(
                    path: 'bike',
                    parentNavigatorKey: root,
                    builder: (_, _) =>
                        const SwipeBack(child: DashboardScreen()),
                    routes: [
                      fullScreen('settings', () => const SettingsScreen()),
                      fullScreen('console', () => const ConsoleScreen()),
                      fullScreen('info', () => const InfoScreen()),
                      fullScreen('nfc', () => const NfcScreen()),
                      fullScreen('security', () => const SecurityScreen()),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bikes,
                builder: (_, _) => const FleetScreen(),
                routes: [
                  fullScreen('settings', () => const AppSettingsScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
