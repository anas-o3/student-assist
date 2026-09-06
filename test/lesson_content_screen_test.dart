import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/lesson.dart';
import 'package:student_assist/models/resource.dart';
import 'package:student_assist/screens/student/lesson_content_screen.dart';
import 'package:student_assist/screens/student/pdf_viewer_screen.dart';
import 'package:student_assist/screens/student/video_player_screen.dart';
import 'package:student_assist/services/pdf_download_service.dart';
import 'package:student_assist/services/resource_service.dart';
import 'package:student_assist/services/video_download_service.dart';

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
    expect(find.byKey(const Key('download-pdf-pdf-1')), findsOneWidget);
    expect(find.byKey(const Key('download-video-video-1')), findsOneWidget);
  });

  testWidgets('video and PDF expose only their matching download actions', (
    tester,
  ) async {
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
          _resource(resourceId: 'pdf-1', title: 'ملخص', type: 'pdf', order: 2),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('download-pdf-video-1')), findsNothing);
    expect(find.byKey(const Key('download-video-video-1')), findsOneWidget);
    expect(find.byKey(const Key('download-video-pdf-1')), findsNothing);
    expect(find.byKey(const Key('download-pdf-pdf-1')), findsOneWidget);
  });

  testWidgets('downloads a video separately and shows success', (tester) async {
    final video = _resource(
      resourceId: 'video-1',
      title: 'شرح مرئي',
      type: 'video',
      order: 1,
    );
    final folder = Directory.systemTemp.createTempSync(
      'student_assist_video_ui_test_',
    );
    final file = File('${folder.path}/video.mp4')..writeAsBytesSync(const [1]);
    var calls = 0;
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService((_) async => [video]),
      videoDownloadService: _FakeVideoDownloadService((_) async {
        calls++;
        return VideoDownloadResult(file: file, wasAlreadyDownloaded: false);
      }),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('download-video-video-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(calls, 1);
    expect(find.text('تم تنزيل الفيديو بنجاح.'), findsOneWidget);
    expect(find.byType(VideoPlayerScreen), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    folder.deleteSync(recursive: true);
  });

  testWidgets('reports when a persistent video is already available', (
    tester,
  ) async {
    final folder = Directory.systemTemp.createTempSync(
      'student_assist_existing_video_ui_test_',
    );
    final file = File('${folder.path}/video.mp4')..writeAsBytesSync(const [1]);
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
        ],
      ),
      videoDownloadService: _FakeVideoDownloadService(
        (_) async =>
            VideoDownloadResult(file: file, wasAlreadyDownloaded: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('download-video-video-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('الفيديو محفوظ مسبقًا على الجهاز.'), findsOneWidget);
    expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    folder.deleteSync(recursive: true);
  });

  testWidgets('prevents repeated video submission while downloading', (
    tester,
  ) async {
    final completer = Completer<VideoDownloadResult>();
    var calls = 0;
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
        ],
      ),
      videoDownloadService: _FakeVideoDownloadService((_) {
        calls++;
        return completer.future;
      }),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('download-video-video-1'));
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();

    expect(calls, 1);
    expect(find.byKey(const Key('video-download-progress')), findsOneWidget);

    final folder = Directory.systemTemp.createTempSync(
      'student_assist_video_pending_ui_test_',
    );
    final file = File('${folder.path}/video.mp4')..writeAsBytesSync(const [1]);
    completer.complete(
      VideoDownloadResult(file: file, wasAlreadyDownloaded: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 5));
    folder.deleteSync(recursive: true);
  });

  testWidgets('video completion after disposal does not update old screen', (
    tester,
  ) async {
    final completer = Completer<VideoDownloadResult>();
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
        ],
      ),
      videoDownloadService: _FakeVideoDownloadService((_) => completer.future),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('download-video-video-1')));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final folder = Directory.systemTemp.createTempSync(
      'student_assist_video_disposed_ui_test_',
    );
    final file = File('${folder.path}/video.mp4')..writeAsBytesSync(const [1]);
    completer.complete(
      VideoDownloadResult(file: file, wasAlreadyDownloaded: false),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    folder.deleteSync(recursive: true);
  });

  testWidgets('shows a safe video download error and allows retry', (
    tester,
  ) async {
    var attempts = 0;
    final folder = Directory.systemTemp.createTempSync(
      'student_assist_video_retry_ui_test_',
    );
    final file = File('${folder.path}/video.mp4')..writeAsBytesSync(const [1]);
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
        ],
      ),
      videoDownloadService: _FakeVideoDownloadService((_) async {
        attempts++;
        if (attempts == 1) {
          throw const VideoDownloadFailure(
            'تعذر تنزيل ملف الفيديو. حاول مرة أخرى.',
            VideoDownloadFailureReason.backend,
          );
        }
        return VideoDownloadResult(file: file, wasAlreadyDownloaded: false);
      }),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('download-video-video-1'));
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تعذر تنزيل ملف الفيديو. حاول مرة أخرى.'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(attempts, 2);
    expect(find.text('تم تنزيل الفيديو بنجاح.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    folder.deleteSync(recursive: true);
  });

  testWidgets('video card opens VideoPlayerScreen with the selected Resource', (
    tester,
  ) async {
    final video = _resource(
      resourceId: 'video-1',
      title: 'شرح مرئي',
      type: 'video',
      order: 1,
    );
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService((_) async => [video]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('resource-card-video-1')));
    await tester.pumpAndSettle();

    final screen = tester.widget<VideoPlayerScreen>(
      find.byType(VideoPlayerScreen),
    );
    expect(screen.resource, same(video));
    expect(find.text('ملف الفيديو غير متوفر.'), findsOneWidget);
  });

  testWidgets('PDF card opens PdfViewerScreen with the selected Resource', (
    tester,
  ) async {
    final pdf = _resource(
      resourceId: 'pdf-1',
      title: 'ملخص الدرس',
      type: 'pdf',
      order: 1,
    );
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService((_) async => [pdf]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('resource-card-pdf-1')));
    await tester.pumpAndSettle();

    final screen = tester.widget<PdfViewerScreen>(find.byType(PdfViewerScreen));
    expect(screen.resource, same(pdf));
    expect(find.text('ملف PDF غير متوفر.'), findsOneWidget);
  });

  testWidgets('downloads a PDF separately and shows success', (tester) async {
    final pdf = _resource(
      resourceId: 'pdf-1',
      title: 'ملخص الدرس',
      type: 'pdf',
      order: 1,
    );
    final folder = Directory.systemTemp.createTempSync(
      'student_assist_pdf_ui_test_',
    );
    final file = File('${folder.path}/document.pdf')
      ..writeAsBytesSync('%PDF-'.codeUnits);
    var calls = 0;
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService((_) async => [pdf]),
      pdfDownloadService: _FakePdfDownloadService((_) async {
        calls++;
        return PdfDownloadResult(file: file, wasAlreadyDownloaded: false);
      }),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('download-pdf-pdf-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(calls, 1);
    expect(find.text('تم تنزيل الملف بنجاح.'), findsOneWidget);
    expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);
    expect(find.byType(PdfViewerScreen), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    folder.deleteSync(recursive: true);
  });

  testWidgets('prevents repeated PDF submission while downloading', (
    tester,
  ) async {
    final completer = Completer<PdfDownloadResult>();
    var calls = 0;
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService(
        (_) async => [
          _resource(
            resourceId: 'pdf-1',
            title: 'ملخص الدرس',
            type: 'pdf',
            order: 1,
          ),
        ],
      ),
      pdfDownloadService: _FakePdfDownloadService((_) {
        calls++;
        return completer.future;
      }),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('download-pdf-pdf-1'));
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();

    expect(calls, 1);
    expect(find.byKey(const Key('pdf-download-progress')), findsOneWidget);

    final folder = Directory.systemTemp.createTempSync(
      'student_assist_pdf_pending_test_',
    );
    final file = File('${folder.path}/document.pdf')
      ..writeAsBytesSync('%PDF-'.codeUnits);
    completer.complete(
      PdfDownloadResult(file: file, wasAlreadyDownloaded: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 5));
    folder.deleteSync(recursive: true);
  });

  testWidgets('completion after disposal does not update the old screen', (
    tester,
  ) async {
    final completer = Completer<PdfDownloadResult>();
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService(
        (_) async => [
          _resource(
            resourceId: 'pdf-1',
            title: 'ملخص الدرس',
            type: 'pdf',
            order: 1,
          ),
        ],
      ),
      pdfDownloadService: _FakePdfDownloadService((_) => completer.future),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('download-pdf-pdf-1')));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final folder = Directory.systemTemp.createTempSync(
      'student_assist_pdf_disposed_test_',
    );
    final file = File('${folder.path}/document.pdf')
      ..writeAsBytesSync('%PDF-'.codeUnits);
    completer.complete(
      PdfDownloadResult(file: file, wasAlreadyDownloaded: false),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    folder.deleteSync(recursive: true);
  });

  testWidgets('shows a safe PDF download error and allows retry', (
    tester,
  ) async {
    var attempts = 0;
    final folder = Directory.systemTemp.createTempSync(
      'student_assist_pdf_retry_test_',
    );
    final file = File('${folder.path}/document.pdf')
      ..writeAsBytesSync('%PDF-'.codeUnits);
    await _pumpScreen(
      tester,
      resourceService: _FakeResourceService(
        (_) async => [
          _resource(
            resourceId: 'pdf-1',
            title: 'ملخص الدرس',
            type: 'pdf',
            order: 1,
          ),
        ],
      ),
      pdfDownloadService: _FakePdfDownloadService((_) async {
        attempts++;
        if (attempts == 1) {
          throw const PdfDownloadFailure(
            'تعذر تنزيل ملف PDF. حاول مرة أخرى.',
            PdfDownloadFailureReason.backend,
          );
        }
        return PdfDownloadResult(file: file, wasAlreadyDownloaded: false);
      }),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('download-pdf-pdf-1'));
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('تعذر تنزيل ملف PDF. حاول مرة أخرى.'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(attempts, 2);
    expect(find.text('تم تنزيل الملف بنجاح.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    folder.deleteSync(recursive: true);
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

  testWidgets('opens the quiz for the exact selected Lesson', (tester) async {
    Lesson? capturedLesson;
    final lesson = _lesson(title: 'درس الاختبار');
    await _pumpScreen(
      tester,
      lesson: lesson,
      resourceService: _FakeResourceService((_) async => const []),
      quizScreenBuilder: (selectedLesson) {
        capturedLesson = selectedLesson;
        return const Scaffold(body: Text('شاشة الاختبار'));
      },
    );
    await tester.pumpAndSettle();

    final quizButton = find.byKey(const Key('open-lesson-quiz-button'));
    await tester.ensureVisible(quizButton);
    await tester.tap(quizButton);
    await tester.pumpAndSettle();

    expect(capturedLesson, same(lesson));
    expect(find.text('شاشة الاختبار'), findsOneWidget);
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
  PdfDownloadService? pdfDownloadService,
  VideoDownloadService? videoDownloadService,
  QuizScreenBuilder? quizScreenBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: LessonContentScreen(
        lesson: lesson ?? _lesson(),
        resourceService: resourceService,
        pdfDownloadService:
            pdfDownloadService ??
            _FakePdfDownloadService(
              (_) async => throw const PdfDownloadFailure(
                'تعذر تنزيل ملف PDF. حاول مرة أخرى.',
                PdfDownloadFailureReason.backend,
              ),
            ),
        videoDownloadService:
            videoDownloadService ??
            _FakeVideoDownloadService(
              (_) async => throw const VideoDownloadFailure(
                'تعذر تنزيل ملف الفيديو. حاول مرة أخرى.',
                VideoDownloadFailureReason.backend,
              ),
            ),
        quizScreenBuilder: quizScreenBuilder,
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

class _FakePdfDownloadService extends PdfDownloadService {
  _FakePdfDownloadService(this.downloader);

  final Future<PdfDownloadResult> Function(Resource resource) downloader;

  @override
  Future<PdfDownloadResult> downloadPdf(Resource resource) =>
      downloader(resource);

  @override
  Future<File?> findDownloadedPdf(Resource resource) async => null;
}

class _FakeVideoDownloadService extends VideoDownloadService {
  _FakeVideoDownloadService(this.downloader);

  final Future<VideoDownloadResult> Function(Resource resource) downloader;

  @override
  Future<VideoDownloadResult> downloadVideo(Resource resource) =>
      downloader(resource);

  @override
  Future<File?> findDownloadedVideo(Resource resource) async => null;
}
