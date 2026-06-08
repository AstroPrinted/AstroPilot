import 'dart:convert';

import 'package:flutter/services.dart';

import '../../catalog/data/repository/celestial_catalog_repository.dart';
import '../../catalog/domain/models/celestial_object.dart';
import '../domain/models/student_quiz_question.dart';

class StudentQuizRepository {
  static const assetPath = 'assets/student_quiz_questions.json';

  final AssetBundle assetBundle;
  final CelestialCatalogRepository catalogRepository;

  StudentQuizRepository({
    AssetBundle? assetBundle,
    required this.catalogRepository,
  }) : assetBundle = assetBundle ?? rootBundle;

  Future<List<StudentQuizQuestion>> loadQuestions() async {
    final raw = await assetBundle.loadString(assetPath);
    final map = json.decode(raw) as Map<String, dynamic>;
    final questions = (map['questions'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(StudentQuizQuestion.fromJson)
        .toList(growable: false);
    return List.unmodifiable(questions);
  }

  Future<CelestialObject?> findObjectById(String objectId) async {
    await catalogRepository.initialize();
    for (final object in catalogRepository.getAllObjects()) {
      if (object.id == objectId) return object;
    }
    return null;
  }

  Future<String?> findObjectNote(String? objectId) async {
    if (objectId == null || objectId.trim().isEmpty) return null;
    final object = await findObjectById(objectId);
    final note = object?.notes?.trim();
    if (note == null || note.isEmpty) return null;
    return note;
  }
}
