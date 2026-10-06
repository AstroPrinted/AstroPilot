import 'dart:io';

import 'package:astroprintedlogicincludedgeoengine/features/catalog/data/repository/celestial_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every catalog object has a bundled image with its credit', () async {
    final repository = CelestialCatalogRepository();
    await repository.initialize();

    final objects = repository.getAllObjects();
    expect(objects, isNotEmpty);
    for (final object in objects) {
      final image = repository.imageFor(object);
      expect(image, isNotNull, reason: '${object.name} (${object.id})');
      expect(File(image!.asset).existsSync(), isTrue, reason: image.asset);
      expect(image.credit.trim(), isNotEmpty, reason: object.name);
    }
  });
}
