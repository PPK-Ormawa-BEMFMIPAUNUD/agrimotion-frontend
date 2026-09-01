import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:agrimotion/features/landing/presentation/pages/landing_page.dart';
import 'package:agrimotion/features/auth/presentation/pages/login_page.dart';
import 'package:agrimotion/features/dashboard/presentation/pages/overview_page.dart';
import 'package:agrimotion/features/telemetry/presentation/pages/farm_detail_page.dart';
import 'package:agrimotion/features/alerts/presentation/pages/alerts_page.dart';
import 'package:agrimotion/features/users/presentation/pages/user_list_page.dart';
import 'package:agrimotion/features/server_monitor/presentation/pages/server_monitor_page.dart';
import 'package:agrimotion/features/activity_logs/presentation/pages/activity_logs_page.dart';
import 'package:agrimotion/shared/widgets/admin_shell_layout.dart';
import 'package:agrimotion/features/auth/presentation/controllers/auth_controller.dart';

/// Centralized route paths for AgriMotion application.
abstract class AppRoutes {
  /// Public landing page path.
  static const String landing = '/';

  /// Admin base route path.
  static const String admin = '/admin';

  /// Admin login route path.
  static const String login = '/admin/login';

  /// Admin overview dashboard route path.
  static const String overview = '/admin/overview';

  /// Admin farm telemetry detail route path.
  static const String farms = '/admin/farms';

  /// Admin alerts route path.
  static const String alerts = '/admin/alerts';

  /// Admin user management list route path.
  static const String users = '/admin/users';

  /// Admin server monitor route path.
  static const String serverMonitor = '/admin/server-monitor';

  /// Admin system activity logs route path.
  static const String activityLogs = '/admin/activity-logs';
}

/// Listenable adapter that triggers [GoRouter] route guard evaluations
/// whenever the Riverpod authentication state changes.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  /// Creates a [RouterNotifier] listening to [authProvider].
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (AuthState? previous, AuthState next) {
        if (previous?.status != next.status ||
            previous?.session != next.session) {
          notifyListeners();
        }
      },
    );
  }
}

/// Provider for [RouterNotifier] to supply [GoRouter.refreshListenable].
final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// Root navigator key for top-level routes and dialogs.
final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Shell navigator key for nested admin dashboard layout.
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'admin_shell');

/// Main Riverpod provider exposing the configured [GoRouter] instance.
final routerProvider = Provider<GoRouter>((ref) {
  final RouterNotifier routerNotifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.landing,
    refreshListenable: routerNotifier,
    debugLogDiagnostics: kDebugMode,
    redirect: (BuildContext context, GoRouterState state) {
      final AuthState authState = ref.read(authProvider);
      final bool isLoggedIn = authState.isAuthenticated;
      final String location = state.matchedLocation;

      // 1. Rute Publik (Landing Page) -> Jangan pernah cegat/redirect
      if (location == '/') return null;

      // 2. Jika user mencoba akses area /admin
      final bool isAccessingAdmin = location.startsWith('/admin');
      final bool isAtLoginPage = location == '/admin/login';

      // 3. Jika auth masih loading/initial, jangan redirect dulu untuk menghindari flicker
      if (authState.isLoading || authState.status == AuthStatus.initial) {
        return null;
      }

      // 4. Jika belum login dan mencoba masuk ke dashboard admin selain login page
      if (isAccessingAdmin && !isLoggedIn && !isAtLoginPage) {
        return '/admin/login';
      }

      // 5. Jika sudah login tapi masih di halaman login -> lempar ke dashboard overview
      if (isAtLoginPage && isLoggedIn) {
        return '/admin/overview';
      }

      // 6. Jika user mengakses /admin langsung
      if (location == '/admin') {
        return isLoggedIn ? '/admin/overview' : '/admin/login';
      }

      // Rute lain yang diizinkan (misal error page) -> proceed
      return null;
    },
    routes: <RouteBase>[
      // Public Landing Page
      GoRoute(
        path: AppRoutes.landing,
        name: 'landing',
        builder: (BuildContext context, GoRouterState state) =>
            const LandingPage(),
      ),

      // Admin Login Page
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginPage(),
      ),

      // Redirect helper for root '/admin'
      GoRoute(
        path: AppRoutes.admin,
        redirect: (BuildContext context, GoRouterState state) {
          final bool isAuthenticated = ref.read(authProvider).isAuthenticated;
          return isAuthenticated ? AppRoutes.overview : AppRoutes.login;
        },
      ),

      // Admin Protected Shell Routes
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return AdminShellLayout(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.overview,
            name: 'overview',
            builder: (BuildContext context, GoRouterState state) =>
                const OverviewPage(),
          ),
          GoRoute(
            path: AppRoutes.farms,
            name: 'farms',
            builder: (BuildContext context, GoRouterState state) =>
                const FarmDetailPage(),
          ),
          GoRoute(
            path: AppRoutes.alerts,
            name: 'alerts',
            builder: (BuildContext context, GoRouterState state) =>
                const AlertsPage(),
          ),
          GoRoute(
            path: AppRoutes.users,
            name: 'users',
            builder: (BuildContext context, GoRouterState state) =>
                const UserListPage(),
          ),
          GoRoute(
            path: AppRoutes.serverMonitor,
            name: 'server_monitor',
            builder: (BuildContext context, GoRouterState state) =>
                const ServerMonitorPage(),
          ),
          GoRoute(
            path: AppRoutes.activityLogs,
            name: 'activity_logs',
            builder: (BuildContext context, GoRouterState state) =>
                const ActivityLogsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(
        title: const Text('Halaman Tidak Ditemukan'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              '404 - Halaman Tidak Ditemukan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Rute "${state.uri.path}" tidak dapat ditemukan.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.landing),
              icon: const Icon(Icons.home),
              label: const Text('Kembali ke Beranda'),
            ),
          ],
        ),
      ),
    ),
  );
});
