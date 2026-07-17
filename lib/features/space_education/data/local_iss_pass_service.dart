import '../domain/models/iss_pass.dart';
import '../domain/services/iss_pass_service.dart';

class LocalIssPassService implements IssPassService {
  const LocalIssPassService();

  @override
  Future<IssPassResult> getUpcomingIssPasses({
    required double latitude,
    required double longitude,
    required DateTime from,
  }) async {
    return const IssPassResult(
      passes: [],
      hasFreshOrbitalData: false,
      message:
          'No hay datos orbitales actualizados disponibles. Puedes seguir leyendo información educativa, pero los próximos pasos de la ISS requieren datos actualizados.',
    );
  }
}
