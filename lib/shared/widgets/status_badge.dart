import 'package:flutter/material.dart';
import 'package:agrimotion/core/constants/app_constants.dart';

/// Reusable status badge widget that displays sensor or system status
/// with appropriate color coding and styling.
class StatusBadge extends StatelessWidget {
  final SensorStatus status;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11,
    this.padding,
  });

  /// Creates a badge from a custom label and color.
  factory StatusBadge.custom({
    Key? key,
    required String label,
    required Color color,
    double fontSize = 11,
  }) {
    return _CustomStatusBadge(
      key: key,
      label: label,
      color: color,
      fontSize: fontSize,
    );
  }

  Color get _backgroundColor {
    switch (status) {
      case SensorStatus.optimal:
        return const Color(0xFF16A34A).withValues(alpha: 0.1);
      case SensorStatus.warning:
        return const Color(0xFFF59E0B).withValues(alpha: 0.1);
      case SensorStatus.danger:
        return const Color(0xFFEF4444).withValues(alpha: 0.1);
      case SensorStatus.offline:
        return const Color(0xFF64748B).withValues(alpha: 0.1);
      case SensorStatus.unknown:
        return const Color(0xFF94A3B8).withValues(alpha: 0.1);
    }
  }

  Color get _textColor {
    switch (status) {
      case SensorStatus.optimal:
        return const Color(0xFF15803D);
      case SensorStatus.warning:
        return const Color(0xFFB45309);
      case SensorStatus.danger:
        return const Color(0xFFDC2626);
      case SensorStatus.offline:
        return const Color(0xFF475569);
      case SensorStatus.unknown:
        return const Color(0xFF64748B);
    }
  }

  IconData get _icon {
    switch (status) {
      case SensorStatus.optimal:
        return Icons.check_circle;
      case SensorStatus.warning:
        return Icons.warning_amber_rounded;
      case SensorStatus.danger:
        return Icons.error;
      case SensorStatus.offline:
        return Icons.wifi_off;
      case SensorStatus.unknown:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: fontSize + 1, color: _textColor),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: _textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom status badge with arbitrary label and color.
class _CustomStatusBadge extends StatusBadge {
  final String label;
  final Color color;

  const _CustomStatusBadge({
    super.key,
    required this.label,
    required this.color,
    super.fontSize,
  }) : super(status: SensorStatus.unknown);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
