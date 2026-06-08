import 'package:flutter/foundation.dart';

import '../../data/student_quiz_repository.dart';
import '../../data/student_quiz_storage.dart';
import '../../domain/models/student_quiz_progress.dart';
import '../../domain/models/student_quiz_question.dart';

class StudentQuizController extends ChangeNotifier {
  static const int dailyLimit = 5;

  final StudentQuizRepository quizRepository;
  final StudentQuizStorage storage;
  final DateTime Function() now;

  StudentQuizController({
    required this.quizRepository,
    required this.storage,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  bool _isLoading = false;
  String? _errorMessage;
  List<StudentQuizQuestion> _questions = const [];
  StudentQuizProgress _progress = StudentQuizProgress(
    dateKey: _dateKeyFor(DateTime.now()),
    answeredToday: 0,
    correctToday: 0,
    usedQuestionIds: const [],
    dailyQuestionIds: const [],
  );
  StudentQuizQuestion? _currentQuestion;
  int? _selectedChoiceIndex;
  bool _answerSubmitted = false;
  bool? _lastAnswerCorrect;
  String? _currentObjectNote;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<StudentQuizQuestion> get questions => _questions;
  StudentQuizProgress get progress => _progress;
  StudentQuizQuestion? get currentQuestion => _currentQuestion;
  int? get selectedChoiceIndex => _selectedChoiceIndex;
  bool get answerSubmitted => _answerSubmitted;
  bool? get lastAnswerCorrect => _lastAnswerCorrect;
  String? get currentObjectNote => _currentObjectNote;
  int get answeredToday => _progress.answeredToday;
  int get correctToday => _progress.correctToday;
  int get remainingToday => dailyLimit - answeredToday;
  bool get isDailyLimitReached => answeredToday >= dailyLimit;
  bool get hasQuestions => _questions.isNotEmpty;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final questions = await quizRepository.loadQuestions();
      final saved = await storage.loadProgress();
      final normalized = _normalizeProgress(
        saved: saved,
        questions: questions,
        dateKey: _dateKeyFor(now()),
      );

      _questions = questions;
      _progress = normalized;
      _selectedChoiceIndex = null;
      _answerSubmitted = false;
      _lastAnswerCorrect = null;
      _currentObjectNote = null;
      _currentQuestion = _nextQuestionFor(normalized, questions);
      await storage.saveProgress(normalized);
    } catch (error) {
      _errorMessage = 'No se pudo cargar el modo estudiante: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> answerChoice(int choiceIndex) async {
    final question = _currentQuestion;
    if (question == null || _answerSubmitted || isDailyLimitReached) return;
    if (choiceIndex < 0 || choiceIndex >= question.choices.length) return;

    _selectedChoiceIndex = choiceIndex;
    _answerSubmitted = true;
    final isCorrect = choiceIndex == question.correctIndex;
    _lastAnswerCorrect = isCorrect;
    notifyListeners();

    final usedIds = {..._progress.usedQuestionIds, question.id}.toList()
      ..sort();
    final updated = _progress.copyWith(
      answeredToday: (_progress.answeredToday + 1).clamp(0, dailyLimit),
      correctToday: _progress.correctToday + (isCorrect ? 1 : 0),
      usedQuestionIds: usedIds,
    );

    _progress = updated;
    _currentObjectNote = await quizRepository.findObjectNote(question.objectId);
    await storage.saveProgress(updated);
    notifyListeners();
  }

  void goToNextQuestion() {
    if (!_answerSubmitted) return;

    _selectedChoiceIndex = null;
    _answerSubmitted = false;
    _lastAnswerCorrect = null;
    _currentObjectNote = null;
    _currentQuestion = _nextQuestionFor(_progress, _questions);
    notifyListeners();
  }

  StudentQuizProgress _normalizeProgress({
    required StudentQuizProgress? saved,
    required List<StudentQuizQuestion> questions,
    required String dateKey,
  }) {
    final validIds = questions.map((question) => question.id).toSet();
    final savedUsedIds =
        (saved?.usedQuestionIds ?? const [])
            .where(validIds.contains)
            .toSet()
            .toList()
          ..sort();

    if (saved != null &&
        saved.dateKey == dateKey &&
        saved.dailyQuestionIds.length >= dailyLimit &&
        saved.dailyQuestionIds.every(validIds.contains)) {
      return saved.copyWith(
        answeredToday: saved.answeredToday.clamp(0, dailyLimit),
        correctToday: saved.correctToday.clamp(0, dailyLimit),
        usedQuestionIds: savedUsedIds,
        dailyQuestionIds: saved.dailyQuestionIds.take(dailyLimit).toList(),
      );
    }

    final dailyIds = _buildDailyQuestionIds(
      questions: questions,
      usedQuestionIds: savedUsedIds,
      dateKey: dateKey,
    );

    return StudentQuizProgress(
      dateKey: dateKey,
      answeredToday: 0,
      correctToday: 0,
      usedQuestionIds: savedUsedIds,
      dailyQuestionIds: dailyIds,
    );
  }

  List<String> _buildDailyQuestionIds({
    required List<StudentQuizQuestion> questions,
    required List<String> usedQuestionIds,
    required String dateKey,
  }) {
    final used = usedQuestionIds.toSet();
    var available = questions
        .where((question) => !used.contains(question.id))
        .map((question) => question.id)
        .toList();

    if (available.length < dailyLimit) {
      available = questions.map((question) => question.id).toList();
    }

    available.sort();
    if (available.isEmpty) return const [];

    final offset = _stableDateOffset(dateKey, available.length);
    final rotated = [...available.skip(offset), ...available.take(offset)];
    return rotated.take(dailyLimit).toList(growable: false);
  }

  StudentQuizQuestion? _nextQuestionFor(
    StudentQuizProgress progress,
    List<StudentQuizQuestion> questions,
  ) {
    if (progress.answeredToday >= dailyLimit) return null;
    if (progress.answeredToday >= progress.dailyQuestionIds.length) return null;

    final id = progress.dailyQuestionIds[progress.answeredToday];
    for (final question in questions) {
      if (question.id == id) return question;
    }
    return null;
  }

  int _stableDateOffset(String dateKey, int length) {
    if (length <= 0) return 0;
    final hash = dateKey.codeUnits.fold<int>(
      0,
      (value, codeUnit) => value + codeUnit,
    );
    return hash % length;
  }

  static String _dateKeyFor(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
