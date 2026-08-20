import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/lesson.dart';
import 'package:student_assist/screens/student/lesson_content_screen.dart';
import 'package:student_assist/screens/student/lesson_list_screen.dart';
import 'package:student_assist/services/lesson_service.dart';

void main() {
  final lessons = [
    _lesson(lessonId: 'lesson-functions', title: 'الدوال', order: 2),
    _lesson(lessonId: 'lesson-equations', title: 'المعادلات', order: 1),
  ];

  testWidgets('shows loading while active lessons are requested', (
    tester,
  ) async {
    final completer = Completer<List<Lesson>>();
    await _pumpScreen(
      tester,
      lessonService: _FakeLessonService((_) => completer.future),
    );

    expect(find.byKey(const ValueKey('lessons-loading')), findsOneWidget);
    expect(find.text('جارٍ تحميل الدروس...'), findsOneWidget);

    completer.complete(lessons);
    await tester.pumpAndSettle();
  });

  testWidgets('displays lesson titles ordered by order', (tester) async {
    await _pumpScreen(
      tester,
      lessonService: _FakeLessonService((_) async => lessons),
    );
    await tester.pumpAndSettle();

    expect(find.text('المعادلات'), findsOneWidget);
    expect(find.text('الدوال'), findsOneWidget);
    final equationsTop = tester
        .getTopLeft(find.byKey(const Key('lesson-card-lesson-equations')))
        .dy;
    final functionsTop = tester
        .getTopLeft(find.byKey(const Key('lesson-card-lesson-functions')))
        .dy;
    expect(equationsTop, lessThan(functionsTop));
  });

  testWidgets('shows an empty state when no active lessons exist', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      lessonService: _FakeLessonService((_) async => const []),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lessons-empty')), findsOneWidget);
    expect(find.text('لا توجد دروس متاحة لهذا الباب حالياً.'), findsOneWidget);
  });

  testWidgets('shows a safe load error and retries successfully', (
    tester,
  ) async {
    var attempts = 0;
    final service = _FakeLessonService((_) async {
      attempts++;
      if (attempts == 1) {
        throw const LessonFailure(
          'تعذر تحميل الدروس. حاول مرة أخرى.',
          LessonFailureReason.backend,
        );
      }
      return lessons;
    });
    await _pumpScreen(tester, lessonService: service);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lessons-load-error')), findsOneWidget);
    expect(find.textContaining('private Firebase detail'), findsNothing);

    await tester.tap(find.byKey(const Key('retry-lessons-button')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('المعادلات'), findsOneWidget);
  });

  testWidgets('lesson tap opens content with the exact selected lesson', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      lessonService: _FakeLessonService((_) async => lessons),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lesson-card-lesson-equations')));
    await tester.pumpAndSettle();

    expect(find.byType(LessonContentScreen), findsOneWidget);
    expect(find.text('المعادلات'), findsOneWidget);
    expect(find.text('شرح الدرس'), findsOneWidget);

    final contentScreen = tester.widget<LessonContentScreen>(
      find.byType(LessonContentScreen),
    );
    expect(contentScreen.lesson.lessonId, 'lesson-equations');

    await tester.tap(find.byKey(const Key('lesson-content-back-button')));
    await tester.pumpAndSettle();

    expect(find.byType(LessonListScreen), findsOneWidget);
    expect(find.byType(LessonContentScreen), findsNothing);
    expect(find.text('المعادلات'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required LessonService lessonService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: LessonListScreen(
        chapterId: 'chapter-algebra',
        lessonService: lessonService,
      ),
    ),
  );
}

Lesson _lesson({
  required String lessonId,
  required String title,
  required int order,
}) {
  return Lesson(
    lessonId: lessonId,
    title: title,
    chapterId: 'chapter-algebra',
    explanation: 'شرح الدرس',
    order: order,
    isActive: true,
    createdAt: DateTime.utc(2026, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 11),
  );
}

class _FakeLessonService extends LessonService {
  _FakeLessonService(this.loader);

  final Future<List<Lesson>> Function(String chapterId) loader;

  @override
  Future<List<Lesson>> loadActiveLessonsForChapter(String chapterId) {
    return loader(chapterId);
  }
}
