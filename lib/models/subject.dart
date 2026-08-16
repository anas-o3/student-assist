class Subject {
  const Subject({
    required this.subjectId,
    required this.name,
    required this.gradeId,
    required this.imageUrl,
    required this.order,
    required this.isActive,
  });

  /// Firestore persists this identity as `subjectId`, while the Class Diagram
  /// names the same field `id`. A duplicate identifier is intentionally not
  /// represented in the model.
  final String subjectId;
  final String name;
  final String gradeId;
  final String imageUrl;
  final int order;
  final bool isActive;

  factory Subject.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final subjectId = data['subjectId'];
    final name = data['name'];
    final gradeId = data['gradeId'];
    final imageUrlValue = data['imageUrl'];
    final order = data['order'];
    final isActive = data['isActive'];

    if (subjectId is! String ||
        subjectId.isEmpty ||
        subjectId != documentId ||
        name is! String ||
        name.trim().isEmpty ||
        gradeId is! String ||
        gradeId.trim().isEmpty ||
        (imageUrlValue != null && imageUrlValue is! String) ||
        order is! int ||
        isActive is! bool) {
      throw const FormatException('Invalid subject document.');
    }

    return Subject(
      subjectId: subjectId,
      name: name,
      gradeId: gradeId,
      imageUrl: imageUrlValue is String ? imageUrlValue : '',
      order: order,
      isActive: isActive,
    );
  }
}
