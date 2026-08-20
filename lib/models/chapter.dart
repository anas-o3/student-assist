class Chapter {
  const Chapter({
    required this.chapterId,
    required this.title,
    required this.subjectId,
    required this.order,
    required this.isActive,
  });

  /// Firestore persists this identity as `chapterId`, while the Class Diagram
  /// names the same field `id`. A duplicate identifier is intentionally not
  /// represented in the model.
  final String chapterId;
  final String title;
  final String subjectId;
  final int order;
  final bool isActive;

  factory Chapter.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final chapterId = data['chapterId'];
    final title = data['title'];
    final subjectId = data['subjectId'];
    final order = data['order'];
    final isActive = data['isActive'];

    if (chapterId is! String ||
        chapterId.isEmpty ||
        chapterId != documentId ||
        title is! String ||
        title.trim().isEmpty ||
        subjectId is! String ||
        subjectId.trim().isEmpty ||
        order is! int ||
        isActive is! bool) {
      throw const FormatException('Invalid chapter document.');
    }

    return Chapter(
      chapterId: chapterId,
      title: title,
      subjectId: subjectId,
      order: order,
      isActive: isActive,
    );
  }
}
