import '../domain/models/calibration_result.dart';
import 'calibration_storage.dart';

class CalibrationRepository {
  final CalibrationStorage storage;

  const CalibrationRepository({required this.storage});

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
