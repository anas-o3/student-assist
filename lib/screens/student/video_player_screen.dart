import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme.dart';
import '../../models/resource.dart';
import '../../services/video_download_service.dart';
import '../../services/video_service.dart';

abstract class VideoPlaybackController {
  Future<void> initialize();

  bool get isInitialized;
  bool get isPlaying;
  double get aspectRatio;
  Duration get duration;
  Duration get position;

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  Widget buildView();
  Future<void> dispose();
}

typedef VideoPlaybackControllerFactory =
    VideoPlaybackController Function(File file);

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.resource,
    this.videoService,
    this.videoDownloadService,
    this.controllerFactory,
  });

  final Resource resource;
  final VideoService? videoService;
  final VideoDownloadService? videoDownloadService;
  final VideoPlaybackControllerFactory? controllerFactory;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoService? _defaultVideoService;
  VideoDownloadService? _defaultVideoDownloadService;
  VideoPlaybackSource? _source;
  VideoPlaybackController? _controller;
  String? _errorMessage;
  bool _isLoading = true;

  VideoService get _videoService =>
      widget.videoService ?? (_defaultVideoService ??= VideoService());
  VideoDownloadService get _videoDownloadService =>
      widget.videoDownloadService ??
      (_defaultVideoDownloadService ??= VideoDownloadService());

  @override
  void initState() {
    super.initState();
    _prepareVideo();
  }

  Future<void> _prepareVideo() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    await _releasePlayback();

    try {
      final source = await _preparePreferredSource();
      if (!mounted) {
        await source.dispose();
        return;
      }

      final controller =
          widget.controllerFactory?.call(source.file) ??
          _VideoPlayerControllerAdapter(source.file);
      _source = source;
      _controller = controller;
      controller.addListener(_onPlaybackChanged);
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } on VideoFailure catch (error) {
      await _releasePlayback();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      await _releasePlayback();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تشغيل الفيديو. حاول مرة أخرى.';
      });
    }
  }

  Future<VideoPlaybackSource> _preparePreferredSource() async {
    try {
      final persistentFile = await _videoDownloadService.findDownloadedVideo(
        widget.resource,
      );
      if (persistentFile != null) {
        return VideoPlaybackSource.persistent(persistentFile);
      }
    } on VideoDownloadFailure {
      // A local lookup problem must not break authenticated online playback.
    }

    return _videoService.prepareOnlineVideo(widget.resource);
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.isInitialized) return;

    if (controller.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _releasePlayback() async {
    final controller = _controller;
    final source = _source;
    _controller = null;
    _source = null;

    if (controller != null) {
      controller.removeListener(_onPlaybackChanged);
      await controller.dispose();
    }
    if (source != null) await source.dispose();
  }

  @override
  void dispose() {
    unawaited(_releasePlayback());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      key: const Key('video-player-directionality'),
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            widget.resource.title,
            key: const Key('video-player-title'),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _buildContent(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const _VideoLoadingState(key: ValueKey('video-loading'));
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _VideoErrorState(
        key: const ValueKey('video-error'),
        message: errorMessage,
        onRetry: _prepareVideo,
      );
    }

    final controller = _controller;
    if (controller == null || !controller.isInitialized) {
      return _VideoErrorState(
        key: const ValueKey('video-error'),
        message: 'تعذر تشغيل الفيديو. حاول مرة أخرى.',
        onRetry: _prepareVideo,
      );
    }

    final durationMilliseconds = controller.duration.inMilliseconds;
    final maximum = durationMilliseconds > 0
        ? durationMilliseconds.toDouble()
        : 1.0;
    final position = controller.position.inMilliseconds
        .clamp(0, maximum.toInt())
        .toDouble();

    return Column(
      key: const ValueKey('video-ready'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: controller.aspectRatio > 0
                  ? controller.aspectRatio
                  : 16 / 9,
              child: controller.buildView(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryLight),
          ),
          child: Row(
            children: [
              IconButton.filled(
                key: const Key('video-play-pause-button'),
                tooltip: controller.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                onPressed: _togglePlayback,
                icon: Icon(
                  controller.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  key: const Key('video-progress-slider'),
                  min: 0,
                  max: maximum,
                  value: position,
                  onChanged: (value) {
                    controller.seekTo(Duration(milliseconds: value.round()));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatDuration(controller.position)} / '
                '${_formatDuration(controller.duration)}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}

class _VideoLoadingState extends StatelessWidget {
  const _VideoLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: Key('video-loading-content'),
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppTheme.primary),
        SizedBox(height: 14),
        Text(
          'جارٍ تجهيز الفيديو...',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      ],
    );
  }
}

class _VideoErrorState extends StatelessWidget {
  const _VideoErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.error,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('retry-video-button'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerControllerAdapter implements VideoPlaybackController {
  _VideoPlayerControllerAdapter(File file)
    : _controller = VideoPlayerController.file(file);

  final VideoPlayerController _controller;

  @override
  double get aspectRatio => _controller.value.aspectRatio;

  @override
  Duration get duration => _controller.value.duration;

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  bool get isPlaying => _controller.value.isPlaying;

  @override
  Duration get position => _controller.value.position;

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> play() => _controller.play();

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);

  @override
  Future<void> seekTo(Duration position) => _controller.seekTo(position);
}
