import '../models/user_profile.dart';
import '../repositories/user_repository.dart';

enum UserProfileFailureReason {
  emptyUid,
  missingProfile,
  invalidProfile,
  backend,
}

class UserProfileFailure implements Exception {
  const UserProfileFailure({
    this.reason = UserProfileFailureReason.backend,
    this.message = 'تعذر تحميل ملف المستخدم. حاول مرة أخرى.',
  });

  final UserProfileFailureReason reason;
  final String message;
}

class UserGradeSelectionFailure implements Exception {
  const UserGradeSelectionFailure(this.message);

  final String message;
}

enum PostLoginRoute {
  studentNeedsGradeSelection,
  studentReady,
  admin,
  invalidRole,
}

class UserService {
  UserService([this._userRepository]);

  final UserRepository? _userRepository;
  UserRepository? _defaultUserRepository;

  UserRepository get _users =>
      _userRepository ?? (_defaultUserRepository ??= UserRepository());

  Future<UserProfile> getUserProfile(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw const UserProfileFailure(
        reason: UserProfileFailureReason.emptyUid,
        message: 'تعذر تحديد المستخدم الحالي.',
      );
    }

    try {
      return await _users.getUser(normalizedUid);
    } on UserRepositoryFailure catch (error) {
      throw switch (error.reason) {
        UserRepositoryFailureReason.missingProfile => const UserProfileFailure(
          reason: UserProfileFailureReason.missingProfile,
          message: 'لم يتم العثور على ملف المستخدم.',
        ),
        UserRepositoryFailureReason.invalidData => const UserProfileFailure(
          reason: UserProfileFailureReason.invalidProfile,
          message: 'بيانات ملف المستخدم غير صالحة.',
        ),
        UserRepositoryFailureReason.backend => const UserProfileFailure(),
      };
    }
  }

  PostLoginRoute decidePostLoginRoute(UserProfile profile) {
    if (profile.role == 'admin') return PostLoginRoute.admin;
    if (profile.role != 'student') return PostLoginRoute.invalidRole;
    if (profile.gradeId == null) {
      return PostLoginRoute.studentNeedsGradeSelection;
    }
    if (profile.gradeId!.trim().isNotEmpty) return PostLoginRoute.studentReady;
    return PostLoginRoute.invalidRole;
  }

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
