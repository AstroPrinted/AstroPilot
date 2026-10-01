import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ApColors.background,
    colorScheme: const ColorScheme.dark(
      surface: ApColors.surface,
      surfaceContainerHighest: ApColors.surface2Solid,
      primary: ApColors.primary,
      secondary: ApColors.secondary,
      onPrimary: ApColors.text,
      error: ApColors.error,
      outline: ApColors.outline,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ApColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ApColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: ApColors.text,
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: ApColors.primary.withValues(alpha: 0.25),
      side: const BorderSide(color: ApColors.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: const TextStyle(
        color: ApColors.text,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    cardTheme: CardThemeData(
      color: ApColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ApColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ApColors.surface2,
      labelStyle: const TextStyle(color: ApColors.muted),
      floatingLabelStyle: const TextStyle(color: ApColors.primary),
      helperStyle: const TextStyle(color: ApColors.muted, fontSize: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ApColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ApColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ApColors.primary, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : ApColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ApColors.primary
            : ApColors.surface2Solid,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ApColors.primary
            : ApColors.muted,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ApColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: const TextStyle(fontSize: 22, color: ApColors.text),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: ApColors.text,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(color: ApColors.text, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: ApColors.muted),
      bodySmall: TextStyle(color: ApColors.muted),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: ApColors.surface,
      selectedItemColor: ApColors.primary,
      unselectedItemColor: ApColors.muted,
      selectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 12),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
