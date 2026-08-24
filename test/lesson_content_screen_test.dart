import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/lesson.dart';
import 'package:student_assist/models/resource.dart';
import 'package:student_assist/screens/student/lesson_content_screen.dart';
import 'package:student_assist/services/resource_service.dart';

void main() {
  testWidgets('keeps the selected lesson title and explanation visible', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      lesson: _lesson(
        title: 'المعادلات',
        explanation: 'شرح نصي معتمد للمعادلات.',
      ),
      resourceService: _FakeResourceService((_) async => const []),
    );
    await tester.pumpAndSettle();

    expect(find.text('المعادلات'), findsOneWidget);
    expect(find.text('شرح نصي معتمد للمعادلات.'), findsOneWidget);
    expect(find.text('موارد الدرس'), findsOneWidget);
  });

  testWidgets('shows loading while active resources are requested', (
    tester,
  ) async {
    final completer = Completer<List<Resource>>();
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService((_) => completer.future),
    );

    expect(
      find.byKey(const ValueKey('lesson-resources-loading')),
      findsOneWidget,
    );
    expect(find.text('جارٍ تحميل موارد الدرس...'), findsOneWidget);

    completer.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('displays supported video and PDF resources', (tester) async {
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService(
        (_) async => [
          _resource(
            resourceId: 'video-1',
            title: 'شرح مرئي',
            type: 'video',
            order: 1,
          ),
          _resource(
            resourceId: 'pdf-1',
            title: 'ملخص الدرس',
            type: 'pdf',
            order: 2,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('شرح مرئي'), findsOneWidget);
    expect(find.text('فيديو'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    expect(find.text('ملخص الدرس'), findsOneWidget);
    expect(find.text('ملخص PDF'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets('displays supported resources by global order', (tester) async {
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService(
        (_) async => [
          _resource(
            resourceId: 'pdf-2',
            title: 'الثاني',
            type: 'pdf',
            order: 2,
          ),
          _resource(
            resourceId: 'video-1',
            title: 'الأول',
            type: 'video',
            order: 1,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final firstTop = tester
        .getTopLeft(find.byKey(const Key('resource-card-video-1')))
        .dy;
    final secondTop = tester
        .getTopLeft(find.byKey(const Key('resource-card-pdf-2')))
        .dy;
    expect(firstTop, lessThan(secondTop));
  });

  testWidgets('ignores unsupported types without hiding supported resources', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService(
        (_) async => [
          _resource(
            resourceId: 'sample-a',
            title: 'مورد تجريبي',
            type: 'sample-a',
            order: 1,
          ),
          _resource(
            resourceId: 'video-2',
            title: 'فيديو معتمد',
            type: 'video',
            order: 2,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مورد تجريبي'), findsNothing);
    expect(find.text('فيديو معتمد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported-only resources show the supported empty state', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService(
        (_) async => [
          _resource(
            resourceId: 'sample-a',
            title: 'مورد تجريبي أول',
            type: 'sample-a',
            order: 1,
          ),
          _resource(
            resourceId: 'sample-b',
            title: 'مورد تجريبي ثان',
            type: 'sample-b',
            order: 2,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مورد تجريبي أول'), findsNothing);
    expect(find.text('لا توجد موارد متاحة لهذا الدرس حاليًا.'), findsOneWidget);
  });

  testWidgets('no resources shows a normal empty state', (tester) async {
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService((_) async => const []),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('lesson-resources-empty')),
      findsOneWidget,
    );
    expect(find.text('لا توجد موارد متاحة لهذا الدرس حاليًا.'), findsOneWidget);
  });

  testWidgets('shows a safe resource error and retries successfully', (
    tester,
  ) async {
    var attempts = 0;
    final service = _FakeResourceService((_) async {
      attempts++;
      if (attempts == 1) {
        throw const ResourceFailure(
          'تعذر تحميل موارد الدرس. حاول مرة أخرى.',
          ResourceFailureReason.backend,
        );
      }
      return [
        _resource(
          resourceId: 'video-1',
          title: 'شرح مرئي',
          type: 'video',
          order: 1,
        ),
      ];
    });
    await _pumpScreen(tester, resourceService: service);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('lesson-resources-error')),
      findsOneWidget,
    );
    expect(find.textContaining('private Firebase detail'), findsNothing);

    await tester.tap(find.byKey(const Key('retry-lesson-resources-button')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('شرح مرئي'), findsOneWidget);
  });

  testWidgets('long lesson content and resources scroll safely', (
    tester,
  ) async {
    final longExplanation = List.filled(
      45,
      'هذا سطر شرح طويل لاختبار التمرير.',
    ).join('\n\n');
    await _pumpScreen(
      tester,
      lesson: _lesson(explanation: longExplanation),
      resourceService: _FakeResourceService((_) async => const []),
    );
    await tester.pumpAndSettle();

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

  testWidgets('keeps Arabic RTL direction', (tester) async {
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService((_) async => const []),
    );
    await tester.pumpAndSettle();

    final directionality = tester.widget<Directionality>(
      find.byKey(const Key('lesson-content-directionality')),
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('back returns from lesson content to the previous screen', (
    tester,
  ) async {
    final resourceService = _FakeResourceService((_) async => const []);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LessonContentScreen(
                    lesson: _lesson(),
                    resourceService: resourceService,
                  ),
                ),
              ),
              child: const Text('افتح الدرس'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('افتح الدرس'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonContentScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('lesson-content-back-button')));
    await tester.pumpAndSettle();

    expect(find.byType(LessonContentScreen), findsNothing);
    expect(find.text('افتح الدرس'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  Lesson? lesson,
  required ResourceService resourceService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: LessonContentScreen(
        lesson: lesson ?? _lesson(),
        resourceService: resourceService,
      ),
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

Resource _resource({
  required String resourceId,
  required String title,
  required String type,
  required int order,
}) {
  return Resource(
    resourceId: resourceId,
    lessonId: 'lesson-1',
    title: title,
    type: type,
    url: '',
    storagePath: '',
    order: order,
    isActive: true,
    createdAt: DateTime.utc(2026, 2, 10),
  );
}

class _FakeResourceService extends ResourceService {
  _FakeResourceService(this.loader);

  final Future<List<Resource>> Function(String lessonId) loader;

  @override
  Future<List<Resource>> loadActiveResourcesForLesson(String lessonId) {
    return loader(lessonId);
  }
}
