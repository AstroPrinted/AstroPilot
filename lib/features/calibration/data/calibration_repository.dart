import '../domain/models/calibration_result.dart';
import 'calibration_storage.dart';

class CalibrationRepository {
  final CalibrationStorage storage;

  const CalibrationRepository({required this.storage});

  Future<CalibrationResult?> loadInitialAlignmentResult() {
    return storage.loadInitialAlignmentResult();
  }

  Future<CalibrationResult?> loadCorrectionCalibrationResult() {
    return storage.loadCorrectionCalibrationResult();
  }

  Future<void> saveInitialAlignmentResult(CalibrationResult result) {
    return storage.saveInitialAlignmentResult(result);
  }

  Future<void> saveCorrectionCalibrationResult(CalibrationResult result) {
    return storage.saveCorrectionCalibrationResult(result);
  }

  Future<void> clearInitialAlignmentResult() {
    return storage.clearInitialAlignmentResult();
  }

  Future<void> clearCorrectionCalibrationResult() {
    return storage.clearCorrectionCalibrationResult();
  }

  Future<CalibrationResult?> loadCurrentResult() {
    return storage.loadCurrentResult();
  }

  Future<void> saveCurrentResult(CalibrationResult result) {
    return storage.saveCurrentResult(result);
  }

  Future<void> clearCurrentResult() {
    return storage.clearCurrentResult();
  }
}
