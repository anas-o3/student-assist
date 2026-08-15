class Grade {
  const Grade({
    required this.gradeId,
    required this.name,
    required this.order,
    required this.isActive,
  });

  final String gradeId;
  final String name;
  final int order;
  final bool isActive;

  factory Grade.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final gradeId = data['gradeId'];
    final name = data['name'];
    final order = data['order'];
    final isActive = data['isActive'];

    if (gradeId is! String ||
        gradeId != documentId ||
        name is! String ||
        order is! int ||
        isActive is! bool) {
      throw const FormatException('Invalid grade document.');
    }

    return Grade(
      gradeId: gradeId,
      name: name,
      order: order,
      isActive: isActive,
    );
  }

  Map<String, Object> toFirestore() {
    return {
      'gradeId': gradeId,
      'name': name,
      'order': order,
      'isActive': isActive,
    };
  }
}
