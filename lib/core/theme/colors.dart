import 'package:flutter/material.dart';

/// AgriMotion color palette - Agriculture IoT themed.
///
/// Contains the complete design tokens for light and dark modes,
/// semantic statuses, agriculture emerald green branding, and terminal monitor styling.
class AppColors {
  AppColors._();

  // Primary Palette - Emerald Green Agriculture
  static const Color primaryEmerald = Color(0xFF0F7646);
  static const Color primaryDark = Color(0xFF0A5531);
  static const Color primaryLight = Color(0xFFE8F5EE);
  static const Color primaryAccent = Color(0xFF16A34A);
  static const Color forestGreen = Color(0xFF166534);
  static const Color leafGreen = Color(0xFF22C55E);

  // Secondary Palette
  static const Color secondary = Color(0xFF0284C7);
  static const Color secondaryLight = Color(0xFFE0F2FE);

  // Background & Surface
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color elevatedDark = Color(0xFF334155);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textDarkPrimary = Color(0xFFF1F5F9);
  static const Color textDarkSecondary = Color(0xFF94A3B8);

  // Border
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);

  // Semantic / Status Colors
  static const Color optimalGreen = Color(0xFF16A34A);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color dangerRose = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);

  // Terminal Palette (for server monitor)
  static const Color terminalBg = Color(0xFF0D1117);
  static const Color terminalSurface = Color(0xFF161B22);
  static const Color terminalBorder = Color(0xFF30363D);
  static const Color terminalText = Color(0xFFE6EDF3);
  static const Color terminalGreen = Color(0xFF3FB950);
  static const Color terminalYellow = Color(0xFFD29922);
  static const Color terminalRed = Color(0xFFF85149);
  static const Color terminalBlue = Color(0xFF58A6FF);
  static const Color terminalCyan = Color(0xFF39C5CF);
  static const Color terminalComment = Color(0xFF8B949E);
  static const Color terminalPrompt = Color(0xFF7EE787);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F7646), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF064E3B), Color(0xFF0F7646), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
