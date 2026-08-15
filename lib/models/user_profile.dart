class UserProfile {
  const UserProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.gradeId,
    required this.createdAt,
  });

  /// Firestore persists this value as `userId`, while the Class Diagram names
  /// the same identity `id`. A second duplicate identifier is intentionally
  /// not represented in the domain model.
  final String userId;
  final String name;
  final String email;
  final String role;
  final String? gradeId;
  final DateTime createdAt;

  factory UserProfile.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
    required DateTime createdAt,
  }) {
    final userId = data['userId'];
    final name = data['name'];
    final email = data['email'];
    final role = data['role'];
    final gradeId = data['gradeId'];

    if (userId is! String ||
        userId.isEmpty ||
        userId != documentId ||
        name is! String ||
        name.trim().isEmpty ||
        email is! String ||
        email.trim().isEmpty ||
        role is! String ||
        (gradeId != null && (gradeId is! String || gradeId.trim().isEmpty))) {
      throw const FormatException('Invalid user profile document.');
    }

    return UserProfile(
      userId: userId,
      name: name,
      email: email,
      role: role,
      gradeId: gradeId as String?,
      createdAt: createdAt,
    );
  }
}
