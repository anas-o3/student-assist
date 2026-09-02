import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/models/question.dart';
import 'package:student_assist/models/quiz_attempt.dart';
import 'package:student_assist/repositories/question_repository.dart';
import 'package:student_assist/repositories/quiz_attempt_repository.dart';
import 'package:student_assist/services/quiz_service.dart';

void main() {
  final completedAt = DateTime.utc(2026, 8, 31, 12);

  Map<String, dynamic> validQuestionData() => {
    'questionId': 'question-1',
    'lessonId': 'lesson-1',
    'questionText': 'ما الإجابة الصحيحة؟',
    'options': ['الخيار الأول', 'الخيار الثاني'],
    'correctAnswerIndex': 1,
    'explanation': 'الخيار الثاني هو الصحيح.',
    'order': 1,
    'isActive': true,
  };

  Map<String, dynamic> validAttemptData() => {
    'attemptId': 'attempt-1',
    'userId': 'student-1',
    'lessonId': 'lesson-1',
    'score': 2,
    'totalQuestions': 3,
    'percentage': 66.6666666667,
    'completedAt': Timestamp.fromDate(completedAt),
  };

  group('Question', () {
    test('parses the approved Firestore schema', () {
      final question = Question.fromFirestore(
        documentId: 'question-1',
        data: validQuestionData(),
      );

      expect(question.questionId, 'question-1');
      expect(question.lessonId, 'lesson-1');
      expect(question.questionText, 'ما الإجابة الصحيحة؟');
      expect(question.options, ['الخيار الأول', 'الخيار الثاني']);
      expect(question.correctAnswerIndex, 1);
      expect(question.explanation, 'الخيار الثاني هو الصحيح.');
      expect(question.order, 1);
      expect(question.isActive, isTrue);
      expect(() => question.options.add('تعديل'), throwsUnsupportedError);
    });

    test('rejects a questionId that differs from the document id', () {
      final data = validQuestionData()..['questionId'] = 'another-question';

      expect(
        () => Question.fromFirestore(documentId: 'question-1', data: data),
        throwsFormatException,
      );
    });

    for (final field in const ['lessonId', 'questionText', 'explanation']) {
      test('rejects an empty $field', () {
        final data = validQuestionData()..[field] = '   ';

        expect(
          () => Question.fromFirestore(documentId: 'question-1', data: data),
          throwsFormatException,
        );
      });
    }

    test('rejects malformed options', () {
      for (final options in <Object>[[], ['صحيح', 2], ['صحيح', '   ']]) {
        final data = validQuestionData()..['options'] = options;

        expect(
          () => Question.fromFirestore(documentId: 'question-1', data: data),
          throwsFormatException,
        );
      }
    });

    test('rejects an out-of-range correctAnswerIndex', () {
      for (final index in const [-1, 2]) {
        final data = validQuestionData()..['correctAnswerIndex'] = index;

        expect(
          () => Question.fromFirestore(documentId: 'question-1', data: data),
          throwsFormatException,
        );
      }
    });

    test('rejects invalid order and isActive field types', () {
      expect(
        () => Question.fromFirestore(
          documentId: 'question-1',
          data: validQuestionData()..['order'] = 1.5,
        ),
        throwsFormatException,
      );
      expect(
        () => Question.fromFirestore(
          documentId: 'question-1',
          data: validQuestionData()..['isActive'] = 'true',
        ),
        throwsFormatException,
      );
    });
  });

  group('QuizAttempt', () {
    test('parses and serializes the approved Firestore schema', () {
      final attempt = QuizAttempt.fromFirestore(
        documentId: 'attempt-1',
        data: validAttemptData(),
      );

      expect(attempt.attemptId, 'attempt-1');
      expect(attempt.userId, 'student-1');
      expect(attempt.lessonId, 'lesson-1');
      expect(attempt.score, 2);
      expect(attempt.totalQuestions, 3);
      expect(attempt.percentage, closeTo(66.6666666667, 0.000001));
      expect(attempt.completedAt.isAtSameMomentAs(completedAt), isTrue);
      expect(attempt.toFirestore(), validAttemptData());
    });

    test('accepts an integer Firestore percentage as a Number', () {
      final attempt = QuizAttempt.fromFirestore(
        documentId: 'attempt-1',
        data: validAttemptData()..['percentage'] = 100,
      );

      expect(attempt.percentage, 100.0);
    });

    test('rejects identity, relationship, score, and timestamp defects', () {
      final invalidData = <Map<String, dynamic>>[
        validAttemptData()..['attemptId'] = 'other-attempt',
        validAttemptData()..['userId'] = '',
        validAttemptData()..['lessonId'] = '   ',
        validAttemptData()..['score'] = 1.5,
        validAttemptData()..['score'] = -1,
        validAttemptData()..['score'] = 4,
        validAttemptData()..['totalQuestions'] = 0,
        validAttemptData()..['percentage'] = -1,
        validAttemptData()..['percentage'] = 101,
        validAttemptData()..['completedAt'] = completedAt,
      ];

      for (final data in invalidData) {
        expect(
          () => QuizAttempt.fromFirestore(
            documentId: 'attempt-1',
            data: data,
          ),
          throwsFormatException,
        );
      }
    });
  });

  group('QuestionRepository', () {
    test('delegates the exact active ordered question query contract', () async {
      String? capturedLessonId;
      bool? capturedIsActive;
      String? capturedOrderByField;
      final repository = QuestionRepository(null, ({
        required lessonId,
        required isActive,
        required orderByField,
      }) async {
        capturedLessonId = lessonId;
        capturedIsActive = isActive;
        capturedOrderByField = orderByField;
        return [(documentId: 'question-1', data: validQuestionData())];
      });

      final questions = await repository.loadActiveQuestionsForLesson(
        'lesson-1',
      );

      expect(capturedLessonId, 'lesson-1');
      expect(capturedIsActive, isTrue);
      expect(capturedOrderByField, 'order');
      expect(questions.single.questionId, 'question-1');
    });

    test('classifies malformed question documents safely', () async {
      final repository = QuestionRepository(null, ({
        required lessonId,
        required isActive,
        required orderByField,
      }) async {
        return [
          (
            documentId: 'question-1',
            data: validQuestionData()..['options'] = [],
          ),
        ];
      });

      await expectLater(
        repository.loadActiveQuestionsForLesson('lesson-1'),
        throwsA(
          isA<QuestionRepositoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            QuestionRepositoryFailureReason.invalidData,
          ),
        ),
      );
    });

    test('translates Firebase question failures safely', () async {
      final repository = QuestionRepository(null, ({
        required lessonId,
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
        repository.loadActiveQuestionsForLesson('lesson-1'),
        throwsA(
          isA<QuestionRepositoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            QuestionRepositoryFailureReason.backend,
          ),
        ),
      );
    });
  });

  group('QuizAttemptRepository', () {
    test('delegates completed attempt persistence without answer fields', () async {
      Map<String, Object?>? captured;
      final repository = QuizAttemptRepository(null, ({
        required userId,
        required lessonId,
        required score,
        required totalQuestions,
        required percentage,
        required completedAt,
      }) async {
        captured = {
          'userId': userId,
          'lessonId': lessonId,
          'score': score,
          'totalQuestions': totalQuestions,
          'percentage': percentage,
          'completedAt': completedAt,
        };
        return _attempt(completedAt: completedAt);
      });

      await repository.createAttempt(
        userId: 'student-1',
        lessonId: 'lesson-1',
        score: 2,
        totalQuestions: 3,
        percentage: 200 / 3,
        completedAt: completedAt,
      );

      expect(captured?['userId'], 'student-1');
      expect(captured?['lessonId'], 'lesson-1');
      expect(captured?['score'], 2);
      expect(captured?['totalQuestions'], 3);
      expect(captured?.keys, isNot(contains('answers')));
    });

    test('translates Firebase persistence failures safely', () async {
      final repository = QuizAttemptRepository(null, ({
        required userId,
        required lessonId,
        required score,
        required totalQuestions,
        required percentage,
        required completedAt,
      }) async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'private Firebase detail',
        );
      });

      await expectLater(
        repository.createAttempt(
          userId: 'student-1',
          lessonId: 'lesson-1',
          score: 1,
          totalQuestions: 1,
          percentage: 100,
          completedAt: completedAt,
        ),
        throwsA(isA<QuizAttemptRepositoryFailure>()),
      );
    });
  });

  group('QuizService', () {
    test('trims lessonId and delegates question loading', () async {
      final questions = _questions();
      final repository = _FakeQuestionRepository(questions: questions);
      final service = QuizService(repository);

      final result = await service.loadActiveQuestionsForLesson(' lesson-1 ');

      expect(repository.lastLessonId, 'lesson-1');
      expect(result, same(questions));
    });

    test('rejects an empty lessonId without repository access', () async {
      final repository = _FakeQuestionRepository();
      final service = QuizService(repository);

      await expectLater(
        service.loadActiveQuestionsForLesson('   '),
        throwsA(
          isA<QuizFailure>().having(
            (failure) => failure.reason,
            'reason',
            QuizFailureReason.emptyLessonId,
          ),
        ),
      );
      expect(repository.loadCalls, 0);
    });

    test('evaluates authoritative answers and calculates score safely', () async {
      final questions = _questions();
      final attempts = _FakeQuizAttemptRepository();
      final service = QuizService(
        _FakeQuestionRepository(),
        attempts,
        () => completedAt,
      );

      final result = await service.evaluateAndSaveAttempt(
        userId: ' student-1 ',
        lessonId: ' lesson-1 ',
        questions: questions,
        selectedAnswerIndexes: {
          'question-1': 1,
          'question-2': 0,
          'question-3': 0,
        },
      );

      expect(result.answerCorrectness, {
        'question-1': true,
        'question-2': false,
        'question-3': true,
      });
      expect(result.attempt.score, 2);
      expect(result.attempt.totalQuestions, 3);
      expect(result.attempt.percentage, closeTo(200 / 3, 0.000001));
      expect(attempts.lastUserId, 'student-1');
      expect(attempts.lastLessonId, 'lesson-1');
      expect(attempts.lastCompletedAt, completedAt);
    });

    test('rejects missing, unknown, and out-of-range answers', () async {
      final questions = _questions();
      final service = QuizService(
        _FakeQuestionRepository(),
        _FakeQuizAttemptRepository(),
      );
      final invalidAnswers = <Map<String, int>>[
        {'question-1': 1},
        {
          'question-1': 1,
          'question-2': 1,
          'question-3': 0,
          'unknown-question': 0,
        },
        {'question-1': 2, 'question-2': 1, 'question-3': 0},
      ];

      for (final answers in invalidAnswers) {
        await expectLater(
          service.evaluateAndSaveAttempt(
            userId: 'student-1',
            lessonId: 'lesson-1',
            questions: questions,
            selectedAnswerIndexes: answers,
          ),
          throwsA(
            isA<QuizFailure>().having(
              (failure) => failure.reason,
              'reason',
              QuizFailureReason.invalidAnswers,
            ),
          ),
        );
      }
    });

    test('rejects empty and inconsistent question sets', () async {
      final service = QuizService(
        _FakeQuestionRepository(),
        _FakeQuizAttemptRepository(),
      );

      await expectLater(
        service.evaluateAndSaveAttempt(
          userId: 'student-1',
          lessonId: 'lesson-1',
          questions: const [],
          selectedAnswerIndexes: const {},
        ),
        throwsA(
          isA<QuizFailure>().having(
            (failure) => failure.reason,
            'reason',
            QuizFailureReason.noQuestions,
          ),
        ),
      );
      await expectLater(
        service.evaluateAndSaveAttempt(
          userId: 'student-1',
          lessonId: 'another-lesson',
          questions: _questions(),
          selectedAnswerIndexes: const {
            'question-1': 1,
            'question-2': 1,
            'question-3': 0,
          },
        ),
        throwsA(
          isA<QuizFailure>().having(
            (failure) => failure.reason,
            'reason',
            QuizFailureReason.invalidQuestions,
          ),
        ),
      );
    });

    test('translates question load failures without raw details', () async {
      final service = QuizService(
        _FakeQuestionRepository(
          failure: const QuestionRepositoryFailure(),
        ),
      );

      await expectLater(
        service.loadActiveQuestionsForLesson('lesson-1'),
        throwsA(
          isA<QuizFailure>()
              .having(
                (failure) => failure.reason,
                'reason',
                QuizFailureReason.loadFailed,
              )
              .having(
                (failure) => failure.message,
                'message',
                isNot(contains('private Firebase detail')),
              ),
        ),
      );
    });

    test('translates attempt persistence failures safely', () async {
      final service = QuizService(
        _FakeQuestionRepository(),
        _FakeQuizAttemptRepository(
          failure: const QuizAttemptRepositoryFailure(),
        ),
      );

      await expectLater(
        service.evaluateAndSaveAttempt(
          userId: 'student-1',
          lessonId: 'lesson-1',
          questions: _questions(),
          selectedAnswerIndexes: const {
            'question-1': 1,
            'question-2': 1,
            'question-3': 0,
          },
        ),
        throwsA(
          isA<QuizFailure>().having(
            (failure) => failure.reason,
            'reason',
            QuizFailureReason.saveFailed,
          ),
        ),
      );
    });
  });
}

