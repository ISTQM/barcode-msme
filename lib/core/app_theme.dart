import 'package:flutter/material.dart';

import 'brand_config.dart';

/// Mobbin-inspired Monochrome Theme System.
///
/// Built on high contrast, pitch blacks (#000000), stark whites (#FFFFFF),
/// and refined zinc neutral borders (#27272A / #E4E4E7).
/// Fully driven by [BrandConfig] for white-label adaptation.
class AppTheme {
  AppTheme._();

  static ThemeData light([BrandConfig config = BrandConfig.mobbinMonochrome]) =>
      _build(Brightness.light, config);

  static ThemeData dark([BrandConfig config = BrandConfig.mobbinMonochrome]) =>
      _build(Brightness.dark, config);

  static ThemeData _build(Brightness brightness, BrandConfig config) {
    final isDark = brightness == Brightness.dark;
    final palette = config.palette;
    final corners = config.cornerStyle;

    final background =
        isDark ? palette.backgroundDark : palette.backgroundLight;
    final surface = isDark ? palette.surfaceDark : palette.surfaceLight;
    final cardColor = isDark ? palette.cardDark : palette.cardLight;
    final borderColor = isDark ? palette.borderDark : palette.borderLight;
    final textPrimary =
        isDark ? palette.textPrimaryDark : palette.textPrimaryLight;
    final textSecondary =
        isDark ? palette.textSecondaryDark : palette.textSecondaryLight;
    final primary = isDark ? Colors.white : const Color(0xFF09090B);
    final onPrimary = isDark ? Colors.black : Colors.white;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
      onPrimaryContainer: textPrimary,
      secondary: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
      onSecondary: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerHighest:
          isDark ? const Color(0xFF1E1E22) : const Color(0xFFF4F4F5),
      surfaceContainer:
          isDark ? const Color(0xFF141416) : const Color(0xFFFFFFFF),
      error: const Color(0xFFEF4444),
      onError: Colors.white,
      outline: borderColor,
      outlineVariant:
          isDark ? const Color(0xFF1F1F23) : const Color(0xFFEDEDF0),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      cardColor: cardColor,
      dividerColor: borderColor,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor:
            isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? textPrimary : textSecondary,
            letterSpacing: 0.1,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
        hintStyle: TextStyle(
          color: textSecondary,
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 14.5,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: corners.mediumRadius,
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: corners.mediumRadius,
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: corners.mediumRadius,
          borderSide: BorderSide(color: textPrimary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: corners.mediumRadius,
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: corners.mediumRadius,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFF27272A) : const Color(0xFF18181B),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: corners.smallRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
        dragHandleColor: textSecondary.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: corners.sheetRadius,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: corners.mediumRadius,
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
    );
  }
}
