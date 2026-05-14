import 'package:flutter/material.dart';

class AppTheme {
  static const _background = Color(0xFF0B0B10);
  static const _surface = Color(0xFF151520);
  static const _surfaceAlt = Color(0xFF1D2333);
  static const _primary = Color(0xFF3B82F6);
  static const _secondary = Color(0xFF22D3EE);
  static const _onPrimary = Color(0xFFF8FAFC);
  static const _error = Color(0xFFEF4444);
  static const _textPrimary = Color(0xFFF8FAFC);
  static const _textSecondary = Color(0xFF94A3B8);

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _background,
    colorScheme: ColorScheme.dark(
      surface: _surface,
      surfaceContainerHighest: _surfaceAlt,
      primary: _primary,
      secondary: _secondary,
      onPrimary: _onPrimary,
      error: _error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _surface,
      foregroundColor: _textPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    chipTheme: ChipThemeData(
      selectedColor: _primary.withValues(alpha: 0.25),
      side: BorderSide(color: _textSecondary.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: const TextStyle(
        color: _textPrimary,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _textSecondary.withValues(alpha: 0.1)),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: _textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: _textSecondary),
      bodySmall: TextStyle(color: _textSecondary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _surface,
      selectedItemColor: _primary,
      unselectedItemColor: _textSecondary,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
