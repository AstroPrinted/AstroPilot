import 'package:astroprintedlogicincludedgeoengine/features/catalog/application/visible_objects_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/data/repository/celestial_catalog_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/domain/models/celestial_object.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/alt_az_result.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/models/observer_data.dart';
import 'package:astroprintedlogicincludedgeoengine/features/observation/domain/services/observer_data_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final highObject = _object('high', 'Objeto Alto');
  final nearObject = _object('near', 'Objeto Bajo Visible');
  final belowObject = _object('below', 'Objeto Bajo Horizonte');

  test('filters visible objects and sorts by altitude', () async {
    final service = VisibleObjectsService(
      catalogRepository: CelestialCatalogRepository(),
      observerDataProvider: const _FakeObserverDataProvider(),
      objectsProvider: (_) async => [belowObject, nearObject, highObject],
      positionResolver: (object, _) => switch (object.id) {
        'high' => _position(35, 120),
        'near' => _position(2, 80),
        'below' => _position(-1, 10),
        _ => _position(0, 0),
      },
    );

    final results = await service.loadObjects(visibleOnly: true);

    expect(results.map((item) => item.object.id), ['high', 'near']);
    expect(results.first.isNearHorizon, isFalse);
    expect(results.last.isNearHorizon, isTrue);
  });

  test('keeps below horizon objects when visibleOnly is false', () async {
    final service = VisibleObjectsService(
      catalogRepository: CelestialCatalogRepository(),
      observerDataProvider: const _FakeObserverDataProvider(),
      objectsProvider: (_) async => [belowObject],
      positionResolver: (_, __) => _position(-3, 45),
    );

    final results = await service.loadObjects();

    expect(results, hasLength(1));
    expect(results.single.isVisible, isFalse);
    expect(results.single.blockedReason, 'Objeto bajo el horizonte');
  });
}

DeepSkyObject _object(String id, String name) {
  return DeepSkyObject(
    id: id,
    name: name,
    objectType: 'Test',
    constellations: const ['Test'],
    raJ2000Hours: 0,
    decJ2000Degrees: 0,
    catalogs: const ['TEST'],
  );
}

AltAzResult _position(double altitude, double azimuth) {
  return AltAzResult(
    altitudeDeg: altitude,
    azimuthDeg: azimuth,
    altitudeRawDeg: altitude,
    azimuthRawDeg: azimuth,
    computedAt: DateTime.utc(2026),
  );
}

class _FakeObserverDataProvider implements ObserverDataProvider {
  const _FakeObserverDataProvider();

  @override
  ObserverData current() {
    return ObserverData(
      latDeg: -33.0,
      lonDeg: -70.0,
      heightMeters: 0,
      utc: DateTime.utc(2026),
    );
  }
}
