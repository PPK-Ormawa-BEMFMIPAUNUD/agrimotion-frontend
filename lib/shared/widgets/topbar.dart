import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimotion/core/theme/colors.dart';
import 'package:agrimotion/core/theme/app_theme.dart';
import 'package:agrimotion/shared/widgets/responsive_layout.dart';

/// Represents an individual crumb in the navigation breadcrumb trail.
class BreadcrumbItem {
  /// Display label for this breadcrumb segment.
  final String title;

  /// Navigation target path for GoRouter.
  final String path;

  /// Whether this crumb is the active / current destination.
  final bool isLast;

  const BreadcrumbItem({
    required this.title,
    required this.path,
    this.isLast = false,
  });
}

/// Production-ready Admin TopBar / Header widget for AgriMotion.
///
/// Features:
/// - Horizontal top bar with responsive layout adaptation.
/// - Left side: Dynamic breadcrumbs generated from [GoRouterState.of]
///   (e.g., 'Admin / Overview', 'Admin / Monitoring Lahan').
///   On mobile screens, replaces full breadcrumbs with a hamburger menu button.
/// - Right side:
///   1. Dark/light theme toggle switch with Sun and Moon icons.
///   2. Server status pill indicator (green dot + 'Online' or red dot + 'Offline').
///   3. Admin user avatar circle displaying the first letter of [adminName].
///   4. Interactive popup dropdown menu with 'Profil Admin', 'Pengaturan',
///      divider, and 'Keluar' (logout).
class AdminTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Name of the authenticated admin user.
  final String adminName;

  /// Email address of the authenticated admin user.
  final String adminEmail;

  /// Whether dark mode is currently active.
  final bool isDarkMode;

  /// Callback executed when toggling dark/light theme mode.
  final VoidCallback onThemeToggle;

  /// Callback executed when the user clicks 'Keluar' (logout).
  final VoidCallback onLogout;

  /// Callback executed when the mobile hamburger button is tapped.
  final VoidCallback? onMenuToggle;

  /// Connection status to the server / MQTT broker. Defaults to true.
  final bool isOnline;

  /// Optional callback executed when 'Profil Admin' is selected.
  final VoidCallback? onProfileTap;

  /// Optional callback executed when 'Pengaturan' is selected.
  final VoidCallback? onSettingsTap;

  /// Optional explicit route path (overrides GoRouterState if provided).
  final String? currentPath;

  const AdminTopBar({
    super.key,
    required this.adminName,
    required this.adminEmail,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.onLogout,
    this.onMenuToggle,
    this.isOnline = true,
    this.onProfileTap,
    this.onSettingsTap,
    this.currentPath,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68.0);

  /// Resolves the current URI path either from [currentPath], [GoRouterState],
  /// or [ModalRoute].
  String _resolveCurrentPath(BuildContext context) {
    if (currentPath != null && currentPath!.isNotEmpty) {
      return currentPath!;
    }
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute?.settings.name != null &&
          modalRoute!.settings.name!.isNotEmpty) {
        return modalRoute.settings.name!;
      }
      return '/admin/overview';
    }
  }

  /// Converts a URL path string into structured [BreadcrumbItem] segments.
  List<BreadcrumbItem> _buildBreadcrumbs(String rawPath) {
    final cleanPath = rawPath.trim();
    final segments = cleanPath.split('/').where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) {
      return const [
        BreadcrumbItem(title: 'Admin', path: '/admin'),
        BreadcrumbItem(title: 'Overview', path: '/admin', isLast: true),
      ];
    }

    final List<BreadcrumbItem> items = [];

    // Ensure 'Admin' is always the root crumb in the admin portal
    if (segments.first.toLowerCase() != 'admin') {
      items.add(const BreadcrumbItem(title: 'Admin', path: '/admin'));
    }

    String accumulatedPath = '';
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      accumulatedPath += '/$segment';
      final isLast = i == segments.length - 1;
      items.add(BreadcrumbItem(
        title: _formatSegmentTitle(segment),
        path: accumulatedPath,
        isLast: isLast,
      ));
    }

    // If only root 'Admin' exists, append 'Overview' as the active destination
    if (items.length == 1 && items.first.title.toLowerCase() == 'admin') {
      items.add(const BreadcrumbItem(
        title: 'Overview',
        path: '/admin',
        isLast: true,
      ));
    }

    return items;
  }

  /// Formats raw route segment strings into clean, user-facing Indonesian titles.
  String _formatSegmentTitle(String segment) {
    final lower = segment.toLowerCase();
    switch (lower) {
      case 'admin':
        return 'Admin';
      case 'overview':
      case 'dashboard':
        return 'Overview';
      case 'monitoring':
      case 'monitoring-lahan':
      case 'lahan':
      case 'demplot':
        return 'Monitoring Lahan';
      case 'devices':
      case 'perangkat':
      case 'iot':
        return 'Perangkat IoT';
      case 'analytics':
      case 'analitik':
      case 'telemetry':
      case 'telemetri':
        return 'Analitik';
      case 'alerts':
      case 'peringatan':
      case 'notifikasi':
      case 'notifications':
        return 'Peringatan';
      case 'control':
      case 'kontrol':
      case 'pompa':
      case 'irrigation':
        return 'Kontrol Pompa & Pupuk';
      case 'settings':
      case 'pengaturan':
        return 'Pengaturan';
      case 'profile':
      case 'profil':
        return 'Profil Admin';
      case 'users':
      case 'pengguna':
        return 'Manajemen Pengguna';
      case 'reports':
      case 'laporan':
        return 'Laporan';
      case 'logs':
      case 'log':
      case 'activity-logs':
      case 'log-aktivitas':
        return 'Log Aktivitas Sistem';
      default:
        return segment
            .replaceAll(RegExp(r'[-_]'), ' ')
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w.length > 1
                ? '${w[0].toUpperCase()}${w.substring(1)}'
                : w.toUpperCase())
            .join(' ');
    }
  }

  /// Extracts the initial character from the given name string.
  String _getInitial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'A';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bool effectiveIsDark =
        isDarkMode || Theme.of(context).brightness == Brightness.dark;
    final bool isMobile = ResponsiveLayout.isMobile(context);
    final String currentPathStr = _resolveCurrentPath(context);
    final List<BreadcrumbItem> breadcrumbs = _buildBreadcrumbs(currentPathStr);

    final Color bgColor =
        effectiveIsDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final Color borderColor =
        effectiveIsDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      height: preferredSize.height,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: AppTheme.getSoftShadow(effectiveIsDark),
      ),
      child: Row(
        children: [
          // Left: Dynamic Breadcrumbs or Mobile Hamburger
          Expanded(
            child: isMobile
                ? _buildMobileLeading(context, breadcrumbs, effectiveIsDark)
                : _buildBreadcrumbsView(context, breadcrumbs, effectiveIsDark),
          ),

          const SizedBox(width: 12),

          // Right: Actions (Theme Toggle, Server Status, User Avatar & Menu)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Theme Toggle (Sun / Moon)
              _buildThemeToggle(context, effectiveIsDark),

              const SizedBox(width: 8),

              // Server Status Pill (Online / Offline)
              _buildServerStatusPill(context, effectiveIsDark),

              const SizedBox(width: 8),

              // Dedicated Logout Button for quick access
              if (!isMobile) ...[
                Tooltip(
                  message: 'Keluar ke Beranda',
                  child: IconButton(
                    onPressed: onLogout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: AppColors.dangerRose,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: effectiveIsDark
                          ? AppColors.dangerRose.withValues(alpha: 0.12)
                          : const Color(0xFFFEE2E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Admin User Avatar & Popup Menu
              _buildUserMenu(context, effectiveIsDark),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the desktop / tablet breadcrumb path display.
  Widget _buildBreadcrumbsView(
    BuildContext context,
    List<BreadcrumbItem> breadcrumbs,
    bool isDark,
  ) {
    final Color textColor =
        isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final Color mutedColor =
        isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primaryAccent.withValues(alpha: 0.15)
                : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.admin_panel_settings_rounded,
            size: 18,
            color: isDark ? AppColors.primaryAccent : AppColors.primaryEmerald,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < breadcrumbs.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  _BreadcrumbChip(
                    item: breadcrumbs[i],
                    isDark: isDark,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the mobile leading widget with a hamburger button and active screen title.
  Widget _buildMobileLeading(
    BuildContext context,
    List<BreadcrumbItem> breadcrumbs,
    bool isDark,
  ) {
    final String currentTitle =
        breadcrumbs.isNotEmpty ? breadcrumbs.last.title : 'Admin';
    final Color textColor =
        isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onMenuToggle,
          icon: Icon(
            Icons.menu_rounded,
            color: textColor,
            size: 22,
          ),
          tooltip: 'Buka Menu Navigasi',
          style: IconButton.styleFrom(
            backgroundColor:
                isDark ? AppColors.elevatedDark : const Color(0xFFF1F5F9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(8),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            currentTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Builds the animated dark/light mode toggle capsule switch.
  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    return Tooltip(
      message: isDarkMode ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
      child: InkWell(
        onTap: onThemeToggle,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Light (Sun) Icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !isDarkMode ? Colors.white : Colors.transparent,
                  boxShadow: !isDarkMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.wb_sunny_rounded,
                  size: 16,
                  color: !isDarkMode
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 2),
              // Dark (Moon) Icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode
                      ? AppColors.primaryAccent
                      : Colors.transparent,
                  boxShadow: isDarkMode
                      ? [
                          BoxShadow(
                            color:
                                AppColors.primaryAccent.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.nightlight_round,
                  size: 15,
                  color: isDarkMode ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the server status indicator pill (Online / Offline).
  Widget _buildServerStatusPill(BuildContext context, bool isDark) {
    final bool online = isOnline;
    final Color bgColor = online
        ? (isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.6)
            : const Color(0xFFDCFCE7))
        : (isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.6)
            : const Color(0xFFFEE2E2));
    final Color borderColor = online
        ? (isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC))
        : (isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA));
    final Color dotColor =
        online ? const Color(0xFF16A34A) : const Color(0xFFEF4444);
    final Color textColor = online
        ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
        : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626));
    final String label = online ? 'Online' : 'Offline';

    final bool isMobile = ResponsiveLayout.isMobile(context);

    return Tooltip(
      message: online
          ? 'Status Server: Online (Terhubung)'
          : 'Status Server: Offline (Terputus)',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            if (!isMobile || MediaQuery.sizeOf(context).width > 400) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the admin user avatar and interactive dropdown menu.
  Widget _buildUserMenu(BuildContext context, bool isDark) {
    final bool isMobile = ResponsiveLayout.isMobile(context);
    final Color textColor =
        isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final Color mutedColor =
        isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;
    final Color popupBg = isDark ? AppColors.surfaceDark : Colors.white;
    final String initial = _getInitial(adminName);

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      elevation: 6,
      color: popupBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            if (onProfileTap != null) {
              onProfileTap!();
            } else {
              try {
                context.go('/admin/profile');
              } catch (_) {}
            }
            break;
          case 'settings':
            if (onSettingsTap != null) {
              onSettingsTap!();
            } else {
              try {
                context.go('/admin/settings');
              } catch (_) {}
            }
            break;
          case 'logout':
            onLogout();
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        // Header Info Item with Admin Name and Email
        PopupMenuItem<String>(
          enabled: false,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _buildAvatar(initial, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        adminName.isNotEmpty ? adminName : 'Admin AgriMotion',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        adminEmail.isNotEmpty
                            ? adminEmail
                            : 'admin@agrimotion.id',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: mutedColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: isDark
                    ? AppColors.textDarkSecondary
                    : const Color(0xFF475569),
              ),
              const SizedBox(width: 12),
              Text(
                'Profil Admin',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(
                Icons.settings_outlined,
                size: 18,
                color: isDark
                    ? AppColors.textDarkSecondary
                    : const Color(0xFF475569),
              ),
              const SizedBox(width: 12),
              Text(
                'Pengaturan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: const [
              Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.dangerRose,
              ),
              SizedBox(width: 12),
              Text(
                'Keluar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dangerRose,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 4 : 10,
          vertical: isMobile ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.elevatedDark.withValues(alpha: 0.5)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(initial, radius: 15),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      adminName.isNotEmpty ? adminName : 'Admin',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Administrator',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: mutedColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: mutedColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds a circular avatar showing the first letter of the user name with gradient fill.
  Widget _buildAvatar(String initial, {double radius = 16}) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryEmerald.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Helper chip widget for rendering individual breadcrumb items.
class _BreadcrumbChip extends StatelessWidget {
  final BreadcrumbItem item;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;

  const _BreadcrumbChip({
    required this.item,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    if (item.isLast) {
      return Text(
        item.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: -0.1,
        ),
      );
    }

    return InkWell(
      onTap: () {
        try {
          context.go(item.path);
        } catch (_) {}
      },
      borderRadius: BorderRadius.circular(6),
      hoverColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : AppColors.primaryLight.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          item.title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: mutedColor,
          ),
        ),
      ),
    );
  }
}

/// Type alias for [AdminTopBar] providing clean backward and interchangeable compatibility.
typedef TopBar = AdminTopBar;
