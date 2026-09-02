import '../models/question.dart';
import '../models/quiz_attempt.dart';
import '../repositories/question_repository.dart';
import '../repositories/quiz_attempt_repository.dart';

enum QuizFailureReason {
  emptyLessonId,
  emptyUserId,
  noQuestions,
  invalidQuestions,
  invalidAnswers,
  invalidData,
  loadFailed,
  saveFailed,
}

class QuizFailure implements Exception {
  const QuizFailure(this.message, this.reason);

  final String message;
  final QuizFailureReason reason;
}

class QuizEvaluationResult {
  QuizEvaluationResult({
    required this.attempt,
    required Map<String, bool> answerCorrectness,
  }) : answerCorrectness = Map.unmodifiable(answerCorrectness);

  final QuizAttempt attempt;
  final Map<String, bool> answerCorrectness;
}

class QuizService {
  QuizService([
    this._questionRepository,
    this._quizAttemptRepository,
    this._clock,
  ]);

  final QuestionRepository? _questionRepository;
  final QuizAttemptRepository? _quizAttemptRepository;
  final DateTime Function()? _clock;
  QuestionRepository? _defaultQuestionRepository;
  QuizAttemptRepository? _defaultQuizAttemptRepository;

  QuestionRepository get _questions =>
      _questionRepository ??
      (_defaultQuestionRepository ??= QuestionRepository());

  QuizAttemptRepository get _attempts =>
      _quizAttemptRepository ??
      (_defaultQuizAttemptRepository ??= QuizAttemptRepository());

  DateTime get _now => (_clock ?? DateTime.now)().toUtc();

  Future<List<Question>> loadActiveQuestionsForLesson(String lessonId) async {
    final normalizedLessonId = lessonId.trim();
    if (normalizedLessonId.isEmpty) {
      throw const QuizFailure(
        'تعذر تحديد الدرس.',
        QuizFailureReason.emptyLessonId,
      );
    }

    try {
      return await _questions.loadActiveQuestionsForLesson(normalizedLessonId);
    } on QuestionRepositoryFailure catch (error) {
      throw switch (error.reason) {
        QuestionRepositoryFailureReason.invalidData => const QuizFailure(
          'بيانات أسئلة الاختبار غير صالحة.',
          QuizFailureReason.invalidData,
        ),
        QuestionRepositoryFailureReason.backend => const QuizFailure(
          'تعذر تحميل أسئلة الاختبار. حاول مرة أخرى.',
          QuizFailureReason.loadFailed,
        ),
      };
    }
  }

  Future<QuizEvaluationResult> evaluateAndSaveAttempt({
    required String userId,
    required String lessonId,
    required List<Question> questions,
    required Map<String, int> selectedAnswerIndexes,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedLessonId = lessonId.trim();
    if (normalizedUserId.isEmpty) {
      throw const QuizFailure(
        'تعذر تحديد المستخدم.',
        QuizFailureReason.emptyUserId,
      );
    }
    if (normalizedLessonId.isEmpty) {
      throw const QuizFailure(
        'تعذر تحديد الدرس.',
        QuizFailureReason.emptyLessonId,
      );
    }
    if (questions.isEmpty) {
      throw const QuizFailure(
        'لا توجد أسئلة متاحة للتقييم.',
        QuizFailureReason.noQuestions,
      );
    }

    final questionIds = questions.map((question) => question.questionId).toSet();
    final questionsAreValid = questionIds.length == questions.length &&
        questions.every(
          (question) =>
              question.lessonId == normalizedLessonId && question.isActive,
        );
    if (!questionsAreValid) {
      throw const QuizFailure(
        'بيانات أسئلة الاختبار غير صالحة.',
        QuizFailureReason.invalidQuestions,
      );
    }

    final answersAreComplete =
        selectedAnswerIndexes.length == questions.length &&
        selectedAnswerIndexes.keys.every(questionIds.contains) &&
        questions.every((question) {
          final selectedIndex = selectedAnswerIndexes[question.questionId];
          return selectedIndex != null &&
              selectedIndex >= 0 &&
              selectedIndex < question.options.length;
        });
    if (!answersAreComplete) {
      throw const QuizFailure(
        'يرجى الإجابة عن جميع أسئلة الاختبار بإجابات صالحة.',
        QuizFailureReason.invalidAnswers,
      );
    }

    final correctness = <String, bool>{};
    var score = 0;
    for (final question in questions) {
      final isCorrect =
          selectedAnswerIndexes[question.questionId] ==
          question.correctAnswerIndex;
      correctness[question.questionId] = isCorrect;
      if (isCorrect) score++;
    }
    final totalQuestions = questions.length;
    final percentage = score * 100 / totalQuestions;

    try {
      final attempt = await _attempts.createAttempt(
        userId: normalizedUserId,
        lessonId: normalizedLessonId,
        score: score,
        totalQuestions: totalQuestions,
        percentage: percentage,
        completedAt: _now,
      );
      return QuizEvaluationResult(
        attempt: attempt,
        answerCorrectness: correctness,
      );
    } on QuizAttemptRepositoryFailure {
      throw const QuizFailure(
        'تعذر حفظ نتيجة الاختبار. حاول مرة أخرى.',
        QuizFailureReason.saveFailed,
      );
    }
  }
}
