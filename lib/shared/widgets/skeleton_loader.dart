import 'package:flutter/material.dart';

/// Shimmer / skeleton loading placeholder widgets for async data states.
///
/// Provides a pulsating animation effect while data is being loaded.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: isDark
                ? Color.lerp(
                    const Color(0xFF1E293B),
                    const Color(0xFF334155),
                    _animation.value,
                  )
                : Color.lerp(
                    const Color(0xFFE2E8F0),
                    const Color(0xFFF1F5F9),
                    _animation.value,
                  ),
          ),
        );
      },
    );
  }
}

/// Skeleton card mimicking a MetricCard during loading.
class SkeletonMetricCard extends StatelessWidget {
  final double? width;

  const SkeletonMetricCard({super.key, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonLoader(width: 100, height: 12),
              SkeletonLoader(width: 28, height: 28, borderRadius: 8),
            ],
          ),
          SizedBox(height: 16),
          SkeletonLoader(width: 80, height: 32),
          SizedBox(height: 16),
          SkeletonLoader(width: 120, height: 12),
        ],
      ),
    );
  }
}

/// Skeleton row for data table loading.
class SkeletonTableRow extends StatelessWidget {
  final int columns;

  const SkeletonTableRow({super.key, this.columns = 6});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: List.generate(
          columns,
          (index) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SkeletonLoader(
                height: 14,
                width: index == 0 ? 120 : 60,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton chart placeholder.
class SkeletonChart extends StatelessWidget {
  final double height;

  const SkeletonChart({super.key, this.height = 280});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: 180, height: 18),
          SizedBox(height: 8),
          SkeletonLoader(width: 240, height: 14),
          SizedBox(height: 24),
          Expanded(child: SkeletonLoader(height: double.infinity)),
        ],
      ),
    );
  }
}
