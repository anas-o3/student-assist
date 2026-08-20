import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/subject.dart';
import 'package:student_assist/screens/student/student_home_screen.dart';
import 'package:student_assist/services/subject_service.dart';

void main() {
  const subjects = [
    Subject(
      subjectId: 'subject-arabic',
      name: 'اللغة العربية',
      gradeId: 'grade-1',
      imageUrl: '',
      order: 1,
      isActive: true,
    ),
    Subject(
      subjectId: 'subject-math',
      name: 'الرياضيات',
      gradeId: 'grade-1',
      imageUrl: '',
      order: 2,
      isActive: true,
    ),
  ];

  testWidgets('shows loading while active subjects are requested', (
    tester,
  ) async {
    final completer = Completer<List<Subject>>();
    await _pumpScreen(
      tester,
      subjectService: _FakeSubjectService((_) => completer.future),
    );

    expect(find.byKey(const ValueKey('subjects-loading')), findsOneWidget);
    expect(find.text('جارٍ تحميل المواد الدراسية...'), findsOneWidget);

    completer.complete(subjects);
    await tester.pumpAndSettle();
  });

  testWidgets('displays subjects in service order with image fallback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpScreen(
      tester,
      subjectService: _FakeSubjectService((_) async => subjects),
    );
    await tester.pumpAndSettle();

    expect(find.text('اللغة العربية'), findsOneWidget);
    expect(find.text('الرياضيات'), findsOneWidget);
    expect(
      find.byKey(const Key('subject-image-placeholder-subject-arabic')),
      findsOneWidget,
    );

    final firstTop = tester
        .getTopLeft(find.byKey(const Key('subject-card-subject-arabic')))
        .dy;
    final secondTop = tester
        .getTopLeft(find.byKey(const Key('subject-card-subject-math')))
        .dy;
    expect(firstTop, lessThan(secondTop));
  });

  testWidgets('shows an empty state when no active subjects exist', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      subjectService: _FakeSubjectService((_) async => const []),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('subjects-empty')), findsOneWidget);
    expect(
      find.text('لا توجد مواد دراسية متاحة لهذا الصف حالياً.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a safe load error and retries successfully', (
    tester,
  ) async {
    var attempts = 0;
    final service = _FakeSubjectService((_) async {
      attempts++;
      if (attempts == 1) {
        throw const SubjectFailure(
          'تعذر تحميل المواد الدراسية. حاول مرة أخرى.',
          SubjectFailureReason.backend,
        );
      }
      return subjects;
    });
    await _pumpScreen(tester, subjectService: service);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('subjects-load-error')), findsOneWidget);
    expect(find.textContaining('private Firebase detail'), findsNothing);

    await tester.tap(find.byKey(const Key('retry-subjects-button')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('اللغة العربية'), findsOneWidget);
  });

  testWidgets('subject tap opens ChapterScreen with the selected subjectId', (
    tester,
  ) async {
    String? openedSubjectId;
    await _pumpScreen(
      tester,
      subjectService: _FakeSubjectService((_) async => subjects),
      chapterScreenBuilder: (subjectId) {
        openedSubjectId = subjectId;
        return Scaffold(body: Text('chapters-for-$subjectId'));
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('subject-card-subject-arabic')));
    await tester.pumpAndSettle();

    expect(openedSubjectId, 'subject-arabic');
    expect(find.text('chapters-for-subject-arabic'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required SubjectService subjectService,
  ChapterScreenBuilder? chapterScreenBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: StudentHomeScreen(
        gradeId: 'grade-1',
        subjectService: subjectService,
        chapterScreenBuilder: chapterScreenBuilder,
      ),
    ),
  );
}

class _FakeSubjectService extends SubjectService {
  _FakeSubjectService(this.loader);

  final Future<List<Subject>> Function(String gradeId) loader;

  @override
  Future<List<Subject>> loadActiveSubjectsForGrade(String gradeId) {
    return loader(gradeId);
  }
}
