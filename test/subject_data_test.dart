import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/models/subject.dart';
import 'package:student_assist/repositories/subject_repository.dart';
import 'package:student_assist/services/subject_service.dart';

void main() {
  group('Subject', () {
    test('parses the approved Firestore schema', () {
      final subject = Subject.fromFirestore(
        documentId: 'subject-math',
        data: const {
          'subjectId': 'subject-math',
          'name': 'الرياضيات',
          'gradeId': 'grade-1',
          'imageUrl': 'https://example.com/math.png',
          'order': 1,
          'isActive': true,
        },
      );

      expect(subject.subjectId, 'subject-math');
      expect(subject.name, 'الرياضيات');
      expect(subject.gradeId, 'grade-1');
      expect(subject.imageUrl, 'https://example.com/math.png');
      expect(subject.order, 1);
      expect(subject.isActive, isTrue);
    });

    test('rejects malformed fields and a mismatched document id', () {
      expect(
        () => Subject.fromFirestore(
          documentId: 'subject-math',
          data: const {
            'subjectId': 'different-id',
            'name': 'الرياضيات',
            'gradeId': 'grade-1',
            'imageUrl': '',
            'order': 'first',
            'isActive': true,
          },
        ),
        throwsFormatException,
      );
    });

    test('maps a missing imageUrl to the supported empty fallback', () {
      final subject = Subject.fromFirestore(
        documentId: 'subject-math',
        data: const {
          'subjectId': 'subject-math',
          'name': 'الرياضيات',
          'gradeId': 'grade-1',
          'order': 1,
          'isActive': true,
        },
      );

      expect(subject.imageUrl, isEmpty);
    });
  });

  group('SubjectRepository', () {
    test('delegates grade filtering and preserves query ordering', () async {
      String? requestedGradeId;
      final repository = SubjectRepository(null, (gradeId) async {
        requestedGradeId = gradeId;
        return const [
          (
            documentId: 'subject-arabic',
            data: {
              'subjectId': 'subject-arabic',
              'name': 'اللغة العربية',
              'gradeId': 'grade-2',
              'imageUrl': '',
              'order': 1,
              'isActive': true,
            },
          ),
          (
            documentId: 'subject-math',
            data: {
              'subjectId': 'subject-math',
              'name': 'الرياضيات',
              'gradeId': 'grade-2',
              'imageUrl': '',
              'order': 2,
              'isActive': true,
            },
          ),
        ];
      });

      final subjects = await repository.loadActiveSubjectsForGrade('grade-2');

      expect(requestedGradeId, 'grade-2');
      expect(subjects.map((subject) => subject.order), [1, 2]);
      expect(subjects.every((subject) => subject.isActive), isTrue);
    });

    test('classifies malformed documents as invalid data', () async {
      final repository = SubjectRepository(null, (_) async {
        return const [
          (
            documentId: 'subject-math',
            data: {
              'subjectId': 'subject-math',
              'name': 'الرياضيات',
              'gradeId': 'grade-1',
              'imageUrl': '',
              'order': 1.5,
              'isActive': true,
            },
          ),
        ];
      });

      await expectLater(
        repository.loadActiveSubjectsForGrade('grade-1'),
        throwsA(
          isA<SubjectRepositoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            SubjectRepositoryFailureReason.invalidData,
          ),
        ),
      );
    });

    test('converts Firebase failures into repository-safe failures', () async {
      final repository = SubjectRepository(null, (_) async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'private Firebase detail',
        );
      });

      await expectLater(
        repository.loadActiveSubjectsForGrade('grade-1'),
        throwsA(isA<SubjectRepositoryFailure>()),
      );
    });
  });

  group('SubjectService', () {
    test('trims gradeId and delegates loading to the repository', () async {
      final repository = _FakeSubjectRepository(
        subjects: const [
          Subject(
            subjectId: 'subject-math',
            name: 'الرياضيات',
            gradeId: 'grade-1',
            imageUrl: '',
            order: 1,
            isActive: true,
          ),
        ],
      );
      final service = SubjectService(repository);

      final subjects = await service.loadActiveSubjectsForGrade(' grade-1 ');

      expect(repository.loadCalls, 1);
      expect(repository.lastGradeId, 'grade-1');
      expect(subjects.single.subjectId, 'subject-math');
    });

    test('rejects an empty gradeId without calling the repository', () async {
      final repository = _FakeSubjectRepository();
      final service = SubjectService(repository);

      await expectLater(
        service.loadActiveSubjectsForGrade('   '),
        throwsA(
          isA<SubjectFailure>().having(
            (failure) => failure.reason,
            'reason',
            SubjectFailureReason.emptyGradeId,
          ),
        ),
      );
      expect(repository.loadCalls, 0);
    });

    test('translates repository failures without exposing details', () async {
      final service = SubjectService(
        _FakeSubjectRepository(
          failure: const SubjectRepositoryFailure(
            SubjectRepositoryFailureReason.backend,
          ),
        ),
      );

      await expectLater(
        service.loadActiveSubjectsForGrade('grade-1'),
        throwsA(
          isA<SubjectFailure>()
              .having(
                (failure) => failure.message,
                'message',
                contains('تعذر تحميل المواد'),
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

class _FakeSubjectRepository extends SubjectRepository {
  _FakeSubjectRepository({this.subjects = const [], this.failure});

  final List<Subject> subjects;
  final SubjectRepositoryFailure? failure;
  int loadCalls = 0;
  String? lastGradeId;

  @override
  Future<List<Subject>> loadActiveSubjectsForGrade(String gradeId) async {
    loadCalls++;
    lastGradeId = gradeId;
    final repositoryFailure = failure;
    if (repositoryFailure != null) throw repositoryFailure;
    return subjects;
  }
}
