import '../models/iss_pass.dart';

abstract class IssPassService {
  Future<IssPassResult> getUpcomingIssPasses({
    required double latitude,
    required double longitude,
    required DateTime from,
  });
}
