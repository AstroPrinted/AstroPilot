import '../../calibration/domain/services/astronomy_position_service.dart';
import '../../observation/domain/models/alt_az_result.dart';
import '../../observation/domain/models/observer_data.dart';
import '../../observation/domain/services/observer_data_provider.dart';
import '../../observation/domain/services/sun_guard.dart';
import '../data/repository/celestial_catalog_repository.dart';
import '../domain/models/celestial_object.dart';
import '../domain/models/visible_celestial_object.dart';

typedef CatalogObjectsProvider =
    Future<List<CelestialObject>> Function(String category);

typedef ObjectPositionResolver =
    AltAzResult Function(CelestialObject object, ObserverData observer);

class VisibleObjectsService {
  static const double horizonAltitudeDeg = 0.0;
  static const double nearHorizonAltitudeDeg = 5.0;

  final CelestialCatalogRepository catalogRepository;
  final ObserverDataProvider observerDataProvider;
  final AstronomyPositionService astronomyPositionService;
  final CatalogObjectsProvider? objectsProvider;
  final ObjectPositionResolver? positionResolver;

  /// Marca los objetos visibles que quedan cerca del Sol.
  final SunGuard? sunGuard;

  const VisibleObjectsService({
    required this.catalogRepository,
    required this.observerDataProvider,
    this.astronomyPositionService = const AstronomyPositionService(),
    this.objectsProvider,
    this.positionResolver,
    this.sunGuard,
  });

  Future<List<VisibleCelestialObject>> loadObjects({
    String category = 'all',
    String query = '',
    bool visibleOnly = false,
  }) async {
    final observer = observerDataProvider.current();
    final normalizedQuery = query.trim().toLowerCase();
    final source = await _loadSource(category);

    final objects = normalizedQuery.isEmpty
        ? source
        : source
              .where(
                (object) => object.name.toLowerCase().contains(normalizedQuery),
              )
              .toList(growable: false);

    final results = objects.map((object) {
      try {
        final position = _calculatePosition(object, observer);
        final visible = position.altitudeDeg >= horizonAltitudeDeg;
        final nearHorizon =
            visible && position.altitudeDeg < nearHorizonAltitudeDeg;
        final nearSun =
            visible &&
            (sunGuard?.isNearSun(
                  position.altitudeDeg,
                  position.azimuthDeg,
                  at: observer.utc,
                ) ??
                false);

        return VisibleCelestialObject(
          object: object,
          position: position,
          isVisible: visible,
          isNearHorizon: nearHorizon,
          isNearSun: nearSun,
          blockedReason: !visible
              ? 'Objeto bajo el horizonte'
              : nearSun
              ? SunGuard.blockedMessage(what: object.name)
              : null,
        );
      } catch (error) {
        return VisibleCelestialObject(
          object: object,
          position: null,
          isVisible: false,
          isNearHorizon: false,
          blockedReason: error.toString(),
        );
      }
    }).toList();

    final filtered = visibleOnly
        ? results.where((result) => result.isVisible).toList()
        : results;

    filtered.sort((a, b) {
      final aAlt = a.position?.altitudeDeg ?? double.negativeInfinity;
      final bAlt = b.position?.altitudeDeg ?? double.negativeInfinity;
      final altitudeOrder = bAlt.compareTo(aAlt);
      if (altitudeOrder != 0) return altitudeOrder;
      return a.object.name.compareTo(b.object.name);
    });

    return List.unmodifiable(filtered);
  }

  Future<List<CelestialObject>> _loadSource(String category) async {
    final provider = objectsProvider;
    if (provider != null) {
      return provider(category);
    }

    await catalogRepository.initialize();
    return catalogRepository.getByCategory(category);
  }

  AltAzResult _calculatePosition(
    CelestialObject object,
    ObserverData observer,
  ) {
    final resolver = positionResolver;
    if (resolver != null) {
      return resolver(object, observer);
    }

    return astronomyPositionService.calculateForObject(
      object: object,
      observer: observer,
    );
  }
}
