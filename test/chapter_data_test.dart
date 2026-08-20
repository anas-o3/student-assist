import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/models/chapter.dart';
import 'package:student_assist/repositories/chapter_repository.dart';
import 'package:student_assist/services/chapter_service.dart';

void main() {
  group('Chapter', () {
    test('parses the approved Firestore schema', () {
      final chapter = Chapter.fromFirestore(
        documentId: 'chapter-algebra',
        data: const {
          'chapterId': 'chapter-algebra',
          'title': 'الجبر',
          'subjectId': 'subject-math',
          'order': 1,
          'isActive': true,
        },
      );

      expect(chapter.chapterId, 'chapter-algebra');
      expect(chapter.title, 'الجبر');
      expect(chapter.subjectId, 'subject-math');
      expect(chapter.order, 1);
      expect(chapter.isActive, isTrue);
    });

    test('rejects a mismatched document id', () {
      expect(
        () => Chapter.fromFirestore(
          documentId: 'chapter-algebra',
          data: const {
            'chapterId': 'different-id',
            'title': 'الجبر',
            'subjectId': 'subject-math',
            'order': 1,
            'isActive': true,
          },
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed field types including a non-integer order', () {
      expect(
        () => Chapter.fromFirestore(
          documentId: 'chapter-algebra',
          data: const {
            'chapterId': 'chapter-algebra',
            'title': 'الجبر',
            'subjectId': 'subject-math',
            'order': 1.5,
            'isActive': true,
          },
        ),
        throwsFormatException,
      );
    });
  });

  group('ChapterRepository', () {
    test('delegates subject filtering and preserves query ordering', () async {
      String? requestedSubjectId;
      final repository = ChapterRepository(null, (subjectId) async {
        requestedSubjectId = subjectId;
        return const [
          (
            documentId: 'chapter-algebra',
            data: {
              'chapterId': 'chapter-algebra',
              'title': 'الجبر',
              'subjectId': 'subject-math',
              'order': 1,
              'isActive': true,
            },
          ),
          (
            documentId: 'chapter-geometry',
            data: {
              'chapterId': 'chapter-geometry',
              'title': 'الهندسة',
              'subjectId': 'subject-math',
              'order': 2,
              'isActive': true,
            },
          ),
        ];
      });

      final chapters = await repository.loadActiveChaptersForSubject(
        'subject-math',
      );

      expect(requestedSubjectId, 'subject-math');
      expect(chapters.map((chapter) => chapter.order), [1, 2]);
      expect(chapters.every((chapter) => chapter.isActive), isTrue);
    });

    test('classifies malformed documents as invalid data', () async {
      final repository = ChapterRepository(null, (_) async {
        return const [
          (
            documentId: 'chapter-algebra',
            data: {
              'chapterId': 'chapter-algebra',
              'title': '',
              'subjectId': 'subject-math',
              'order': 1,
              'isActive': true,
            },
          ),
        ];
      });

      await expectLater(
        repository.loadActiveChaptersForSubject('subject-math'),
        throwsA(
          isA<ChapterRepositoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            ChapterRepositoryFailureReason.invalidData,
          ),
        ),
      );
    });

    test('converts Firebase failures into repository-safe failures', () async {
      final repository = ChapterRepository(null, (_) async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'private Firebase detail',
        );
      });

      await expectLater(
        repository.loadActiveChaptersForSubject('subject-math'),
        throwsA(isA<ChapterRepositoryFailure>()),
      );
    });
  });

  group('ChapterService', () {
    test('trims subjectId and delegates loading to the repository', () async {
      final repository = _FakeChapterRepository(chapters: const [_algebra]);
      final service = ChapterService(repository);

      final chapters = await service.loadActiveChaptersForSubject(
        ' subject-math ',
      );

      expect(repository.loadCalls, 1);
      expect(repository.lastSubjectId, 'subject-math');
      expect(chapters.single.chapterId, 'chapter-algebra');
    });

    test('rejects an empty subjectId without repository access', () async {
      final repository = _FakeChapterRepository();
      final service = ChapterService(repository);

      await expectLater(
        service.loadActiveChaptersForSubject('   '),
        throwsA(
          isA<ChapterFailure>().having(
            (failure) => failure.reason,
            'reason',
            ChapterFailureReason.emptySubjectId,
          ),
        ),
      );
      expect(repository.loadCalls, 0);
    });

    test('translates repository failures without exposing details', () async {
      final service = ChapterService(
        _FakeChapterRepository(
          failure: const ChapterRepositoryFailure(
            ChapterRepositoryFailureReason.backend,
          ),
        ),
      );

      await expectLater(
        service.loadActiveChaptersForSubject('subject-math'),
        throwsA(
          isA<ChapterFailure>()
              .having(
                (failure) => failure.message,
                'message',
                contains('تعذر تحميل الأبواب'),
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

const _algebra = Chapter(
  chapterId: 'chapter-algebra',
  title: 'الجبر',
  subjectId: 'subject-math',
  order: 1,
  isActive: true,
);

class _FakeChapterRepository extends ChapterRepository {
  _FakeChapterRepository({this.chapters = const [], this.failure});

  final List<Chapter> chapters;
  final ChapterRepositoryFailure? failure;
  int loadCalls = 0;
  String? lastSubjectId;

  @override
  Future<List<Chapter>> loadActiveChaptersForSubject(String subjectId) async {
    loadCalls++;
    lastSubjectId = subjectId;
    final repositoryFailure = failure;
    if (repositoryFailure != null) throw repositoryFailure;
    return chapters;
  }
}
