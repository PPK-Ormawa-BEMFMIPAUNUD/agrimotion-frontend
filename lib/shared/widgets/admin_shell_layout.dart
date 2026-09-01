import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimotion/core/constants/app_constants.dart';
import 'package:agrimotion/core/theme/app_theme.dart';
import 'package:agrimotion/features/auth/presentation/controllers/auth_controller.dart';
import 'package:agrimotion/shared/widgets/sidebar.dart';
import 'package:agrimotion/shared/widgets/topbar.dart';
import 'package:agrimotion/core/network/api_client.dart';

/// Global Riverpod [StateProvider] to manage application theme mode (light/dark/system).
final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

/// Global Riverpod provider for active unread alerts count in the admin navigation shell.
final alertCountProvider = Provider<int>((ref) => 3);

/// Root ShellRoute layout widget for all `/admin/*` administrative pages.
///
/// Provides a unified, responsive dashboard shell comprising:
/// - **Desktop (>=1024px)**: Fixed collapsible [Sidebar] on the left, sticky [Topbar] on top, and scrollable content area.
/// - **Tablet & Mobile (<1024px)**: Slide-out [Drawer] containing the [Sidebar], [Topbar] with hamburger menu trigger, and content area.
/// - Dynamic authentication state synchronization with [authProvider] (name, email, avatar, role, logout).
/// - Reactive theme toggling synchronized with [themeProvider].
class AdminShellLayout extends ConsumerStatefulWidget {
  /// The active route's child widget supplied by [ShellRoute].
  final Widget child;

  const AdminShellLayout({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AdminShellLayout> createState() => _AdminShellLayoutState();
}

class _AdminShellLayoutState extends ConsumerState<AdminShellLayout> {
  /// Local state tracking whether the desktop sidebar is collapsed to icon-only mode.
  bool _isSidebarCollapsed = false;

  /// Scaffold key used to control the mobile/tablet navigation drawer.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Toggles the desktop sidebar between expanded (260px) and collapsed (72px) modes.
  void _toggleSidebarCollapse() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  /// Toggles theme mode between light and dark via Riverpod [themeProvider].
  void _toggleTheme() {
    final ThemeMode currentMode = ref.read(themeProvider);
    ref.read(themeProvider.notifier).state =
        currentMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  /// Performs user sign out and redirects to the admin login page.
  Future<void> _handleLogout() async {
    // Close drawer if open on mobile/tablet before logging out
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    await ref.read(authProvider.notifier).logout();

    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authProvider);
    final ThemeMode themeMode = ref.watch(themeProvider);
    final int alertCount = ref.watch(alertCountProvider);
    final bool isOnline = ref.watch(serverOnlineStateProvider);

    final bool isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    final String userName = authState.user?.name.isNotEmpty == true
        ? authState.user!.name
        : 'Admin AgriMotion';
    final String userEmail = authState.user?.email.isNotEmpty == true
        ? authState.user!.email
        : 'admin@agrimotion.id';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDesktop =
            constraints.maxWidth >= AppConstants.desktopBreakpoint;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor:
              isDark ? AppTheme.backgroundDark : AppTheme.backgroundColor,
          drawer: isDesktop
              ? null
              : Drawer(
                  backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 16,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(0),
                      bottomRight: Radius.circular(0),
                    ),
                  ),
                  child: SafeArea(
                    child: Sidebar(
                      isCollapsed: false,
                      alertCount: alertCount,
                    ),
                  ),
                ),
          body: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Sidebar(
                      isCollapsed: _isSidebarCollapsed,
                      onCollapseChanged: (collapsed) {
                        setState(() => _isSidebarCollapsed = collapsed);
                      },
                      alertCount: alertCount,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          AdminTopBar(
                            adminName: userName,
                            adminEmail: userEmail,
                            isDarkMode: isDark,
                            isOnline: isOnline,
                            onThemeToggle: _toggleTheme,
                            onLogout: _handleLogout,
                            onMenuToggle: _toggleSidebarCollapse,
                          ),
                          Expanded(
                            child: widget.child,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    AdminTopBar(
                      adminName: userName,
                      adminEmail: userEmail,
                      isDarkMode: isDark,
                      isOnline: isOnline,
                      onThemeToggle: _toggleTheme,
                      onLogout: _handleLogout,
                      onMenuToggle: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
                    Expanded(
                      child: widget.child,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

