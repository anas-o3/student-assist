import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/models/user_profile.dart';
import 'package:student_assist/repositories/user_repository.dart';
import 'package:student_assist/services/user_service.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 15, 10, 30);

  UserProfile profile({required String role, String? gradeId}) {
    return UserProfile(
      userId: 'user-uid',
      name: 'طالب تجريبي',
      email: 'student@example.com',
      role: role,
      gradeId: gradeId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> profileData({
    Object? name = 'طالب تجريبي',
    String role = 'student',
    String? gradeId,
  }) {
    return {
      'userId': 'user-uid',
      'name': name,
      'email': 'student@example.com',
      'role': role,
      'gradeId': gradeId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  group('UserProfile persistence mapping', () {
    test('maps the approved Firestore user fields', () {
      final result = UserRepository.profileFromFirestore(
        documentId: 'user-uid',
        data: profileData(gradeId: 'grade-1'),
      );

      expect(result.userId, 'user-uid');
      expect(result.name, 'طالب تجريبي');
      expect(result.email, 'student@example.com');
      expect(result.role, 'student');
      expect(result.gradeId, 'grade-1');
      expect(result.createdAt, createdAt);
    });

    test('rejects a malformed profile field', () {
      expect(
        () => UserRepository.profileFromFirestore(
          documentId: 'user-uid',
          data: profileData(name: 42),
        ),
        throwsFormatException,
      );
    });
  });

  group('UserRepository profile loading', () {
    test('reports a missing user document safely', () async {
      final repository = UserRepository(null, (_) async => null);

      await expectLater(
        repository.getUser('user-uid'),
        throwsA(
          isA<UserRepositoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            UserRepositoryFailureReason.missingProfile,
          ),
        ),
      );
    });

    test('classifies malformed document data as invalid', () async {
      final repository = UserRepository(
        null,
        (_) async => profileData(name: 42),
      );

      await expectLater(
        repository.getUser('user-uid'),
        throwsA(
          isA<UserRepositoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            UserRepositoryFailureReason.invalidData,
          ),
        ),
      );
    });

    test('maps repository read failures without exposing details', () async {
      final repository = UserRepository(
        null,
        (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'private Firestore detail',
        ),
      );

      await expectLater(
        repository.getUser('user-uid'),
        throwsA(
          isA<UserRepositoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            UserRepositoryFailureReason.backend,
          ),
        ),
      );
    });
  });

  group('UserService profile loading', () {
    test('delegates a normalized uid and returns the profile', () async {
      final expected = profile(role: 'student');
      final repository = _FakeUserRepository(profile: expected);
      final service = UserService(repository);

      final result = await service.getUserProfile('  user-uid  ');

      expect(result, same(expected));
      expect(repository.lastUid, 'user-uid');
    });

    test('rejects an empty uid before repository access', () async {
      final repository = _FakeUserRepository(profile: profile(role: 'student'));
      final service = UserService(repository);

      await expectLater(
        service.getUserProfile('   '),
        throwsA(
          isA<UserProfileFailure>().having(
            (failure) => failure.reason,
            'reason',
            UserProfileFailureReason.emptyUid,
          ),
        ),
      );
      expect(repository.readCalls, 0);
    });

    test('translates missing profile errors safely', () async {
      final service = UserService(
        _FakeUserRepository(
          failureReason: UserRepositoryFailureReason.missingProfile,
        ),
      );

      await expectLater(
        service.getUserProfile('user-uid'),
        throwsA(
          isA<UserProfileFailure>()
              .having(
                (failure) => failure.reason,
                'reason',
                UserProfileFailureReason.missingProfile,
              )
              .having(
                (failure) => failure.message,
                'message',
                isNot(contains('private Firestore detail')),
              ),
        ),
      );
    });

    test('translates invalid profile data safely', () async {
      final service = UserService(
        _FakeUserRepository(
          failureReason: UserRepositoryFailureReason.invalidData,
        ),
      );

      await expectLater(
        service.getUserProfile('user-uid'),
        throwsA(
          isA<UserProfileFailure>().having(
            (failure) => failure.reason,
            'reason',
            UserProfileFailureReason.invalidProfile,
          ),
        ),
      );
    });

    test('translates backend read failures safely', () async {
      final service = UserService(
        _FakeUserRepository(failureReason: UserRepositoryFailureReason.backend),
      );

      await expectLater(
        service.getUserProfile('user-uid'),
        throwsA(
          isA<UserProfileFailure>()
              .having(
                (failure) => failure.reason,
                'reason',
                UserProfileFailureReason.backend,
              )
              .having(
                (failure) => failure.message,
                'message',
                isNot(contains('private Firestore detail')),
              ),
        ),
      );
    });
  });

  group('Post-login routing decision', () {
    final service = UserService(_FakeUserRepository());

    test('student without grade needs grade selection', () {
      expect(
        service.decidePostLoginRoute(profile(role: 'student')),
        PostLoginRoute.studentNeedsGradeSelection,
      );
    });

    test('student with grade is ready', () {
      expect(
        service.decidePostLoginRoute(
          profile(role: 'student', gradeId: 'grade-1'),
        ),
        PostLoginRoute.studentReady,
      );
    });

    test('admin is classified without inspecting grade', () {
      expect(
        service.decidePostLoginRoute(profile(role: 'admin')),
        PostLoginRoute.admin,
      );
    });

    test('unknown role is invalid', () {
      expect(
        service.decidePostLoginRoute(profile(role: 'teacher')),
        PostLoginRoute.invalidRole,
      );
    });

    test('empty role is invalid', () {
      expect(
        service.decidePostLoginRoute(profile(role: '')),
        PostLoginRoute.invalidRole,
      );
    });
  });
}

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository({this.profile, this.failureReason});

  final UserProfile? profile;
  final UserRepositoryFailureReason? failureReason;
  int readCalls = 0;
  String? lastUid;

  @override
  Future<UserProfile> getUser(String uid) async {
    readCalls++;
    lastUid = uid;
    final reason = failureReason;
    if (reason != null) throw UserRepositoryFailure(reason);
    return profile!;
  }
}
