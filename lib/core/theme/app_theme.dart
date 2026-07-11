import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0F5A34);
  static const Color backgroundColor = Color(0xFFF4F7F6);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        surface: Colors.white,
      ),
      fontFamily: 'Roboto',
    );
  }
}
