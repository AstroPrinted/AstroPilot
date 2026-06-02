import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/calibration_result.dart';

class CalibrationStorage {
  static const _currentCalibrationKey = 'astropilot.calibration.current';

  Future<CalibrationResult?> loadCurrentResult() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentCalibrationKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return CalibrationResult.fromJson(decoded);
    } catch (error) {
      debugPrint('[Calibration] Stored estimated correction ignored: $error');
      return null;
    }
  }

  Future<void> saveCurrentResult(CalibrationResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentCalibrationKey, jsonEncode(result.toJson()));
  }

  Future<void> clearCurrentResult() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentCalibrationKey);
  }
}
