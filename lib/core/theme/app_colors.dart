import 'package:flutter/material.dart';

/// Tokens del sistema visual de AstroPilot (diseño "AstroPilot", Material 3
/// oscuro).
abstract final class ApColors {
  static const background = Color(0xFF0B0B10);
  static const surface = Color(0xFF151520);
  static const surface2 = Color(0x731D2333); // #1D2333 al 45 %
  static const surface2Solid = Color(0xFF1D2333);
  static const primary = Color(0xFF3B82F6);
  static const secondary = Color(0xFF22D3EE);
  static const error = Color(0xFFEF4444);
  static const warn = Color(0xFFF59E0B);
  static const ok = Color(0xFF22C55E);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const tip = Color(0xFFFACC15);
  static const border = Color(0x1A94A3B8); // muted al 10 %
  static const outline = Color(0x6694A3B8); // muted al 40 %
}

/// Tono de pills, avisos y badges.
enum ApTone {
  ok(ApColors.ok),
  info(ApColors.secondary),
  warn(ApColors.warn),
  error(ApColors.error),
  primary(ApColors.primary),
  muted(ApColors.muted);

  final Color color;
  const ApTone(this.color);
}

abstract final class ApText {
  static const mono = 'monospace';

  static const title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: ApColors.text,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    color: ApColors.muted,
  );
  static const small = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    color: ApColors.muted,
  );
  static const strong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: ApColors.text,
  );
  static const section = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: ApColors.muted,
  );
  static const number = TextStyle(
    fontFamily: mono,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
