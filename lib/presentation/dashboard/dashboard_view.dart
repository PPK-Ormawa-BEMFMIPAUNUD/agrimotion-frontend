import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSystemStatus(),
          const SizedBox(height: 24),
          _buildKpiCards(),
          const SizedBox(height: 24),
          _buildBottomArea(),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  text: 'System Status: ',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.w500),
                  children: [
                    TextSpan(
                        text: 'Optimal',
                        style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold))
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                  "All 24 sensor nodes are currently online and transmitting data.",
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16)),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 10),
                    SizedBox(width: 6),
                    Text("ONLINE",
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16)),
                child: const Text("LAST SYNC: JUST NOW",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildKpiCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final cardWidth =
            isWide ? (constraints.maxWidth / 3) - 16 : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _kpiCard(cardWidth, "AVG SOIL MOISTURE", "42%",
                "+2.4% vs last week", Icons.water_drop_outlined, true),
            _kpiCard(cardWidth, "FIELD TEMP", "24°C", "Stable",
                Icons.thermostat_outlined, false),
            _kpiCard(cardWidth, "SOIL PH LEVEL", "6.8", "Optimal Range",
                Icons.science_outlined, true),
          ],
        );
      },
    );
  }

  Widget _kpiCard(double width, String title, String value, String subtitle,
      IconData icon, bool isPositive) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              Icon(icon, color: AppTheme.primaryColor, size: 20)
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style:
                  const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(isPositive ? Icons.trending_up : Icons.horizontal_rule,
                  color: isPositive ? Colors.green : Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(subtitle,
                  style: TextStyle(
                      color: isPositive ? Colors.green : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildBarChartCard()),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: _buildAlertsAndMap()),
            ],
          );
        } else {
          return Column(children: [
            _buildBarChartCard(),
            const SizedBox(height: 24),
            _buildAlertsAndMap()
          ]);
        }
      },
    );
  }

  Widget _buildBarChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Moisture Trends (7 Days)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _barItem("Mon", 100),
                _barItem("Tue", 90),
                _barItem("Wed", 80),
                _barItem("Thu", 160),
                _barItem("Fri", 140),
                _barItem("Sat", 120),
                _barItem("Sun", 110),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barItem(String day, double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
            width: 40,
            height: height,
            decoration: const BoxDecoration(
                color: Color(0xFF32704E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)))),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildAlertsAndMap() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!)),
          child: const Center(child: Text("Recent Alerts Placeholder")),
        ),
      ],
    );
  }
}
