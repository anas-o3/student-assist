import '../repositories/user_repository.dart';

class UserProfileFailure implements Exception {
  const UserProfileFailure();
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
}
