import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/question.dart';
import 'package:student_assist/models/quiz_attempt.dart';
import 'package:student_assist/screens/student/quiz_result_screen.dart';
import 'package:student_assist/services/quiz_service.dart';

void main() {
  testWidgets('shows score, percentage, and answer feedback', (tester) async {
    await _pumpResult(tester);

    expect(find.text('1 من 2'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('إجابة صحيحة'), findsOneWidget);
    expect(find.text('إجابة غير صحيحة'), findsOneWidget);
    expect(find.text('إجابتك: صحيح'), findsOneWidget);
    expect(find.text('إجابتك: اختيار خاطئ'), findsOneWidget);
    expect(find.text('الإجابة الصحيحة: اختيار صحيح'), findsOneWidget);
    expect(find.text('التفسير: التفسير الأول'), findsOneWidget);
    expect(find.text('التفسير: التفسير الثاني'), findsOneWidget);
  });

  testWidgets('uses Arabic RTL and supports long scrolling content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpResult(tester);

    final directionality = tester.widget<Directionality>(
      find.byKey(const Key('quiz-result-directionality')),
    );
    expect(directionality.textDirection, TextDirection.rtl);

    final summary = find.byKey(const Key('quiz-result-summary'));
    final before = tester.getTopLeft(summary).dy;
    await tester.drag(
      find.byKey(const Key('quiz-result-scroll-view')),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(summary).dy, lessThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('back returns to the screen below the result', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => _resultScreen())),
              child: const Text('افتح النتيجة'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('افتح النتيجة'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quiz-result-back-button')));
    await tester.pumpAndSettle();

    expect(find.byType(QuizResultScreen), findsNothing);
    expect(find.text('افتح النتيجة'), findsOneWidget);
  });
}

Future<void> _pumpResult(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.lightTheme, home: _resultScreen()),
  );
  await tester.pumpAndSettle();
}

QuizResultScreen _resultScreen() => QuizResultScreen(
  questions: _questions,
  selectedAnswerIndexes: const {'question-1': 1, 'question-2': 0},
  evaluation: QuizEvaluationResult(
    attempt: QuizAttempt(
      attemptId: 'attempt-1',
      userId: 'student-1',
      lessonId: 'lesson-1',
      score: 1,
      totalQuestions: 2,
      percentage: 50,
      completedAt: DateTime.utc(2026, 1, 1),
    ),
    answerCorrectness: const {'question-1': true, 'question-2': false},
  ),
);

const _questions = [
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
    options: ['اختيار خاطئ', 'اختيار صحيح'],
    correctAnswerIndex: 1,
    explanation: 'التفسير الثاني',
    order: 2,
    isActive: true,
  ),
];
