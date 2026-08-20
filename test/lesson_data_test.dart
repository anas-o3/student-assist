import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/models/lesson.dart';
import 'package:student_assist/repositories/lesson_repository.dart';
import 'package:student_assist/services/lesson_service.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 10, 8, 30);
  final updatedAt = DateTime.utc(2026, 1, 11, 9, 45);

  Map<String, dynamic> validLessonData() => {
    'lessonId': 'lesson-equations',
    'title': 'المعادلات',
    'chapterId': 'chapter-algebra',
    'explanation': 'شرح المعادلات',
    'order': 1,
    'isActive': true,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  group('Lesson', () {
    test('parses the approved Firestore schema and timestamps', () {
      final lesson = Lesson.fromFirestore(
        documentId: 'lesson-equations',
        data: validLessonData(),
      );

      expect(lesson.lessonId, 'lesson-equations');
      expect(lesson.title, 'المعادلات');
      expect(lesson.chapterId, 'chapter-algebra');
      expect(lesson.explanation, 'شرح المعادلات');
      expect(lesson.order, 1);
      expect(lesson.isActive, isTrue);
      expect(lesson.createdAt.isAtSameMomentAs(createdAt), isTrue);
      expect(lesson.updatedAt.isAtSameMomentAs(updatedAt), isTrue);
    });

    test('rejects an empty lessonId', () {
      final data = validLessonData()..['lessonId'] = '';

      expect(
        () => Lesson.fromFirestore(documentId: 'lesson-equations', data: data),
        throwsFormatException,
      );
    });

    test('rejects a lessonId that differs from the document id', () {
      final data = validLessonData()..['lessonId'] = 'different-id';

      expect(
        () => Lesson.fromFirestore(documentId: 'lesson-equations', data: data),
        throwsFormatException,
      );
    });

    for (final invalidField in const ['title', 'chapterId', 'explanation']) {
      test('rejects an invalid $invalidField', () {
        final data = validLessonData()..[invalidField] = '   ';

        expect(
          () =>
              Lesson.fromFirestore(documentId: 'lesson-equations', data: data),
          throwsFormatException,
        );
      });
    }

    test('rejects a non-integer order', () {
      final data = validLessonData()..['order'] = 1.5;

      expect(
        () => Lesson.fromFirestore(documentId: 'lesson-equations', data: data),
        throwsFormatException,
      );
    });

    test('rejects an invalid isActive value', () {
      final data = validLessonData()..['isActive'] = 'true';

      expect(
        () => Lesson.fromFirestore(documentId: 'lesson-equations', data: data),
        throwsFormatException,
      );
    });

    for (final timestampField in const ['createdAt', 'updatedAt']) {
      test('rejects an invalid $timestampField timestamp', () {
        final data = validLessonData()..[timestampField] = createdAt;

        expect(
          () =>
              Lesson.fromFirestore(documentId: 'lesson-equations', data: data),
          throwsFormatException,
        );
      });
    }
  });

  group('LessonRepository', () {
    test('delegates the exact active lesson query contract', () async {
      String? requestedChapterId;
      bool? requestedIsActive;
      String? requestedOrderByField;
      final repository = LessonRepository(null, ({
        required chapterId,
        required isActive,
        required orderByField,
      }) async {
        requestedChapterId = chapterId;
        requestedIsActive = isActive;
        requestedOrderByField = orderByField;
        return [(documentId: 'lesson-equations', data: validLessonData())];
      });

      final lessons = await repository.loadActiveLessonsForChapter(
        'chapter-algebra',
      );

      expect(requestedChapterId, 'chapter-algebra');
      expect(requestedIsActive, isTrue);
      expect(requestedOrderByField, 'order');
      expect(lessons.single.lessonId, 'lesson-equations');
      expect(lessons.single.isActive, isTrue);
    });

    test('classifies malformed documents as invalid data', () async {
      final repository = LessonRepository(null, ({
        required chapterId,
        required isActive,
        required orderByField,
      }) async {
        return [
          (
            documentId: 'lesson-equations',
            data: validLessonData()..['title'] = '',
          ),
        ];
      });

      await expectLater(
        repository.loadActiveLessonsForChapter('chapter-algebra'),
        throwsA(
          isA<LessonRepositoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            LessonRepositoryFailureReason.invalidData,
          ),
        ),
      );
    });

    test('converts Firebase failures into repository-safe failures', () async {
      final repository = LessonRepository(null, ({
        required chapterId,
        required isActive,
        required orderByField,
      }) async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'private Firebase detail',
        );
      });

      await expectLater(
        repository.loadActiveLessonsForChapter('chapter-algebra'),
        throwsA(isA<LessonRepositoryFailure>()),
      );
    });
  });

  group('LessonService', () {
    test('trims chapterId and delegates loading to the repository', () async {
      final repository = _FakeLessonRepository(lessons: [_lesson]);
      final service = LessonService(repository);

      final lessons = await service.loadActiveLessonsForChapter(
        ' chapter-algebra ',
      );

      expect(repository.loadCalls, 1);
      expect(repository.lastChapterId, 'chapter-algebra');
      expect(lessons.single.lessonId, 'lesson-equations');
    });

    test('rejects an empty chapterId without repository access', () async {
      final repository = _FakeLessonRepository();
      final service = LessonService(repository);

      await expectLater(
        service.loadActiveLessonsForChapter('   '),
        throwsA(
          isA<LessonFailure>().having(
            (failure) => failure.reason,
            'reason',
            LessonFailureReason.emptyChapterId,
          ),
        ),
      );
      expect(repository.loadCalls, 0);
    });

    test('translates repository failures without exposing details', () async {
      final service = LessonService(
        _FakeLessonRepository(
          failure: const LessonRepositoryFailure(
            LessonRepositoryFailureReason.backend,
          ),
        ),
      );

      await expectLater(
        service.loadActiveLessonsForChapter('chapter-algebra'),
        throwsA(
          isA<LessonFailure>()
              .having(
                (failure) => failure.message,
                'message',
                contains('تعذر تحميل الدروس'),
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

final _lesson = Lesson(
  lessonId: 'lesson-equations',
  title: 'المعادلات',
  chapterId: 'chapter-algebra',
  explanation: 'شرح المعادلات',
  order: 1,
  isActive: true,
  createdAt: DateTime.utc(2026, 1, 10, 8, 30),
  updatedAt: DateTime.utc(2026, 1, 11, 9, 45),
);

class _FakeLessonRepository extends LessonRepository {
  _FakeLessonRepository({this.lessons = const [], this.failure});

  final List<Lesson> lessons;
  final LessonRepositoryFailure? failure;
  int loadCalls = 0;
  String? lastChapterId;

  @override
  Future<List<Lesson>> loadActiveLessonsForChapter(String chapterId) async {
    loadCalls++;
    lastChapterId = chapterId;
    final repositoryFailure = failure;
    if (repositoryFailure != null) throw repositoryFailure;
    return lessons;
  }
}
