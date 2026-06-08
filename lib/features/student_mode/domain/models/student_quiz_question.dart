enum StudentQuizDifficulty { easy, medium }

extension StudentQuizDifficultyLabel on StudentQuizDifficulty {
  String get label {
    return switch (this) {
      StudentQuizDifficulty.easy => 'Facil',
      StudentQuizDifficulty.medium => 'Media',
    };
  }
}

StudentQuizDifficulty studentQuizDifficultyFromName(String? name) {
  return StudentQuizDifficulty.values.firstWhere(
    (difficulty) => difficulty.name == name,
    orElse: () => StudentQuizDifficulty.easy,
  );
}

class StudentQuizQuestion {
  final String id;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final StudentQuizDifficulty difficulty;
  final String topic;
  final String explanation;
  final String? objectId;

  const StudentQuizQuestion({
    required this.id,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.difficulty,
    required this.topic,
    required this.explanation,
    this.objectId,
  });

  factory StudentQuizQuestion.fromJson(Map<String, dynamic> json) {
    return StudentQuizQuestion(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      choices: (json['choices'] as List<dynamic>? ?? const [])
          .map((choice) => choice.toString())
          .toList(growable: false),
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      difficulty: studentQuizDifficultyFromName(json['difficulty'] as String?),
      topic: json['topic'] as String? ?? 'Astronomia',
      explanation: json['explanation'] as String? ?? '',
      objectId: json['objectId'] as String?,
    );
  }
}
