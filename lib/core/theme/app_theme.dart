import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agrimotion/core/theme/colors.dart';

/// Complete Material 3 theme configuration for the AgriMotion IoT platform.
///
/// Provides both [lightTheme] (Emerald Green agriculture) and [darkTheme] (Slate dark),
/// along with backward-compatible static color constants and elevation shadows.
class AppTheme {
  AppTheme._();

  // ===========================================================================
  // Backward Compatibility - Static Color Constants
  // ===========================================================================

  /// Primary Emerald Green brand color.
  static const Color primaryColor = AppColors.primaryEmerald;

  /// Dark emerald shade for emphasis or headers.
  static const Color primaryDark = AppColors.primaryDark;

  /// Light emerald tint for backgrounds and badges.
  static const Color primaryLight = AppColors.primaryLight;

  /// Vibrant green accent for highlights and active states.
  static const Color primaryAccent = AppColors.primaryAccent;

  /// Forest green variant.
  static const Color forestGreen = AppColors.forestGreen;

  /// Bright leaf green variant.
  static const Color leafGreen = AppColors.leafGreen;

  /// Secondary sky blue color for IoT / water / humidity metrics.
  static const Color secondaryColor = AppColors.secondary;

  /// Light secondary tint.
  static const Color secondaryLight = AppColors.secondaryLight;

  /// Default light scaffold background color.
  static const Color backgroundColor = AppColors.backgroundLight;

  /// Default light card / surface background color.
  static const Color cardColor = AppColors.surfaceLight;

  /// Dark mode background surface color.
  static const Color surfaceDark = AppColors.surfaceDark;

  /// Dark mode scaffold background color.
  static const Color backgroundDark = AppColors.backgroundDark;

  /// Dark mode card color.
  static const Color cardDark = AppColors.cardDark;

  /// Primary high-contrast text color (dark navy on light).
  static const Color textPrimary = AppColors.textPrimary;

  /// Secondary muted text color (slate grey on light).
  static const Color textSecondary = AppColors.textSecondary;

  /// Tertiary placeholder/disabled text color.
  static const Color textTertiary = AppColors.textTertiary;

  /// Primary text color for dark mode (light slate on dark).
  static const Color textDarkPrimary = AppColors.textDarkPrimary;

  /// Secondary text color for dark mode (muted slate on dark).
  static const Color textDarkSecondary = AppColors.textDarkSecondary;

  /// Default light border color.
  static const Color borderColor = AppColors.borderLight;

  /// Dark mode border color.
  static const Color borderDark = AppColors.borderDark;

  // Semantic Status Colors
  static const Color optimalGreen = AppColors.optimalGreen;
  static const Color warningAmber = AppColors.warningAmber;
  static const Color dangerRose = AppColors.dangerRose;
  static const Color infoBlue = AppColors.infoBlue;

  // Terminal Palette
  static const Color terminalBg = AppColors.terminalBg;
  static const Color terminalSurface = AppColors.terminalSurface;
  static const Color terminalBorder = AppColors.terminalBorder;
  static const Color terminalText = AppColors.terminalText;
  static const Color terminalGreen = AppColors.terminalGreen;
  static const Color terminalYellow = AppColors.terminalYellow;
  static const Color terminalRed = AppColors.terminalRed;
  static const Color terminalBlue = AppColors.terminalBlue;
  static const Color terminalCyan = AppColors.terminalCyan;
  static const Color terminalComment = AppColors.terminalComment;
  static const Color terminalPrompt = AppColors.terminalPrompt;

  // ===========================================================================
  // Gradients
  // ===========================================================================

  /// Vibrant primary gradient from deep emerald to vibrant green.
  static const LinearGradient primaryGradient = AppColors.primaryGradient;

  /// Extended hero header gradient.
  static const LinearGradient heroGradient = AppColors.heroGradient;

  /// Deep slate gradient for dark surfaces.
  static const LinearGradient darkGradient = AppColors.darkGradient;

  /// Gentle top-down tint for card headers.
  static const LinearGradient cardHeaderGradient = LinearGradient(
    colors: [Color(0xFFF0FDF4), Colors.white],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ===========================================================================
  // Shadows & Elevation Utilities
  // ===========================================================================

  /// Soft shadow for elevated surfaces, cards, and containers (Light mode default).
  static List<BoxShadow> get softShadow => getSoftShadow(false);

  /// Card shadow for floating elements and modal overlays (Light mode default).
  static List<BoxShadow> get cardShadow => getCardShadow(false);

  /// Soft shadow accepting [isDark] parameter to adapt to theme brightness.
  static List<BoxShadow> getSoftShadow([bool isDark = false]) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  /// Card shadow accepting [isDark] parameter to adapt to theme brightness.
  static List<BoxShadow> getCardShadow([bool isDark = false]) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.45)
              : const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  /// Utility method to get soft shadows with named parameter `isDark`.
  static List<BoxShadow> softShadows({bool isDark = false}) =>
      getSoftShadow(isDark);

  /// Utility method to get card shadows with named parameter `isDark`.
  static List<BoxShadow> cardShadows({bool isDark = false}) =>
      getCardShadow(isDark);

  // ===========================================================================
  // Light Theme
  // ===========================================================================

