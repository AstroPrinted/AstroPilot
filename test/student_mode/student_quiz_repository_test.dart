import 'package:astroprintedlogicincludedgeoengine/features/catalog/data/repository/celestial_catalog_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/student_mode/data/student_quiz_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/student_mode/domain/models/student_quiz_question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads a valid curated question bank', () async {
    final catalogRepository = CelestialCatalogRepository();
    final repository = StudentQuizRepository(
      catalogRepository: catalogRepository,
    );

    final questions = await repository.loadQuestions();

    expect(questions.length, greaterThanOrEqualTo(50));
    expect(
      questions.map((question) => question.id).toSet(),
      hasLength(questions.length),
    );

    final easyCount = questions
        .where((question) => question.difficulty == StudentQuizDifficulty.easy)
        .length;
    final mediumCount = questions
        .where(
          (question) => question.difficulty == StudentQuizDifficulty.medium,
        )
        .length;

    expect(easyCount, greaterThanOrEqualTo(30));
    expect(mediumCount, greaterThanOrEqualTo(20));

    for (final question in questions) {
      expect(question.prompt.trim(), isNotEmpty);
      expect(question.choices, hasLength(4));
      expect(question.correctIndex, inInclusiveRange(0, 3));
      expect(question.topic.trim(), isNotEmpty);
      expect(question.explanation.trim(), isNotEmpty);

      final objectId = question.objectId;
      if (objectId != null) {
        expect(await repository.findObjectById(objectId), isNotNull);
      }
    }
  });
}
