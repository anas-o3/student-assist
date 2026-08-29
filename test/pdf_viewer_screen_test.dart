import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/resource.dart';
import 'package:student_assist/screens/student/pdf_viewer_screen.dart';
import 'package:student_assist/services/pdf_download_service.dart';
import 'package:student_assist/services/pdf_service.dart';

void main() {
  testWidgets('shows loading while the authenticated PDF is prepared', (
    tester,
  ) async {
    final completer = Completer<PdfViewSource>();
    await _pumpScreen(
      tester,
      pdfService: _FakePdfService((_) => completer.future),
      viewerBuilder: _successfulViewer,
    );

    expect(find.byKey(const ValueKey('pdf-loading')), findsOneWidget);
    expect(find.text('جارٍ تجهيز ملف PDF...'), findsOneWidget);

    final source = _source();
    completer.complete(source);
    await _pumpFrames(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await _pumpFrames(tester);
  });

  testWidgets('shows the title and prepared local PDF viewer', (tester) async {
    final source = _source();
    await _pumpScreen(
      tester,
      pdfService: _FakePdfService((_) async => source),
      viewerBuilder: _successfulViewer,
    );
    await _pumpFrames(tester);

    expect(find.text('ملخص الدرس'), findsOneWidget);
    expect(find.byKey(const ValueKey('pdf-ready')), findsOneWidget);
    expect(find.text('صفحات PDF محلية'), findsOneWidget);
    expect(find.textContaining('تنزيل'), findsNothing);
    expect(find.textContaining('تحميل الملف'), findsNothing);
    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });

  testWidgets('keeps Arabic RTL direction', (tester) async {
    final source = _source();
    await _pumpScreen(
      tester,
      pdfService: _FakePdfService((_) async => source),
      viewerBuilder: _successfulViewer,
    );
    await _pumpFrames(tester);

    final directionality = tester.widget<Directionality>(
      find.byKey(const Key('pdf-viewer-directionality')),
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('shows a safe service error and retries successfully', (
    tester,
  ) async {
    var attempts = 0;
    final source = _source();
    await _pumpScreen(
      tester,
      pdfService: _FakePdfService((_) async {
        attempts++;
        if (attempts == 1) {
          throw const PdfFailure(
            'غير مسموح بالوصول إلى هذا الملف.',
            PdfFailureReason.unauthorized,
          );
        }
        return source;
      }),
      viewerBuilder: _successfulViewer,
    );
    await _pumpFrames(tester);

    expect(find.text('غير مسموح بالوصول إلى هذا الملف.'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);
    expect(find.textContaining('student-content/'), findsNothing);

    await tester.tap(find.byKey(const Key('retry-pdf-button')));
    await _pumpFrames(tester);

    expect(attempts, 2);
    expect(find.byKey(const ValueKey('pdf-ready')), findsOneWidget);
  });

  testWidgets('handles viewer initialization failure safely', (tester) async {
    final source = _source();
    await _pumpScreen(
      tester,
      pdfService: _FakePdfService((_) async => source),
      viewerBuilder: (context, file, onLoaded, onFailed) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onFailed());
        return const SizedBox();
      },
    );
    await _pumpFrames(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );

    expect(find.text('تعذر عرض ملف PDF. حاول مرة أخرى.'), findsOneWidget);
    expect(find.byKey(const Key('retry-pdf-button')), findsOneWidget);
    expect(source.disposed, isTrue);
    expect(source.file.parent.existsSync(), isFalse);
  });

  testWidgets('back navigation removes the temporary PDF', (tester) async {
    final source = _source();
    final previous = source.file.parent.existsSync();
    expect(previous, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PdfViewerScreen(
                    resource: _resource(),
                    pdfService: _FakePdfService((_) async => source),
                    pdfDownloadService: _FakePdfDownloadService(
                      findDownloaded: (_) async => null,
                    ),
                    viewerBuilder: _successfulViewer,
                  ),
                ),
              ),
              child: const Text('افتح PDF'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح PDF'));
    await _pumpFrames(tester);

    Navigator.of(tester.element(find.byType(PdfViewerScreen))).pop();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );

    expect(find.byType(PdfViewerScreen), findsNothing);
    expect(source.disposed, isTrue);
    expect(source.file.parent.existsSync(), isFalse);
  });

  testWidgets('a pending preparation cleans up after the screen is disposed', (
    tester,
  ) async {
    final completer = Completer<PdfViewSource>();
    await _pumpScreen(
      tester,
      pdfService: _FakePdfService((_) => completer.future),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    final source = _source();
    completer.complete(source);
    await _pumpFrames(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );

    expect(source.disposed, isTrue);
    expect(source.file.parent.existsSync(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a valid persistent PDF without an online download', (
    tester,
  ) async {
    final persistentFolder = Directory.systemTemp.createTempSync(
      'student_assist_persistent_pdf_test_',
    );
    final persistentFile = File('${persistentFolder.path}/document.pdf')
      ..writeAsBytesSync('%PDF-1.7\n'.codeUnits);
    var onlineCalls = 0;

    await _pumpScreen(
      tester,
      pdfService: _FakePdfService((_) async {
        onlineCalls++;
        return _source();
      }),
      pdfDownloadService: _FakePdfDownloadService(
        findDownloaded: (_) async => persistentFile,
      ),
      viewerBuilder: _successfulViewer,
    );
    await _pumpFrames(tester);

    expect(find.byKey(const ValueKey('pdf-ready')), findsOneWidget);
    expect(onlineCalls, 0);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await _pumpFrames(tester);
    expect(persistentFile.existsSync(), isTrue);
    persistentFolder.deleteSync(recursive: true);
  });

  testWidgets('keeps existing online viewing when no download exists', (
    tester,
  ) async {
    final source = _source();
    var onlineCalls = 0;
    await _pumpScreen(
      tester,
      pdfService: _FakePdfService((_) async {
        onlineCalls++;
        return source;
      }),
      pdfDownloadService: _FakePdfDownloadService(
        findDownloaded: (_) async => null,
      ),
      viewerBuilder: _successfulViewer,
    );
    await _pumpFrames(tester);

    expect(onlineCalls, 1);
    expect(find.byKey(const ValueKey('pdf-ready')), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await _pumpFrames(tester);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Widget _successfulViewer(
  BuildContext context,
  File file,
  VoidCallback onLoaded,
  VoidCallback onFailed,
) {
  return _FakePdfViewer(onLoaded: onLoaded);
}

class _FakePdfViewer extends StatefulWidget {
  const _FakePdfViewer({required this.onLoaded});

  final VoidCallback onLoaded;

  @override
  State<_FakePdfViewer> createState() => _FakePdfViewerState();
}

class _FakePdfViewerState extends State<_FakePdfViewer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(child: Text('صفحات PDF محلية'));
  }
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required PdfService pdfService,
  PdfDownloadService? pdfDownloadService,
  PdfDocumentViewerBuilder? viewerBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: PdfViewerScreen(
        resource: _resource(),
        pdfService: pdfService,
        pdfDownloadService:
            pdfDownloadService ??
            _FakePdfDownloadService(findDownloaded: (_) async => null),
        viewerBuilder: viewerBuilder,
      ),
    ),
  );
}

_TrackingPdfViewSource _source() {
  final folder = Directory.systemTemp.createTempSync(
    'student_assist_pdf_screen_test_',
  );
  final file = File('${folder.path}/document.pdf');
  file.writeAsBytesSync('%PDF-1.7\n'.codeUnits);
  return _TrackingPdfViewSource(file, folder);
}

class _TrackingPdfViewSource extends PdfViewSource {
  _TrackingPdfViewSource(File file, this.folder) : super(file, folder);

  final Directory folder;
  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  }
}

Resource _resource() {
  return Resource(
    resourceId: 'resource-pdf-1',
    lessonId: 'lesson-1',
    title: 'ملخص الدرس',
    type: 'pdf',
    url: '',
    storagePath: 'approved/path.pdf',
    order: 1,
    isActive: true,
    createdAt: DateTime.utc(2026, 8, 27),
  );
}

class _FakePdfService extends PdfService {
  _FakePdfService(this.loader);

  final Future<PdfViewSource> Function(Resource resource) loader;

  @override
  Future<PdfViewSource> preparePdf(Resource resource) => loader(resource);
}

class _FakePdfDownloadService extends PdfDownloadService {
  _FakePdfDownloadService({required this.findDownloaded});

  final Future<File?> Function(Resource resource) findDownloaded;

  @override
  Future<File?> findDownloadedPdf(Resource resource) =>
      findDownloaded(resource);
}
