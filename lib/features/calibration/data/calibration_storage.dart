import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/calibration_result.dart';

class CalibrationStorage {
  static const _currentCalibrationKey = 'astropilot.calibration.current';
  static const _initialAlignmentKey =
      'astropilot.calibration.initial_alignment';
  static const _correctionCalibrationKey = 'astropilot.calibration.correction';

  Future<CalibrationResult?> loadCurrentResult() async {
    return loadInitialAlignmentResult();
  }

  Future<CalibrationResult?> loadInitialAlignmentResult() async {
    final saved = await _loadResult(_initialAlignmentKey);
    if (saved != null && saved.isInitialAlignment) return saved;

    final legacy = await _loadResult(_currentCalibrationKey);
    if (legacy != null && legacy.isInitialAlignment) return legacy;
    return null;
  }

  Future<CalibrationResult?> loadCorrectionCalibrationResult() async {
    final saved = await _loadResult(_correctionCalibrationKey);
    if (saved != null && saved.isCorrectionCalibration) return saved;

    final legacy = await _loadResult(_currentCalibrationKey);
    if (legacy != null && legacy.isCorrectionCalibration) return legacy;
    return null;
  }

  Future<void> saveInitialAlignmentResult(CalibrationResult result) async {
    await _saveResult(_initialAlignmentKey, result);
    await _saveResult(_currentCalibrationKey, result);
  }

  Future<void> saveCorrectionCalibrationResult(CalibrationResult result) async {
    await _saveResult(_correctionCalibrationKey, result);
  }

  Future<void> clearInitialAlignmentResult() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_initialAlignmentKey);
    final legacy = await _loadResult(_currentCalibrationKey);
    if (legacy == null || legacy.isInitialAlignment) {
      await prefs.remove(_currentCalibrationKey);
    }
  }

  Future<void> clearCorrectionCalibrationResult() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_correctionCalibrationKey);
  }

  Future<CalibrationResult?> _loadResult(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
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
    if (result.isInitialAlignment) {
      await saveInitialAlignmentResult(result);
      return;
    }
    await saveCorrectionCalibrationResult(result);
  }

  Future<void> _saveResult(String key, CalibrationResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(result.toJson()));
  }

  Future<void> clearCurrentResult() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentCalibrationKey);
    await prefs.remove(_initialAlignmentKey);
    await prefs.remove(_correctionCalibrationKey);
  }
}
