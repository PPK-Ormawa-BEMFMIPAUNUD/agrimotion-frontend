import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class WebSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const WebSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Agri Motion",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor)),
                Text("Precision IoT",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sidebarItem(Icons.dashboard, "Dashboard", 0),
          _sidebarItem(Icons.analytics, "Analytics", 1),
          _sidebarItem(Icons.notifications, "Alerts", 2),
          _sidebarItem(Icons.settings, "Settings", 3),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String title, int index) {
    final isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => onItemSelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(
                  left: BorderSide(color: AppTheme.primaryColor, width: 4))
              : null,
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.primaryColor : Colors.grey[600]),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