  /// Clean light theme with Emerald green primary and Inter typography.
  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;
    final interTextTheme = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    const lightColorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryEmerald,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryLight,
      onSecondaryContainer: Color(0xFF0C4A6E),
      tertiary: AppColors.optimalGreen,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFDCFCE7),
      onTertiaryContainer: Color(0xFF14532D),
      error: AppColors.dangerRose,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: Color(0xFFF1F5F9),
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderLight,
      outlineVariant: Color(0xFFE2E8F0),
      shadow: Color(0xFF0F172A),
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      primaryColor: AppColors.primaryEmerald,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: interTextTheme,
      dividerColor: AppColors.borderLight,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.borderLight,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          size: 20,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(
          color: AppColors.textTertiary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryEmerald, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dangerRose, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dangerRose, width: 2),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryEmerald,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryEmerald,
          side: const BorderSide(color: AppColors.borderLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryEmerald,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryEmerald,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          hoverColor: AppColors.primaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Data Table Theme
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.backgroundLight),
        dataRowColor: const WidgetStatePropertyAll(AppColors.surfaceLight),
        headingTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        dataTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        dividerThickness: 1,
        horizontalMargin: 16,
        columnSpacing: 24,
        headingRowHeight: 48,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        elevation: 8,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        elevation: 16,
        modalBackgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.borderLight,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundLight,
        selectedColor: AppColors.primaryLight,
        disabledColor: const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: const BorderSide(color: AppColors.borderLight, width: 1),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryEmerald,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryEmerald,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primaryEmerald,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.borderLight,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryEmerald,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Navigation Bar Theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        indicatorColor: AppColors.primaryLight,
        elevation: 2,
        shadowColor: AppColors.borderLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryEmerald,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryEmerald, size: 22);
          }
          return const IconThemeData(color: AppColors.textSecondary, size: 22);
        }),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryEmerald;
          }
          return const Color(0xFFE2E8F0);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryEmerald;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.borderLight, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryEmerald;
          }
          return AppColors.textSecondary;
        }),
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryEmerald,
        linearTrackColor: AppColors.primaryLight,
        circularTrackColor: AppColors.primaryLight,
      ),
    );
  }

  // ===========================================================================
  // Dark Theme
  // ===========================================================================

  /// Slate dark theme with vibrant emerald accents and Inter typography.
  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    final interTextTheme = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: AppColors.textDarkPrimary,
      displayColor: AppColors.textDarkPrimary,
    );

    const darkColorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primaryAccent,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryDark,
      onPrimaryContainer: AppColors.primaryLight,
      secondary: Color(0xFF38BDF8),
      onSecondary: Color(0xFF082F49),
      secondaryContainer: Color(0xFF075985),
      onSecondaryContainer: AppColors.secondaryLight,
      tertiary: AppColors.leafGreen,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF064E3B),
      onTertiaryContainer: Color(0xFF86EFAC),
      error: AppColors.dangerRose,
      onError: Colors.white,
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFECACA),
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDarkPrimary,
      surfaceContainerHighest: AppColors.elevatedDark,
      onSurfaceVariant: AppColors.textDarkSecondary,
      outline: AppColors.borderDark,
      outlineVariant: Color(0xFF475569),
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.primaryAccent,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: interTextTheme,
      dividerColor: AppColors.borderDark,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textDarkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textDarkPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textDarkPrimary,
          size: 20,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.textDarkSecondary,
          size: 20,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(
          color: AppColors.textDarkSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.inter(
          color: AppColors.textDarkSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: AppColors.textDarkSecondary,
        suffixIconColor: AppColors.textDarkSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dangerRose, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dangerRose, width: 2),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryAccent,
          side: const BorderSide(color: AppColors.borderDark, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textDarkSecondary,
          hoverColor: AppColors.elevatedDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Data Table Theme
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.backgroundDark),
        dataRowColor: const WidgetStatePropertyAll(AppColors.surfaceDark),
        headingTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDarkSecondary,
        ),
        dataTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textDarkPrimary,
        ),
        dividerThickness: 1,
        horizontalMargin: 16,
        columnSpacing: 24,
        headingRowHeight: 48,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDarkPrimary,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textDarkSecondary,
          height: 1.5,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        elevation: 16,
        modalBackgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.borderDark,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.elevatedDark,
        selectedColor: AppColors.primaryDark,
        disabledColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: const BorderSide(color: AppColors.borderDark, width: 1),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textDarkSecondary,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryAccent,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryAccent,
        unselectedLabelColor: AppColors.textDarkSecondary,
        indicatorColor: AppColors.primaryAccent,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.borderDark,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryAccent,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Navigation Bar Theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.primaryDark,
        elevation: 2,
        shadowColor: Colors.black,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryAccent,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textDarkSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryAccent, size: 22);
          }
          return const IconThemeData(color: AppColors.textDarkSecondary, size: 22);
        }),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.textDarkSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryAccent;
          }
          return AppColors.elevatedDark;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryAccent;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.borderDark, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryAccent;
          }
          return AppColors.textDarkSecondary;
        }),
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevatedDark,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textDarkPrimary,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.elevatedDark.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderDark, width: 1),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.textDarkPrimary,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryAccent,
        linearTrackColor: AppColors.primaryDark,
        circularTrackColor: AppColors.primaryDark,
      ),
    );
  }
}
