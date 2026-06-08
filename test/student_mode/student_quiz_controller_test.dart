import 'package:astroprintedlogicincludedgeoengine/features/catalog/data/repository/celestial_catalog_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/student_mode/data/student_quiz_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/student_mode/data/student_quiz_storage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/student_mode/domain/models/student_quiz_question.dart';
import 'package:astroprintedlogicincludedgeoengine/features/student_mode/presentation/controllers/student_quiz_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('delivers at most five questions per local day', () async {
    final controller = _controller(now: DateTime(2026, 6, 7, 10));
    addTearDown(controller.dispose);

    await controller.load();
    final seenIds = <String>{};

    for (var i = 0; i < StudentQuizController.dailyLimit; i++) {
      final question = controller.currentQuestion;
      expect(question, isNotNull);
      seenIds.add(question!.id);
      await controller.answerChoice(question.correctIndex);
      controller.goToNextQuestion();
    }

    expect(seenIds, hasLength(StudentQuizController.dailyLimit));
    expect(controller.answeredToday, StudentQuizController.dailyLimit);
    expect(controller.currentQuestion, isNull);
    expect(controller.isDailyLimitReached, isTrue);
  });

  test('incorrect answers also consume the daily quota', () async {
    final controller = _controller(now: DateTime(2026, 6, 7, 10));
    addTearDown(controller.dispose);

    await controller.load();
    final question = controller.currentQuestion!;
    final wrongIndex = question.correctIndex == 0 ? 1 : 0;

    await controller.answerChoice(wrongIndex);

    expect(controller.answeredToday, 1);
    expect(controller.correctToday, 0);
    expect(controller.lastAnswerCorrect, isFalse);
  });

  test('resets daily quota when local date changes', () async {
    final firstDay = _controller(now: DateTime(2026, 6, 7, 10));
    addTearDown(firstDay.dispose);

    await firstDay.load();
    for (var i = 0; i < StudentQuizController.dailyLimit; i++) {
      await firstDay.answerChoice(firstDay.currentQuestion!.correctIndex);
      firstDay.goToNextQuestion();
    }

    final secondDay = _controller(now: DateTime(2026, 6, 8, 10));
    addTearDown(secondDay.dispose);

    await secondDay.load();

    expect(secondDay.answeredToday, 0);
    expect(secondDay.correctToday, 0);
    expect(secondDay.currentQuestion, isNotNull);
  });

  test('preserves progress when controller reloads on the same day', () async {
    final first = _controller(now: DateTime(2026, 6, 7, 10));
    addTearDown(first.dispose);

    await first.load();
    final firstQuestion = first.currentQuestion!;
    await first.answerChoice(firstQuestion.correctIndex);
    first.goToNextQuestion();
    final secondQuestion = first.currentQuestion!;
    await first.answerChoice(secondQuestion.correctIndex);

    final reloaded = _controller(now: DateTime(2026, 6, 7, 12));
    addTearDown(reloaded.dispose);

    await reloaded.load();

    expect(reloaded.answeredToday, 2);
    expect(reloaded.correctToday, 2);
    expect(reloaded.currentQuestion?.id, isNot(firstQuestion.id));
    expect(reloaded.currentQuestion?.id, isNot(secondQuestion.id));
  });
}

StudentQuizController _controller({required DateTime now}) {
  return StudentQuizController(
    quizRepository: _FakeStudentQuizRepository(_questions()),
    storage: const StudentQuizStorage(),
    now: () => now,
  );
}

List<StudentQuizQuestion> _questions() {
  return List.generate(
    8,
    (index) => StudentQuizQuestion(
      id: 'q_$index',
      prompt: 'Pregunta $index',
      choices: const ['A', 'B', 'C', 'D'],
      correctIndex: index % 4,
      difficulty: index.isEven
          ? StudentQuizDifficulty.easy
          : StudentQuizDifficulty.medium,
      topic: 'Tema',
      explanation: 'Explicación $index',
      objectId: 'solar_mars',
    ),
  );
}

class _FakeStudentQuizRepository extends StudentQuizRepository {
  final List<StudentQuizQuestion> fakeQuestions;

  _FakeStudentQuizRepository(this.fakeQuestions)
    : super(catalogRepository: CelestialCatalogRepository());

  @override
  Future<List<StudentQuizQuestion>> loadQuestions() async {
    return fakeQuestions;
  }

  @override
  Future<String?> findObjectNote(String? objectId) async {
    return objectId == null ? null : 'Curiosidad de prueba';
  }
}
