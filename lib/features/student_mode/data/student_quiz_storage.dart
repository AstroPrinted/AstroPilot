import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/student_quiz_progress.dart';

class StudentQuizStorage {
  static const _dateKey = 'student_quiz.date';
  static const _answeredTodayKey = 'student_quiz.answered_today';
  static const _correctTodayKey = 'student_quiz.correct_today';
  static const _usedQuestionIdsKey = 'student_quiz.used_question_ids';
  static const _dailyQuestionIdsKey = 'student_quiz.daily_question_ids';

  const StudentQuizStorage();

  Future<StudentQuizProgress?> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = prefs.getString(_dateKey);
    if (dateKey == null || dateKey.isEmpty) return null;

    return StudentQuizProgress(
      dateKey: dateKey,
      answeredToday: prefs.getInt(_answeredTodayKey) ?? 0,
      correctToday: prefs.getInt(_correctTodayKey) ?? 0,
      usedQuestionIds: prefs.getStringList(_usedQuestionIdsKey) ?? const [],
      dailyQuestionIds: prefs.getStringList(_dailyQuestionIdsKey) ?? const [],
    );
  }

  Future<void> saveProgress(StudentQuizProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dateKey, progress.dateKey);
    await prefs.setInt(_answeredTodayKey, progress.answeredToday);
    await prefs.setInt(_correctTodayKey, progress.correctToday);
    await prefs.setStringList(_usedQuestionIdsKey, progress.usedQuestionIds);
    await prefs.setStringList(_dailyQuestionIdsKey, progress.dailyQuestionIds);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dateKey);
    await prefs.remove(_answeredTodayKey);
    await prefs.remove(_correctTodayKey);
    await prefs.remove(_usedQuestionIdsKey);
    await prefs.remove(_dailyQuestionIdsKey);
  }
}
