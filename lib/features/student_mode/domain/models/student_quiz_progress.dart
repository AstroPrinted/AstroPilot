class StudentQuizProgress {
  final String dateKey;
  final int answeredToday;
  final int correctToday;
  final List<String> usedQuestionIds;
  final List<String> dailyQuestionIds;

  const StudentQuizProgress({
    required this.dateKey,
    required this.answeredToday,
    required this.correctToday,
    required this.usedQuestionIds,
    required this.dailyQuestionIds,
  });

  StudentQuizProgress copyWith({
    String? dateKey,
    int? answeredToday,
    int? correctToday,
    List<String>? usedQuestionIds,
    List<String>? dailyQuestionIds,
  }) {
    return StudentQuizProgress(
      dateKey: dateKey ?? this.dateKey,
      answeredToday: answeredToday ?? this.answeredToday,
      correctToday: correctToday ?? this.correctToday,
      usedQuestionIds: usedQuestionIds ?? this.usedQuestionIds,
      dailyQuestionIds: dailyQuestionIds ?? this.dailyQuestionIds,
    );
  }
}
