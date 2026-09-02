class Question {
  const Question({
    required this.questionId,
    required this.lessonId,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    required this.order,
    required this.isActive,
  });

  /// Firestore persists this identity as `questionId`, while the Class Diagram
  /// names the same field `id`. A duplicate identifier is intentionally not
  /// represented in the model.
  final String questionId;
  final String lessonId;
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final int order;
  final bool isActive;

  factory Question.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final questionId = data['questionId'];
    final lessonId = data['lessonId'];
    final questionText = data['questionText'];
    final rawOptions = data['options'];
    final correctAnswerIndex = data['correctAnswerIndex'];
    final explanation = data['explanation'];
    final order = data['order'];
    final isActive = data['isActive'];

    if (questionId is! String ||
        questionId.isEmpty ||
        questionId != documentId ||
        lessonId is! String ||
        lessonId.trim().isEmpty ||
        questionText is! String ||
        questionText.trim().isEmpty ||
        rawOptions is! List ||
        rawOptions.isEmpty ||
        rawOptions.any(
          (option) => option is! String || option.trim().isEmpty,
        ) ||
        correctAnswerIndex is! int ||
        correctAnswerIndex < 0 ||
        correctAnswerIndex >= rawOptions.length ||
        explanation is! String ||
        explanation.trim().isEmpty ||
        order is! int ||
        isActive is! bool) {
      throw const FormatException('Invalid question document.');
    }

    return Question(
      questionId: questionId,
      lessonId: lessonId,
      questionText: questionText,
      options: List<String>.unmodifiable(rawOptions.cast<String>()),
      correctAnswerIndex: correctAnswerIndex,
      explanation: explanation,
      order: order,
      isActive: isActive,
    );
  }
}
