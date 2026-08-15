import '../repositories/user_repository.dart';

class UserProfileFailure implements Exception {
  const UserProfileFailure();
}

class UserGradeSelectionFailure implements Exception {
  const UserGradeSelectionFailure(this.message);

  final String message;
}

class UserService {
  UserService([this._userRepository]);

  final UserRepository? _userRepository;
  UserRepository? _defaultUserRepository;

  UserRepository get _users =>
      _userRepository ?? (_defaultUserRepository ??= UserRepository());

  Future<void> createStudentProfile({
    required String uid,
    required String name,
    required String email,
  }) async {
    try {
      await _users.createStudentProfile(uid: uid, name: name, email: email);
    } on UserRepositoryFailure {
      throw const UserProfileFailure();
    }
  }

  Future<void> selectGrade({
    required String uid,
    required String gradeId,
  }) async {
    final normalizedGradeId = gradeId.trim();
    if (normalizedGradeId.isEmpty) {
      throw const UserGradeSelectionFailure('يرجى اختيار الصف الدراسي.');
    }

    try {
      await _users.updateGradeId(uid: uid, gradeId: normalizedGradeId);
    } on UserRepositoryFailure {
      throw const UserGradeSelectionFailure(
        'تعذر حفظ الصف الدراسي. حاول مرة أخرى.',
      );
    }
  }
}
