import 'package:go_router/go_router.dart';

import '../../features/gallery/gallery_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../env/environment.dart';
import 'worker_shell.dart';

/// The worker shell's four destinations, per the approved information
/// architecture in docs/architecture/overview.md.
///
/// "Current shift" is deliberately not a tab: it is what Home *is* when a shift
/// is active. A worker on a plant floor in gloves needs the next action to be
/// obvious, not to choose between two screens that both claim to be about the
/// shift.
///
/// The officer and administrator shells are Phase 9; their routes are not
/// declared here until they exist. Role-based redirect guards need auth, which
/// is Phase 7.
GoRouter buildRouter(EnvironmentConfig config) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => WorkerShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/scan', builder: (_, _) => const ScanScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => ProfileScreen(config: config),
                routes: [
                  // Development only. Guarded by the same flag that compiles
                  // simulation out of production builds, so the gallery cannot
                  // appear in a worker's release app.
                  if (config.simulationAvailable)
                    GoRoute(
                      path: 'gallery',
                      builder: (_, _) => const GalleryScreen(),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
