import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import 'widgets/web_sidebar.dart';
import 'widgets/top_app_bar.dart';
import '../dashboard/dashboard_view.dart';
import '../analytics/analytics_view.dart';
import '../alerts/alerts_view.dart';
import '../settings/settings_view.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardView(),
    const AnalyticsView(),
    const AlertsView(),
    const SettingsView(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      desktop: Scaffold(
        body: Row(
          children: [
            WebSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: _onItemTapped,
            ),
            Expanded(
              child: Column(
                children: [
                  const TopAppBar(),
                  Expanded(child: _pages[_selectedIndex]),
                ],
              ),
            ),
          ],
        ),
      ),
      mobile: Scaffold(
        body: SafeArea(child: _pages[_selectedIndex]),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard'),
            BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                activeIcon: Icon(Icons.analytics),
                label: 'Analytics'),
            BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
