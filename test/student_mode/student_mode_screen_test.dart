import 'package:astroprintedlogicincludedgeoengine/core/theme/app_theme.dart';
import 'package:astroprintedlogicincludedgeoengine/features/catalog/data/repository/celestial_catalog_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/settings/application/settings_service.dart';
import 'package:astroprintedlogicincludedgeoengine/features/student_mode/data/student_quiz_repository.dart';
import 'package:astroprintedlogicincludedgeoengine/features/student_mode/data/student_quiz_storage.dart';
import 'package:astroprintedlogicincludedgeoengine/features/student_mode/domain/models/student_quiz_question.dart';
import 'package:astroprintedlogicincludedgeoengine/features/student_mode/presentation/controllers/student_quiz_controller.dart';
import 'package:astroprintedlogicincludedgeoengine/features/student_mode/presentation/screens/student_mode_screen.dart';
import 'package:astroprintedlogicincludedgeoengine/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('home exposes the educational mode', (tester) async {
    SharedPreferences.setMockInitialValues({'app_flow.onboarding_done': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      AstroPilotApp(
        settingsService: SettingsService(),
        prefs: prefs,
        initializeBle: false,
      ),
    );

    expect(find.text('Educativo'), findsOneWidget);
  });

  testWidgets('shows daily counter and answer feedback with curiosity', (
    tester,
  ) async {
    final controller = _controller(DateTime(2026, 6, 7, 10));
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(StudentModeScreen(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiz astronómico'));
    await tester.pumpAndSettle();

    expect(find.text('Preguntas de hoy'), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);

    final activeAnswer = controller.currentQuestion!.choices.first;
    await tester.tap(find.text(activeAnswer));
    await tester.pumpAndSettle();

    expect(find.text('Respuesta correcta'), findsOneWidget);
    expect(find.textContaining('Curiosidad:'), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('shows blocked state after five answered questions', (
    tester,
  ) async {
    final controller = _controller(DateTime(2026, 6, 7, 10));
    addTearDown(controller.dispose);

    await controller.load();
    for (var i = 0; i < StudentQuizController.dailyLimit; i++) {
      await controller.answerChoice(controller.currentQuestion!.correctIndex);
      controller.goToNextQuestion();
    }

    await tester.pumpWidget(_app(StudentModeScreen(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiz astronómico'));
    await tester.pumpAndSettle();

    expect(find.text('Meta diaria completada'), findsOneWidget);
    expect(find.textContaining('Vuelve manana'), findsOneWidget);
    expect(find.text('5/5'), findsWidgets);
  });
}

Widget _app(Widget child) {
  return MaterialApp(theme: AppTheme.darkTheme, home: child);
}

StudentQuizController _controller(DateTime now) {
  return StudentQuizController(
    quizRepository: _FakeStudentQuizRepository(_questions()),
    storage: const StudentQuizStorage(),
    now: () => now,
  );
}

List<StudentQuizQuestion> _questions() {
  return [
    _question('q_0', 'Cuál es el planeta más grande?', 'Júpiter'),
    _question('q_1', 'Qué objeto es una estrella?', 'Sol'),
    _question('q_2', 'Qué planeta es rojizo?', 'Marte'),
    _question('q_3', 'Qué planeta tiene anillos famosos?', 'Saturno'),
    _question('q_4', 'Qué satélite vemos en fases?', 'Luna'),
  ];
}

StudentQuizQuestion _question(String id, String prompt, String answer) {
  return StudentQuizQuestion(
    id: id,
    prompt: prompt,
    choices: [answer, 'Opción B', 'Opción C', 'Opción D'],
    correctIndex: 0,
    difficulty: StudentQuizDifficulty.easy,
    topic: 'Sistema solar',
    explanation: '$answer es la respuesta correcta.',
    objectId: 'solar_jupiter',
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
    return objectId == null ? null : 'Júpiter es el planeta más grande.';
  }
}
