import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/lesson.dart';
import 'package:student_assist/models/question.dart';
import 'package:student_assist/models/quiz_attempt.dart';
import 'package:student_assist/screens/student/quiz_screen.dart';
import 'package:student_assist/services/auth_service.dart';
import 'package:student_assist/services/quiz_service.dart';

void main() {
  testWidgets('shows loading while questions are requested', (tester) async {
    final completer = Completer<List<Question>>();
    await _pumpQuiz(
      tester,
      quizService: _FakeQuizService(loader: (_) => completer.future),
    );

    expect(find.byKey(const ValueKey('quiz-loading')), findsOneWidget);
    expect(find.text('جارٍ تحميل أسئلة الاختبار...'), findsOneWidget);

    completer.complete(_questions());
    await tester.pumpAndSettle();
  });

  testWidgets('renders questions in order and preserves option selection', (
    tester,
  ) async {
    final questions = _questions().reversed.toList();
    await _pumpQuiz(
      tester,
      quizService: _FakeQuizService(loader: (_) async => questions),
    );
    await tester.pumpAndSettle();

    expect(find.text('السؤال الأول'), findsOneWidget);
    expect(find.text('السؤال 1 من 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quiz-option-question-1-1')));
    await tester.tap(find.byKey(const Key('quiz-next-button')));
    await tester.pump();

    expect(find.text('السؤال الثاني'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quiz-previous-button')));
    await tester.pump();
    final selectedIcon = find.descendant(
      of: find.byKey(const Key('quiz-option-question-1-1')),
      matching: find.byIcon(Icons.radio_button_checked_rounded),
    );
    expect(selectedIcon, findsOneWidget);
  });

  testWidgets('rejects incomplete submission without calling the service', (
    tester,
  ) async {
    final service = _FakeQuizService(loader: (_) async => [_questions().first]);
    await _pumpQuiz(tester, quizService: service);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quiz-submit-button')));
    await tester.pump();

    expect(find.text('يرجى الإجابة عن جميع أسئلة الاختبار.'), findsOneWidget);
    expect(service.evaluateCalls, 0);
  });

  testWidgets('submits through QuizService with the authenticated user', (
    tester,
  ) async {
    final service = _FakeQuizService(loader: (_) async => [_questions().first]);
    await _pumpQuiz(
      tester,
      quizService: service,
      authService: _FakeAuthService('student-uid'),
      resultScreenBuilder:
          ({
            required questions,
            required selectedAnswerIndexes,
            required evaluation,
          }) => const Scaffold(body: Text('النتيجة التجريبية')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quiz-option-question-1-1')));
    await tester.tap(find.byKey(const Key('quiz-submit-button')));
    await tester.pumpAndSettle();

    expect(service.evaluateCalls, 1);
    expect(service.lastUserId, 'student-uid');
    expect(service.lastLessonId, 'lesson-1');
    expect(service.lastAnswers, {'question-1': 1});
    expect(find.text('النتيجة التجريبية'), findsOneWidget);
  });

  testWidgets('shows submitting state and prevents duplicate submission', (
    tester,
  ) async {
    final completer = Completer<QuizEvaluationResult>();
    final service = _FakeQuizService(
      loader: (_) async => [_questions().first],
      evaluator: (_) => completer.future,
    );
    await _pumpQuiz(tester, quizService: service);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quiz-option-question-1-1')));
    await tester.tap(find.byKey(const Key('quiz-submit-button')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('quiz-submit-button')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(service.evaluateCalls, 1);
    expect(find.byKey(const Key('quiz-submit-progress')), findsOneWidget);

    completer.complete(_evaluation());
    await tester.pumpAndSettle();
  });

  testWidgets('shows an empty state when no questions are available', (
    tester,
  ) async {
    await _pumpQuiz(
      tester,
      quizService: _FakeQuizService(loader: (_) async => const []),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quiz-empty')), findsOneWidget);
    expect(find.text('لا توجد أسئلة متاحة لهذا الدرس حاليًا.'), findsOneWidget);
  });

  testWidgets('shows a safe load error and retries', (tester) async {
    var shouldFail = true;
    final service = _FakeQuizService(
      loader: (_) async {
        if (shouldFail) {
          throw const QuizFailure(
            'تعذر تحميل أسئلة الاختبار. حاول مرة أخرى.',
            QuizFailureReason.loadFailed,
          );
        }
        return _questions();
      },
    );
    await _pumpQuiz(tester, quizService: service);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quiz-load-error')), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);

    shouldFail = false;
    await tester.tap(find.byKey(const Key('quiz-retry-button')));
    await tester.pumpAndSettle();

    expect(service.loadCalls, 2);
    expect(find.text('السؤال الأول'), findsOneWidget);
  });

  testWidgets('locks retry after an ambiguous attempt save failure', (
    tester,
  ) async {
    final service = _FakeQuizService(
      loader: (_) async => [_questions().first],
      evaluator: (_) async => throw const QuizFailure(
        'private detail',
        QuizFailureReason.saveFailed,
      ),
    );
    await _pumpQuiz(tester, quizService: service);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quiz-option-question-1-1')));
    await tester.tap(find.byKey(const Key('quiz-submit-button')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'تعذر التأكد من حفظ النتيجة. ارجع إلى الدرس ثم أعد فتح الاختبار.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('private detail'), findsNothing);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('quiz-submit-button')),
    );
    expect(button.onPressed, isNull);
    expect(service.evaluateCalls, 1);
  });

  testWidgets('does not submit without an authenticated user', (tester) async {
    final service = _FakeQuizService(loader: (_) async => [_questions().first]);
    await _pumpQuiz(
      tester,
      quizService: service,
      authService: _FakeAuthService(null),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quiz-option-question-1-1')));
    await tester.tap(find.byKey(const Key('quiz-submit-button')));
    await tester.pump();

    expect(
      find.text('تعذر التحقق من جلسة المستخدم. سجل الدخول مرة أخرى.'),
      findsOneWidget,
    );
    expect(service.evaluateCalls, 0);
  });

  testWidgets('successful submission replaces QuizScreen in the route stack', (
    tester,
  ) async {
    final service = _FakeQuizService(loader: (_) async => [_questions().first]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => QuizScreen(
                    lesson: _lesson(),
                    quizService: service,
                    authService: _FakeAuthService('student-uid'),
                    resultScreenBuilder:
                        ({
                          required questions,
                          required selectedAnswerIndexes,
                          required evaluation,
                        }) => Scaffold(
                          body: TextButton(
                            key: const Key('close-test-result'),
                            onPressed: () => Navigator.maybePop(context),
                            child: const Text('إغلاق النتيجة'),
                          ),
                        ),
                  ),
                ),
              ),
              child: const Text('افتح الاختبار'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('افتح الاختبار'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quiz-option-question-1-1')));
    await tester.tap(find.byKey(const Key('quiz-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsNothing);
    await tester.tap(find.byKey(const Key('close-test-result')));
    await tester.pumpAndSettle();

    expect(find.text('افتح الاختبار'), findsOneWidget);
    expect(find.byType(QuizScreen), findsNothing);
  });
}

Future<void> _pumpQuiz(
  WidgetTester tester, {
  required QuizService quizService,
  AuthService? authService,
  QuizResultScreenBuilder? resultScreenBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: QuizScreen(
        lesson: _lesson(),
        quizService: quizService,
        authService: authService ?? _FakeAuthService('student-uid'),
        resultScreenBuilder: resultScreenBuilder,
      ),
    ),
  );
}

Lesson _lesson() => Lesson(
  lessonId: 'lesson-1',
  title: 'الدرس الأول',
  chapterId: 'chapter-1',
  explanation: 'شرح الدرس',
  order: 1,
  isActive: true,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 2),
);

List<Question> _questions() => const [
  Question(
    questionId: 'question-1',
    lessonId: 'lesson-1',
    questionText: 'السؤال الأول',
    options: ['خاطئة', 'صحيحة'],
    correctAnswerIndex: 1,
    explanation: 'تفسير السؤال الأول',
    order: 1,
    isActive: true,
  ),
  Question(
    questionId: 'question-2',
    lessonId: 'lesson-1',
    questionText: 'السؤال الثاني',
    options: ['صحيحة', 'خاطئة'],
    correctAnswerIndex: 0,
    explanation: 'تفسير السؤال الثاني',
    order: 2,
    isActive: true,
  ),
  Question(
    questionId: 'question-3',
    lessonId: 'lesson-1',
    questionText: 'السؤال الثالث',
    options: ['خاطئة', 'صحيحة'],
    correctAnswerIndex: 1,
    explanation: 'تفسير السؤال الثالث',
    order: 3,
    isActive: true,
  ),
];

QuizEvaluationResult _evaluation() => QuizEvaluationResult(
  attempt: QuizAttempt(
    attemptId: 'attempt-1',
    userId: 'student-uid',
    lessonId: 'lesson-1',
    score: 1,
    totalQuestions: 1,
    percentage: 100,
    completedAt: DateTime.utc(2026, 1, 3),
  ),
  answerCorrectness: const {'question-1': true},
);

typedef _EvaluationArguments = ({
  String userId,
  String lessonId,
  List<Question> questions,
  Map<String, int> selectedAnswerIndexes,
});

class _FakeQuizService extends QuizService {
  _FakeQuizService({required this.loader, this.evaluator});

  final Future<List<Question>> Function(String lessonId) loader;
  final Future<QuizEvaluationResult> Function(_EvaluationArguments arguments)?
  evaluator;
  var loadCalls = 0;
  var evaluateCalls = 0;
  String? lastUserId;
  String? lastLessonId;
  Map<String, int>? lastAnswers;

  @override
  Future<List<Question>> loadActiveQuestionsForLesson(String lessonId) {
    loadCalls++;
    return loader(lessonId);
  }

  @override
  Future<QuizEvaluationResult> evaluateAndSaveAttempt({
    required String userId,
    required String lessonId,
    required List<Question> questions,
    required Map<String, int> selectedAnswerIndexes,
  }) {
    evaluateCalls++;
    lastUserId = userId;
    lastLessonId = lessonId;
    lastAnswers = Map.of(selectedAnswerIndexes);
    final arguments = (
      userId: userId,
      lessonId: lessonId,
      questions: questions,
      selectedAnswerIndexes: selectedAnswerIndexes,
    );
    return evaluator?.call(arguments) ?? Future.value(_evaluation());
  }
}

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.uid);

  final String? uid;

  @override
  String? get currentUserUid => uid;
}
