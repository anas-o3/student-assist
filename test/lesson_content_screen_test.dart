import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/lesson.dart';
import 'package:student_assist/screens/student/lesson_content_screen.dart';

void main() {
  testWidgets('displays the selected lesson title and explanation', (
    tester,
  ) async {
    final lesson = _lesson(
      title: 'المعادلات',
      explanation: 'شرح نصي معتمد للمعادلات.',
    );

    await _pumpScreen(tester, lesson);

    expect(find.text('المعادلات'), findsOneWidget);
    expect(find.text('شرح نصي معتمد للمعادلات.'), findsOneWidget);
  });

  testWidgets('uses RTL direction and contains no deferred resource controls', (
    tester,
  ) async {
    await _pumpScreen(tester, _lesson());

    final directionality = tester.widget<Directionality>(
      find.byKey(const Key('lesson-content-directionality')),
    );
    expect(directionality.textDirection, TextDirection.rtl);
    expect(find.text('فيديو'), findsNothing);
    expect(find.text('PDF'), findsNothing);
    expect(find.text('الموارد'), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsNothing);
  });

  testWidgets('long explanation scrolls safely', (tester) async {
    final longExplanation = List.filled(
      45,
      'هذا سطر شرح طويل لاختبار التمرير.',
    ).join('\n\n');
    await _pumpScreen(tester, _lesson(explanation: longExplanation));

    final explanation = find.byKey(const Key('lesson-explanation'));
    final topBeforeScroll = tester.getTopLeft(explanation).dy;

    await tester.drag(
      find.byKey(const Key('lesson-content-scroll-view')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(explanation).dy, lessThan(topBeforeScroll));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(WidgetTester tester, Lesson lesson) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: LessonContentScreen(lesson: lesson),
    ),
  );
}

Lesson _lesson({
  String title = 'الدرس الأول',
  String explanation = 'شرح الدرس',
}) {
  return Lesson(
    lessonId: 'lesson-1',
    title: title,
    chapterId: 'chapter-1',
    explanation: explanation,
    order: 1,
    isActive: true,
    createdAt: DateTime.utc(2026, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 11),
  );
}