List<Question> _questions() => const [
  Question(
    questionId: 'question-1',
    lessonId: 'lesson-1',
    questionText: 'السؤال الأول',
    options: ['خطأ', 'صحيح'],
    correctAnswerIndex: 1,
    explanation: 'التفسير الأول',
    order: 1,
    isActive: true,
  ),
  Question(
    questionId: 'question-2',
    lessonId: 'lesson-1',
    questionText: 'السؤال الثاني',
    options: ['خطأ', 'صحيح'],
    correctAnswerIndex: 1,
    explanation: 'التفسير الثاني',
    order: 2,
    isActive: true,
  ),
  Question(
    questionId: 'question-3',
    lessonId: 'lesson-1',
    questionText: 'السؤال الثالث',
    options: ['صحيح', 'خطأ'],
    correctAnswerIndex: 0,
    explanation: 'التفسير الثالث',
    order: 3,
    isActive: true,
  ),
];

QuizAttempt _attempt({required DateTime completedAt}) => QuizAttempt(
  attemptId: 'attempt-created',
  userId: 'student-1',
  lessonId: 'lesson-1',
  score: 2,
  totalQuestions: 3,
  percentage: 200 / 3,
  completedAt: completedAt,
);

class _FakeQuestionRepository extends QuestionRepository {
  _FakeQuestionRepository({this.questions = const [], this.failure});

