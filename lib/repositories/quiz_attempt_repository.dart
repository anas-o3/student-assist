import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/quiz_attempt.dart';

enum QuizAttemptRepositoryFailureReason { backend }

class QuizAttemptRepositoryFailure implements Exception {
  const QuizAttemptRepositoryFailure([
    this.reason = QuizAttemptRepositoryFailureReason.backend,
  ]);

  final QuizAttemptRepositoryFailureReason reason;
}

typedef QuizAttemptCreator =
    Future<QuizAttempt> Function({
      required String userId,
      required String lessonId,
      required int score,
      required int totalQuestions,
      required double percentage,
      required DateTime completedAt,
    });

class QuizAttemptRepository {
  QuizAttemptRepository([this._firestore, this._quizAttemptCreator]);

  final FirebaseFirestore? _firestore;
  final QuizAttemptCreator? _quizAttemptCreator;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;

  Future<QuizAttempt> createAttempt({
    required String userId,
    required String lessonId,
    required int score,
    required int totalQuestions,
    required double percentage,
    required DateTime completedAt,
  }) async {
    try {
      final creator = _quizAttemptCreator;
      if (creator != null) {
        return await creator(
          userId: userId,
          lessonId: lessonId,
          score: score,
          totalQuestions: totalQuestions,
          percentage: percentage,
          completedAt: completedAt,
        );
      }

      final reference = _database.collection('quizAttempts').doc();
      final attempt = QuizAttempt(
        attemptId: reference.id,
        userId: userId,
        lessonId: lessonId,
        score: score,
        totalQuestions: totalQuestions,
        percentage: percentage,
        completedAt: completedAt,
      );
      await reference.set({
        ...attempt.toFirestore(),
        'completedAt': FieldValue.serverTimestamp(),
      });
      return attempt;
    } on FirebaseException {
      throw const QuizAttemptRepositoryFailure();
    }
  }
}
