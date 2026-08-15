import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/models/grade.dart';
import 'package:student_assist/repositories/grade_repository.dart';
import 'package:student_assist/repositories/user_repository.dart';
import 'package:student_assist/services/grade_service.dart';
import 'package:student_assist/services/user_service.dart';

void main() {
  group('Grade', () {
    test('parses and maps the approved Firestore schema', () {
      final grade = Grade.fromFirestore(
        documentId: 'grade-10',
        data: const {
          'gradeId': 'grade-10',
          'name': 'الصف العاشر',
          'order': 10,
          'isActive': true,
        },
      );

      expect(grade.gradeId, 'grade-10');
      expect(grade.name, 'الصف العاشر');
      expect(grade.order, 10);
      expect(grade.isActive, isTrue);
      expect(grade.toFirestore(), {
        'gradeId': 'grade-10',
        'name': 'الصف العاشر',
        'order': 10,
        'isActive': true,
      });
    });

    test('rejects a gradeId that differs from the document id', () {
      expect(
        () => Grade.fromFirestore(
          documentId: 'grade-10',
          data: const {
            'gradeId': 'grade-11',
            'name': 'الصف العاشر',
            'order': 10,
            'isActive': true,
          },
        ),
        throwsFormatException,
      );
    });
  });

  group('GradeService', () {
    test(
      'delegates active-grade loading and preserves repository order',
      () async {
        final repository = _FakeGradeRepository(
          grades: const [
            Grade(
              gradeId: 'grade-10',
              name: 'الصف العاشر',
              order: 10,
              isActive: true,
            ),
            Grade(
              gradeId: 'grade-11',
              name: 'الصف الحادي عشر',
              order: 11,
              isActive: true,
            ),
          ],
        );
        final service = GradeService(repository);

        final grades = await service.loadActiveGrades();

        expect(repository.loadCalls, 1);
        expect(grades.map((grade) => grade.order), [10, 11]);
      },
    );

    test('maps repository failures to a safe service error', () async {
      final service = GradeService(_FakeGradeRepository(shouldFail: true));

      await expectLater(
        service.loadActiveGrades(),
        throwsA(
          isA<GradeFailure>()
              .having(
                (failure) => failure.message,
                'message',
                contains('تعذر تحميل الصفوف'),
              )
              .having(
                (failure) => failure.message,
                'message',
                isNot(contains('private Firebase detail')),
              ),
        ),
      );
    });
  });

  group('User grade selection', () {
    test('delegates a normalized gradeId to UserRepository', () async {
      final repository = _FakeUserRepository();
      final service = UserService(repository);

      await service.selectGrade(uid: 'student-uid', gradeId: ' grade-10 ');

      expect(repository.updateCalls, 1);
      expect(repository.lastUid, 'student-uid');
      expect(repository.lastGradeId, 'grade-10');
    });

    test('rejects an empty gradeId without calling the repository', () async {
      final repository = _FakeUserRepository();
      final service = UserService(repository);

      await expectLater(
        service.selectGrade(uid: 'student-uid', gradeId: '   '),
        throwsA(isA<UserGradeSelectionFailure>()),
      );
      expect(repository.updateCalls, 0);
    });

    test('grade update payload contains no protected user fields', () {
      expect(UserRepository.gradeSelectionData('grade-10'), {
        'gradeId': 'grade-10',
      });
    });

    test('maps repository failures to a safe service error', () async {
      final service = UserService(_FakeUserRepository(shouldFail: true));

      await expectLater(
        service.selectGrade(uid: 'student-uid', gradeId: 'grade-10'),
        throwsA(
          isA<UserGradeSelectionFailure>()
              .having(
                (failure) => failure.message,
                'message',
                contains('تعذر حفظ الصف'),
              )
              .having(
                (failure) => failure.message,
                'message',
                isNot(contains('private Firebase detail')),
              ),
        ),
      );
    });
  });
}

class _FakeGradeRepository extends GradeRepository {
  _FakeGradeRepository({this.grades = const [], this.shouldFail = false});

  final List<Grade> grades;
  final bool shouldFail;
  int loadCalls = 0;

  @override
  Future<List<Grade>> loadActiveGrades() async {
    loadCalls++;
    if (shouldFail) throw const GradeRepositoryFailure();
    return grades;
  }
}

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository({this.shouldFail = false});

  final bool shouldFail;
  int updateCalls = 0;
  String? lastUid;
  String? lastGradeId;

  @override
  Future<void> updateGradeId({
    required String uid,
    required String gradeId,
  }) async {
    updateCalls++;
    lastUid = uid;
    lastGradeId = gradeId;
    if (shouldFail) throw const UserRepositoryFailure();
  }
}