  final List<Question> questions;
  final QuestionRepositoryFailure? failure;
  int loadCalls = 0;
  String? lastLessonId;

  @override
  Future<List<Question>> loadActiveQuestionsForLesson(String lessonId) async {
    loadCalls++;
    lastLessonId = lessonId;
    final repositoryFailure = failure;
    if (repositoryFailure != null) throw repositoryFailure;
    return questions;
  }
}

class _FakeQuizAttemptRepository extends QuizAttemptRepository {
  _FakeQuizAttemptRepository({this.failure});

  final QuizAttemptRepositoryFailure? failure;
  String? lastUserId;
  String? lastLessonId;
  DateTime? lastCompletedAt;

  @override
  Future<QuizAttempt> createAttempt({
    required String userId,
    required String lessonId,
    required int score,
    required int totalQuestions,
    required double percentage,
    required DateTime completedAt,
  }) async {
    final repositoryFailure = failure;
    if (repositoryFailure != null) throw repositoryFailure;
    lastUserId = userId;
    lastLessonId = lessonId;
    lastCompletedAt = completedAt;
    return QuizAttempt(
      attemptId: 'attempt-created',
      userId: userId,
      lessonId: lessonId,
      score: score,
      totalQuestions: totalQuestions,
      percentage: percentage,
      completedAt: completedAt,
    );
  }
}
