import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agrimotion/core/constants/app_constants.dart';
import 'package:agrimotion/core/theme/colors.dart';

/// Connection status states for the AgriMotion IoT platform.
enum ConnectionStatus {
  /// System is connected and receiving real-time telemetry.
  online('Online', AppColors.optimalGreen),

  /// System has lost connection to server/broker.
  offline('Offline', AppColors.dangerRose);

  /// Human-readable label in Indonesian / English.
  final String label;

  /// Semantic indicator color.
  final Color color;

  const ConnectionStatus(this.label, this.color);
}

/// Navigation item definition for sidebar items.
class _SidebarItemData {
  final String title;
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final bool hasBadge;

  const _SidebarItemData({
    required this.title,
    required this.route,
    required this.icon,
    required this.activeIcon,
    this.hasBadge = false,
  });
}

/// Responsive collapsible Admin Sidebar navigation widget for AgriMotion.
///
/// Features:
/// - Smooth collapsible/expandable width animation (260px expanded ↔ 72px collapsed)
/// - Brand header with leaf icon and 'AgriMotion' typography
/// - Navigation items with active state highlighting via [GoRouterState]
/// - Notification counter badge on "Peringatan" item
/// - Real-time connection status indicator (Online / Offline / Mock Mode)
/// - Integrated collapse/expand toggle button
/// - Full Material 3 dark and light theme adaptability
class AdminSidebar extends StatefulWidget {
  /// Optional unread alerts count to show on the "Peringatan" navigation item.
  final int? alertCount;

  /// Controlled collapse state. If null, the sidebar manages its own state.
  final bool? isCollapsed;

  /// Initial collapse state when not controlled externally. Defaults to `false`.
  final bool initiallyCollapsed;

  /// Callback fired when the user toggles the collapse/expand button.
  final ValueChanged<bool>? onCollapseChanged;

  /// Connection status to display at the footer. Defaults to [ConnectionStatus.online].
  final ConnectionStatus connectionStatus;

  /// Optional route override for testing or previews without an active [GoRouter].
  final String? currentRouteOverride;

  const AdminSidebar({
    super.key,
    this.alertCount,
    this.isCollapsed,
    this.initiallyCollapsed = false,
    this.onCollapseChanged,
    this.connectionStatus = ConnectionStatus.online,
    this.currentRouteOverride,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  late bool _isCollapsedInternal;

  /// Duration for smooth expanding/collapsing animations.
  static const Duration _animationDuration = Duration(milliseconds: 250);

  /// Curve for smooth easing.
  static const Curve _animationCurve = Curves.easeInOutCubic;

  /// Navigation items list configuration.
  static const List<_SidebarItemData> _navItems = [
    _SidebarItemData(
      title: 'Overview',
      route: '/admin/overview',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
    ),
    _SidebarItemData(
      title: 'Monitoring Lahan',
      route: '/admin/farms',
      icon: Icons.eco_outlined,
      activeIcon: Icons.eco_rounded,
    ),
    _SidebarItemData(
      title: 'Peringatan',
      route: '/admin/alerts',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications_rounded,
      hasBadge: true,
    ),
    _SidebarItemData(
      title: 'Kader Digital',
      route: '/admin/users',
      icon: Icons.people_outlined,
      activeIcon: Icons.people_rounded,
    ),
    _SidebarItemData(
      title: 'Server Monitor',
      route: '/admin/server-monitor',
      icon: Icons.terminal_outlined,
      activeIcon: Icons.terminal_rounded,
    ),
    _SidebarItemData(
      title: 'Log Aktivitas',
      route: '/admin/activity-logs',
      icon: Icons.history_rounded,
      activeIcon: Icons.manage_history_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _isCollapsedInternal = widget.initiallyCollapsed;
  }

  bool get _isCollapsed => widget.isCollapsed ?? _isCollapsedInternal;

  void _toggleCollapse() {
    final nextState = !_isCollapsed;
    if (widget.isCollapsed == null) {
      setState(() {
        _isCollapsedInternal = nextState;
      });
    }
    widget.onCollapseChanged?.call(nextState);
  }

  String _getCurrentLocation(BuildContext context) {
    if (widget.currentRouteOverride != null) {
      return widget.currentRouteOverride!;
    }
    try {
      return GoRouterState.of(context).uri.path;
    } catch (_) {
      return '/admin/overview';
    }
  }

  bool _isRouteActive(String currentPath, String itemRoute) {
    if (currentPath == itemRoute) return true;
    if (itemRoute != '/admin' &&
        itemRoute != '/' &&
        currentPath.startsWith('$itemRoute/')) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPath = _getCurrentLocation(context);
    final targetWidth = _isCollapsed
        ? AppConstants.sidebarCollapsedWidth
        : AppConstants.sidebarExpandedWidth;

    final backgroundColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return AnimatedContainer(
      duration: _animationDuration,
      curve: _animationCurve,
      width: targetWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          right: BorderSide(
            color: borderColor,
            width: 1.0,
          ),
        ),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: AppConstants.sidebarCollapsedWidth,
          maxWidth: AppConstants.sidebarExpandedWidth,
          child: SizedBox(
            width: targetWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Brand / Logo Header
                _buildBrandingHeader(isDark),

                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 12),

                // Navigation Items List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _navItems.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = _navItems[index];
                      final isActive = _isRouteActive(currentPath, item.route);
                      return _buildNavItem(
                        context: context,
                        item: item,
                        isActive: isActive,
                        isDark: isDark,
                      );
                    },
                  ),
                ),

                // Collapse / Expand Toggle Button
                _buildCollapseToggleButton(isDark),

                const SizedBox(height: 6),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
                ),

