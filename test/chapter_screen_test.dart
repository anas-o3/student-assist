import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/chapter.dart';
import 'package:student_assist/screens/student/chapter_screen.dart';
import 'package:student_assist/services/chapter_service.dart';

void main() {
  const chapters = [
    Chapter(
      chapterId: 'chapter-geometry',
      title: 'الهندسة',
      subjectId: 'subject-math',
      order: 2,
      isActive: true,
    ),
    Chapter(
      chapterId: 'chapter-algebra',
      title: 'الجبر',
      subjectId: 'subject-math',
      order: 1,
      isActive: true,
    ),
  ];

  testWidgets('shows loading while active chapters are requested', (
    tester,
  ) async {
    final completer = Completer<List<Chapter>>();
    await _pumpScreen(
      tester,
      chapterService: _FakeChapterService((_) => completer.future),
    );

    expect(find.byKey(const ValueKey('chapters-loading')), findsOneWidget);
    expect(find.text('جارٍ تحميل الأبواب الدراسية...'), findsOneWidget);

    completer.complete(chapters);
    await tester.pumpAndSettle();
  });

  testWidgets('displays chapter titles ordered by order', (tester) async {
    await _pumpScreen(
      tester,
      chapterService: _FakeChapterService((_) async => chapters),
    );
    await tester.pumpAndSettle();

    expect(find.text('الجبر'), findsOneWidget);
    expect(find.text('الهندسة'), findsOneWidget);
    final algebraTop = tester
        .getTopLeft(find.byKey(const Key('chapter-card-chapter-algebra')))
        .dy;
    final geometryTop = tester
        .getTopLeft(find.byKey(const Key('chapter-card-chapter-geometry')))
        .dy;
    expect(algebraTop, lessThan(geometryTop));
  });

  testWidgets('shows an empty state when no active chapters exist', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      chapterService: _FakeChapterService((_) async => const []),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chapters-empty')), findsOneWidget);
    expect(
      find.text('لا توجد أبواب دراسية متاحة لهذه المادة حالياً.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a safe load error and retries successfully', (
    tester,
  ) async {
    var attempts = 0;
    final service = _FakeChapterService((_) async {
      attempts++;
      if (attempts == 1) {
        throw const ChapterFailure(
          'تعذر تحميل الأبواب الدراسية. حاول مرة أخرى.',
          ChapterFailureReason.backend,
        );
      }
      return chapters;
    });
    await _pumpScreen(tester, chapterService: service);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chapters-load-error')), findsOneWidget);
    expect(find.textContaining('private Firebase detail'), findsNothing);

    await tester.tap(find.byKey(const Key('retry-chapters-button')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('الجبر'), findsOneWidget);
  });

  testWidgets('chapter tap shows the temporary lesson message', (tester) async {
    await _pumpScreen(
      tester,
      chapterService: _FakeChapterService((_) async => chapters),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chapter-card-chapter-algebra')));
    await tester.pump();

    expect(find.text('سيتم إضافة الدروس في المرحلة التالية.'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ChapterService chapterService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: ChapterScreen(
        subjectId: 'subject-math',
        chapterService: chapterService,
      ),
    ),
  );
}

class _FakeChapterService extends ChapterService {
  _FakeChapterService(this.loader);

  final Future<List<Chapter>> Function(String subjectId) loader;

  @override
  Future<List<Chapter>> loadActiveChaptersForSubject(String subjectId) {
    return loader(subjectId);
  }
}
