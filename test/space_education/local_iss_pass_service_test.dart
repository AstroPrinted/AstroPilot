import 'package:astroprintedlogicincludedgeoengine/features/space_education/data/local_iss_pass_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'returns offline placeholder when orbital data is unavailable',
    () async {
      final result = await const LocalIssPassService().getUpcomingIssPasses(
        latitude: -33.45,
        longitude: -70.66,
        from: DateTime.utc(2026, 6, 7, 21),
      );

      expect(result.hasFreshOrbitalData, isFalse);
      expect(result.passes, isEmpty);
      expect(result.message, contains('datos orbitales actualizados'));
    },
  );
}
