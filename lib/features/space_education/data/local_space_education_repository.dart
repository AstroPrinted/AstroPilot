import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/models/educational_space_object.dart';

class LocalSpaceEducationRepository {
  static const assetPath = 'assets/educational_space_objects.json';

  const LocalSpaceEducationRepository();

  Future<List<EducationalSpaceObject>> loadObjects() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final objects = (decoded['objects'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_parseObject)
          .toList(growable: false);
      return List.unmodifiable(objects);
    } on FlutterError catch (error) {
      throw StateError('No se pudo cargar el contenido educativo: $error');
    } on FormatException {
      rethrow;
    } catch (error) {
      debugPrint('Space education load error: $error');
      throw StateError('No se pudo leer el contenido educativo local.');
    }
  }

  EducationalSpaceObject _parseObject(Map<String, dynamic> item) {
    return EducationalSpaceObject(
      id: item['id'] as String? ?? 'educational_object',
      name: item['name'] as String? ?? 'Objeto educativo',
      category: educationalSpaceCategoryFromId(
        item['category'] as String? ?? '',
      ),
      type: educationalSpaceObjectTypeFromId(item['type'] as String? ?? ''),
      shortDescription: item['shortDescription'] as String? ?? '',
      longDescription: item['longDescription'] as String? ?? '',
      imageAssetPath: item['imageAssetPath'] as String?,
      imageCredit: item['imageCredit'] as String?,
      facts: (item['facts'] as List<dynamic>? ?? const [])
          .map((fact) => fact.toString())
          .toList(growable: false),
      agency: item['agency'] as String?,
      missionStatus: item['missionStatus'] as String?,
      destination: item['destination'] as String?,
      launchYear: (item['launchYear'] as num?)?.toInt(),
      orbit: item['orbit'] as String?,
      visibilityNote: item['visibilityNote'] as String?,
    );
  }
}
