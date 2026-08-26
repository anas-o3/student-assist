import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/app/theme.dart';
import 'package:student_assist/models/resource.dart';
import 'package:student_assist/screens/student/video_player_screen.dart';
import 'package:student_assist/services/video_service.dart';

void main() {
  testWidgets('shows loading while the authenticated video is prepared', (
    tester,
  ) async {
    final completer = Completer<VideoPlaybackSource>();
    await _pumpScreen(
      tester,
      videoService: _FakeVideoService((_) => completer.future),
      controllerFactory: (_) => _FakeController(),
    );

    expect(find.byKey(const ValueKey('video-loading')), findsOneWidget);
    expect(find.text('جارٍ تجهيز الفيديو...'), findsOneWidget);

    final source = _FakeSource();
    completer.complete(source);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('video-ready')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('shows player controls and toggles play and pause', (
    tester,
  ) async {
    final source = _FakeSource();
    final controller = _FakeController();
    await _pumpScreen(
      tester,
      videoService: _FakeVideoService((_) async => source),
      controllerFactory: (_) => controller,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('video-ready')), findsOneWidget);
    expect(find.byKey(const Key('video-progress-slider')), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('video-play-pause-button')));
    await tester.pump();
    expect(controller.playCalls, 1);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('video-play-pause-button')));
    await tester.pump();
    expect(controller.pauseCalls, 1);
  });

  testWidgets('shows a safe Arabic error and retries', (tester) async {
    var attempts = 0;
    final source = _FakeSource();
    final service = _FakeVideoService((_) async {
      attempts++;
      if (attempts == 1) {
        throw const VideoFailure(
          'تعذر تحميل الفيديو. حاول مرة أخرى.',
          VideoFailureReason.backend,
        );
      }
      return source;
    });
    await _pumpScreen(
      tester,
      videoService: service,
      controllerFactory: (_) => _FakeController(),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('video-error')), findsOneWidget);
    expect(find.textContaining('raw Firebase'), findsNothing);

    await tester.tap(find.byKey(const Key('retry-video-button')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byKey(const ValueKey('video-ready')), findsOneWidget);
  });

  testWidgets('player initialization failure produces a safe Arabic error', (
    tester,
  ) async {
    final source = _FakeSource();
    await _pumpScreen(
      tester,
      videoService: _FakeVideoService((_) async => source),
      controllerFactory: (_) => _FakeController(initializeFails: true),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('video-error')), findsOneWidget);
    expect(find.text('تعذر تشغيل الفيديو. حاول مرة أخرى.'), findsOneWidget);
    expect(find.textContaining('platform exception'), findsNothing);
    expect(source.disposeCalls, 1);
  });

  testWidgets('empty storagePath fails safely without creating a controller', (
    tester,
  ) async {
    var controllerCalls = 0;
    await _pumpScreen(
      tester,
      resource: _resource(storagePath: ''),
      videoService: VideoService(),
      controllerFactory: (_) {
        controllerCalls++;
        return _FakeController();
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('ملف الفيديو غير متوفر.'), findsOneWidget);
    expect(controllerCalls, 0);
  });

  testWidgets('disposes controller and temporary source on back', (
    tester,
  ) async {
    final source = _FakeSource();
    final controller = _FakeController();
    final service = _FakeVideoService((_) async => source);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VideoPlayerScreen(
                  resource: _resource(),
                  videoService: service,
                  controllerFactory: (_) => controller,
                ),
              ),
            ),
            child: const Text('فتح الفيديو'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح الفيديو'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pump();

    expect(controller.disposeCalls, 1);
    expect(source.disposeCalls, 1);
    expect(find.text('فتح الفيديو'), findsOneWidget);
  });

  testWidgets('disposal during preparation cleans a late temporary source', (
    tester,
  ) async {
    final completer = Completer<VideoPlaybackSource>();
    final source = _FakeSource();
    var controllerCalls = 0;

    await _pumpScreen(
      tester,
      videoService: _FakeVideoService((_) => completer.future),
      controllerFactory: (_) {
        controllerCalls++;
        return _FakeController();
      },
    );
    expect(find.byKey(const ValueKey('video-loading')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    completer.complete(source);
    await tester.pump();
    await tester.pump();

    expect(source.disposeCalls, 1);
    expect(controllerCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses Arabic RTL and contains no PDF or download actions', (
    tester,
  ) async {
    final source = _FakeSource();
    await _pumpScreen(
      tester,
      videoService: _FakeVideoService((_) async => source),
      controllerFactory: (_) => _FakeController(),
    );
    await tester.pumpAndSettle();

    final directionality = tester.widget<Directionality>(
      find.byKey(const Key('video-player-directionality')),
    );
    expect(directionality.textDirection, TextDirection.rtl);
    expect(find.textContaining('PDF'), findsNothing);
    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  Resource? resource,
  required VideoService videoService,
  required VideoPlaybackControllerFactory controllerFactory,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: VideoPlayerScreen(
        resource: resource ?? _resource(),
        videoService: videoService,
        controllerFactory: controllerFactory,
      ),
    ),
  );
}

Resource _resource({String storagePath = 'approved/video.mp4'}) {
  return Resource(
    resourceId: 'video-1',
    lessonId: 'lesson-1',
    title: 'شرح مرئي',
    type: 'video',
    url: '',
    storagePath: storagePath,
    order: 1,
    isActive: true,
    createdAt: DateTime.utc(2026, 8, 24),
  );
}

class _FakeVideoService extends VideoService {
  _FakeVideoService(this.loader);

  final Future<VideoPlaybackSource> Function(Resource resource) loader;

  @override
  Future<VideoPlaybackSource> prepareOnlineVideo(Resource resource) {
    return loader(resource);
  }
}

class _FakeSource extends VideoPlaybackSource {
  _FakeSource() : super(File('unused-video.mp4'), Directory('unused-video'));

  int disposeCalls = 0;

  @override
  Future<void> dispose() async => disposeCalls++;
}

class _FakeController implements VideoPlaybackController {
  _FakeController({this.initializeFails = false});

  final bool initializeFails;
  final List<VoidCallback> _listeners = [];
  bool _isInitialized = false;
  bool _isPlaying = false;
  Duration _position = const Duration(seconds: 15);
  int playCalls = 0;
  int pauseCalls = 0;
  int disposeCalls = 0;

  @override
  double get aspectRatio => 16 / 9;

  @override
  Duration get duration => const Duration(minutes: 2);

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Duration get position => _position;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  Widget buildView() =>
      const ColoredBox(key: Key('fake-video-view'), color: Colors.black);

  @override
  Future<void> dispose() async => disposeCalls++;

  @override
  Future<void> initialize() async {
    if (initializeFails) throw StateError('raw platform exception');
    _isInitialized = true;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _isPlaying = false;
    _notify();
  }

  @override
  Future<void> play() async {
    playCalls++;
    _isPlaying = true;
    _notify();
  }

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<void> seekTo(Duration position) async {
    _position = position;
    _notify();
  }

  void _notify() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }
}
