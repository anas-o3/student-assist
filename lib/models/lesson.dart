import 'package:cloud_firestore/cloud_firestore.dart';

class Lesson {
  const Lesson({
    required this.lessonId,
    required this.title,
    required this.chapterId,
    required this.explanation,
    required this.order,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestore persists this identity as `lessonId`, while the Class Diagram
  /// names the same field `id`. A duplicate identifier is intentionally not
  /// represented in the model.
  ///
  /// The Class Diagram's `videoUrl` and `pdfUrl` fields are intentionally not
  /// represented because the newer Firestore design stores them as resources.
  final String lessonId;
  final String title;
  final String chapterId;
  final String explanation;
  final int order;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Lesson.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final lessonId = data['lessonId'];
    final title = data['title'];
    final chapterId = data['chapterId'];
    final explanation = data['explanation'];
    final order = data['order'];
    final isActive = data['isActive'];

    if (lessonId is! String ||
        lessonId.isEmpty ||
        lessonId != documentId ||
        title is! String ||
        title.trim().isEmpty ||
        chapterId is! String ||
        chapterId.trim().isEmpty ||
        explanation is! String ||
        explanation.trim().isEmpty ||
        order is! int ||
        isActive is! bool) {
      throw const FormatException('Invalid lesson document.');
    }

    return Lesson(
      lessonId: lessonId,
      title: title,
      chapterId: chapterId,
      explanation: explanation,
      order: order,
      isActive: isActive,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  static DateTime _parseTimestamp(Object? value) {
    if (value is! Timestamp) {
      throw const FormatException('Invalid lesson timestamp.');
    }
    return value.toDate();
  }
}