                // Connection Status Footer Indicator
                _buildConnectionStatusFooter(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BRANDING HEADER
  // ===========================================================================

  Widget _buildBrandingHeader(bool isDark) {
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(
        horizontal: _isCollapsed ? 14 : 18,
        vertical: 14,
      ),
      child: Row(
        mainAxisAlignment:
            _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          // Logo Icon Container
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/logo.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.eco_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // Animated Brand Title
          if (!_isCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedOpacity(
                duration: _animationDuration,
                opacity: _isCollapsed ? 0.0 : 1.0,
                child: Text(
                  'AGRI-MOTION',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark
                        ? AppColors.textDarkPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // NAVIGATION ITEM
  // ===========================================================================

  Widget _buildNavItem({
    required BuildContext context,
    required _SidebarItemData item,
    required bool isActive,
    required bool isDark,
  }) {
    final unselectedColor =
        isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;
    final activeTextColor =
        isDark ? AppColors.primaryAccent : AppColors.primaryEmerald;
    final activeBgColor = isDark
        ? AppColors.primaryAccent.withValues(alpha: 0.15)
        : AppColors.primaryLight;

    final hasBadge =
        item.hasBadge && widget.alertCount != null && widget.alertCount! > 0;
    final badgeCount = widget.alertCount ?? 0;
    final badgeText = badgeCount > 99 ? '99+' : '$badgeCount';

    Widget iconWidget = Icon(
      isActive ? item.activeIcon : item.icon,
      size: 21,
      color: isActive ? activeTextColor : unselectedColor,
    );

    // If collapsed and has badge, overlay a small counter badge on the icon
    if (_isCollapsed && hasBadge) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.dangerRose,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                badgeText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final itemWidget = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.go(item.route);
        },
        borderRadius: BorderRadius.circular(10),
        hoverColor: isDark
            ? AppColors.elevatedDark.withValues(alpha: 0.4)
            : AppColors.primaryLight.withValues(alpha: 0.4),
        splashColor: isDark
            ? AppColors.primaryAccent.withValues(alpha: 0.1)
            : AppColors.primaryEmerald.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          padding: EdgeInsets.symmetric(
            horizontal: _isCollapsed ? 0 : 12,
          ),
          decoration: BoxDecoration(
            color: isActive ? activeBgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive && isDark
                ? Border.all(
                    color: AppColors.primaryAccent.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: _isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              // Icon
              SizedBox(
                width: 28,
                height: 28,
                child: Center(child: iconWidget),
              ),

              // Title and Badge (when expanded)
              if (!_isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive
                          ? (isDark
                              ? AppColors.textDarkPrimary
                              : activeTextColor)
                          : unselectedColor,
                    ),
                  ),
                ),
                if (hasBadge) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerRose,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.dangerRose.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );

    // Show tooltip in collapsed mode for enhanced UX
    if (_isCollapsed) {
      return Tooltip(
        message: hasBadge ? '${item.title} ($badgeText)' : item.title,
        waitDuration: const Duration(milliseconds: 300),
        preferBelow: false,
        verticalOffset: 0,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        textStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        child: itemWidget,
      );
    }

    return itemWidget;
  }

  // ===========================================================================
  // COLLAPSE / EXPAND TOGGLE BUTTON
  // ===========================================================================

  Widget _buildCollapseToggleButton(bool isDark) {
    final hoverColor = isDark
        ? AppColors.elevatedDark.withValues(alpha: 0.5)
        : const Color(0xFFF1F5F9);
    final iconColor =
        isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;

    final toggleContent = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleCollapse,
        borderRadius: BorderRadius.circular(10),
        hoverColor: hoverColor,
        child: Container(
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: EdgeInsets.symmetric(
            horizontal: _isCollapsed ? 0 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: _isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              AnimatedRotation(
                duration: _animationDuration,
                curve: _animationCurve,
                turns: _isCollapsed ? 0.5 : 0.0,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: iconColor,
                ),
              ),
              if (!_isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ciutkan Menu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (_isCollapsed) {
      return Tooltip(
        message: 'Perluas Sidebar',
        waitDuration: const Duration(milliseconds: 300),
        preferBelow: false,
        child: toggleContent,
      );
    }

    return toggleContent;
  }

  // ===========================================================================
  // CONNECTION STATUS FOOTER
  // ===========================================================================

  Widget _buildConnectionStatusFooter(bool isDark) {
    final status = widget.connectionStatus;
    final dotColor = status.color;
    final cardBgColor =
        isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC);
    final cardBorderColor =
        isDark ? AppColors.borderDark : const Color(0xFFE2E8F0);

    final statusWidget = Container(
      margin: EdgeInsets.all(_isCollapsed ? 10 : 14),
      padding: EdgeInsets.symmetric(
        horizontal: _isCollapsed ? 8 : 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorderColor, width: 1),
      ),
      child: _isCollapsed
          ? Center(
              child: _buildStatusDot(dotColor),
            )
          : Row(
              children: [
                _buildStatusDot(dotColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textDarkPrimary
                              : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'v${AppConstants.version}',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textDarkSecondary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'IoT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: dotColor,
                    ),
                  ),
                ),
              ],
            ),
    );

    if (_isCollapsed) {
      return Tooltip(
        message: 'Status Koneksi: ${status.label} (v${AppConstants.version})',
        waitDuration: const Duration(milliseconds: 300),
        preferBelow: false,
        child: statusWidget,
      );
    }

    return statusWidget;
  }

  /// Builds the glowing connection status dot indicator.
  Widget _buildStatusDot(Color dotColor) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dotColor,
        boxShadow: [
          BoxShadow(
            color: dotColor.withValues(alpha: 0.45),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Convenience alias for [AdminSidebar].
typedef Sidebar = AdminSidebar;
