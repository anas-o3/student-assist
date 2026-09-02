import 'package:cloud_firestore/cloud_firestore.dart';

class QuizAttempt {
  const QuizAttempt({
    required this.attemptId,
    required this.userId,
    required this.lessonId,
    required this.score,
    required this.totalQuestions,
    required this.percentage,
    required this.completedAt,
  });

  /// Firestore persists this identity as `attemptId`, while the Class Diagram
  /// names the same field `id`. A duplicate identifier is intentionally not
  /// represented in the model.
  final String attemptId;
  final String userId;
  final String lessonId;
  final int score;
  final int totalQuestions;
  final double percentage;
  final DateTime completedAt;

  factory QuizAttempt.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final attemptId = data['attemptId'];
    final userId = data['userId'];
    final lessonId = data['lessonId'];
    final score = data['score'];
    final totalQuestions = data['totalQuestions'];
    final percentage = data['percentage'];
    final completedAt = data['completedAt'];

    if (attemptId is! String ||
        attemptId.isEmpty ||
        attemptId != documentId ||
        userId is! String ||
        userId.trim().isEmpty ||
        lessonId is! String ||
        lessonId.trim().isEmpty ||
        score is! int ||
        totalQuestions is! int ||
        totalQuestions <= 0 ||
        score < 0 ||
        score > totalQuestions ||
        percentage is! num ||
        percentage < 0 ||
        percentage > 100 ||
        completedAt is! Timestamp) {
      throw const FormatException('Invalid quiz attempt document.');
    }

    return QuizAttempt(
      attemptId: attemptId,
      userId: userId,
      lessonId: lessonId,
      score: score,
      totalQuestions: totalQuestions,
      percentage: percentage.toDouble(),
      completedAt: completedAt.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'attemptId': attemptId,
    'userId': userId,
    'lessonId': lessonId,
    'score': score,
    'totalQuestions': totalQuestions,
    'percentage': percentage,
    'completedAt': Timestamp.fromDate(completedAt),
  };
}
