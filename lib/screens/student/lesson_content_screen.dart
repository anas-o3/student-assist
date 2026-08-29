import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/lesson.dart';
import '../../models/resource.dart';
import '../../services/pdf_download_service.dart';
import '../../services/resource_service.dart';
import '../../services/video_download_service.dart';
import '../../widgets/app_logo.dart';
import 'pdf_viewer_screen.dart';
import 'video_player_screen.dart';

class LessonContentScreen extends StatefulWidget {
  const LessonContentScreen({
    super.key,
    required this.lesson,
    this.resourceService,
    this.pdfDownloadService,
    this.videoDownloadService,
  });

  final Lesson lesson;
  final ResourceService? resourceService;
  final PdfDownloadService? pdfDownloadService;
  final VideoDownloadService? videoDownloadService;

  @override
  State<LessonContentScreen> createState() => _LessonContentScreenState();
}

class _LessonContentScreenState extends State<LessonContentScreen> {
  ResourceService? _defaultResourceService;
  PdfDownloadService? _defaultPdfDownloadService;
  VideoDownloadService? _defaultVideoDownloadService;
  List<Resource> _resources = const [];
  final Map<String, _PdfDownloadState> _pdfDownloadStates = {};
  final Map<String, _VideoDownloadState> _videoDownloadStates = {};
  String? _loadError;
  bool _isLoading = true;

  ResourceService get _resourceService =>
      widget.resourceService ?? (_defaultResourceService ??= ResourceService());
  PdfDownloadService get _pdfDownloadService =>
      widget.pdfDownloadService ??
      (_defaultPdfDownloadService ??= PdfDownloadService());
  VideoDownloadService get _videoDownloadService =>
      widget.videoDownloadService ??
      (_defaultVideoDownloadService ??= VideoDownloadService());

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final resources = await _resourceService.loadActiveResourcesForLesson(
        widget.lesson.lessonId,
      );
      if (!mounted) return;

      final supportedResources =
          resources
              .where(
                (resource) =>
                    resource.type == 'video' || resource.type == 'pdf',
              )
              .toList(growable: false)
            ..sort((first, second) => first.order.compareTo(second.order));

      setState(() {
        _resources = List.unmodifiable(supportedResources);
        _isLoading = false;
        _loadError = null;
      });
    } on ResourceFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'تعذر تحميل موارد الدرس. حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      key: const Key('lesson-content-directionality'),
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _LessonContentHeader(title: widget.lesson.title),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: SingleChildScrollView(
                      key: const Key('lesson-content-scroll-view'),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 22,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.primaryLight),
                            ),
                            child: Text(
                              widget.lesson.explanation,
                              key: const Key('lesson-explanation'),
                              textAlign: TextAlign.start,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 17,
                                height: 1.9,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'موارد الدرس',
                            key: Key('lesson-resources-heading'),
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _buildResourcesContent(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourcesContent() {
    if (_isLoading) {
      return const _ResourcesLoadingState(
        key: ValueKey('lesson-resources-loading'),
      );
    }

    final loadError = _loadError;
    if (loadError != null) {
      return _ResourcesErrorState(
        key: const ValueKey('lesson-resources-error'),
        message: loadError,
        onRetry: _loadResources,
      );
    }

    if (_resources.isEmpty) {
      return const _ResourcesEmptyState(
        key: ValueKey('lesson-resources-empty'),
      );
    }

    return _ResourceList(
      key: const ValueKey('lesson-resources-list'),
      resources: _resources,
      onVideoTap: _openVideo,
      onPdfTap: _openPdf,
      onVideoDownload: _downloadVideo,
      onPdfDownload: _downloadPdf,
      videoDownloadStates: _videoDownloadStates,
      pdfDownloadStates: _pdfDownloadStates,
    );
  }

  void _openVideo(Resource resource) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerScreen(
          resource: resource,
          videoDownloadService: _videoDownloadService,
        ),
      ),
    );
  }

  void _openPdf(Resource resource) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerScreen(
          resource: resource,
          pdfDownloadService: _pdfDownloadService,
        ),
      ),
    );
  }

  Future<void> _downloadPdf(Resource resource) async {
    if (_pdfDownloadStates[resource.resourceId] ==
        _PdfDownloadState.downloading) {
      return;
    }

    setState(() {
      _pdfDownloadStates[resource.resourceId] = _PdfDownloadState.downloading;
    });

    try {
      final result = await _pdfDownloadService.downloadPdf(resource);
      if (!mounted) return;
      setState(() {
        _pdfDownloadStates[resource.resourceId] = _PdfDownloadState.downloaded;
      });
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.wasAlreadyDownloaded
                ? 'الملف محفوظ مسبقًا على الجهاز.'
                : 'تم تنزيل الملف بنجاح.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } on PdfDownloadFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _pdfDownloadStates[resource.resourceId] = _PdfDownloadState.failed;
      });
      _showDownloadError(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pdfDownloadStates[resource.resourceId] = _PdfDownloadState.failed;
      });
      _showDownloadError('تعذر تنزيل ملف PDF. حاول مرة أخرى.');
    }
  }

  Future<void> _downloadVideo(Resource resource) async {
    if (_videoDownloadStates[resource.resourceId] ==
        _VideoDownloadState.downloading) {
      return;
    }

    setState(() {
      _videoDownloadStates[resource.resourceId] =
          _VideoDownloadState.downloading;
    });

    try {
      final result = await _videoDownloadService.downloadVideo(resource);
      if (!mounted) return;
      setState(() {
        _videoDownloadStates[resource.resourceId] =
            _VideoDownloadState.downloaded;
      });
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.wasAlreadyDownloaded
                ? 'الفيديو محفوظ مسبقًا على الجهاز.'
                : 'تم تنزيل الفيديو بنجاح.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } on VideoDownloadFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _videoDownloadStates[resource.resourceId] = _VideoDownloadState.failed;
      });
      _showDownloadError(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoDownloadStates[resource.resourceId] = _VideoDownloadState.failed;
      });
      _showDownloadError('تعذر تنزيل ملف الفيديو. حاول مرة أخرى.');
    }
  }

  void _showDownloadError(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }
}

enum _PdfDownloadState { downloading, downloaded, failed }

enum _VideoDownloadState { downloading, downloaded, failed }

class _ResourceList extends StatelessWidget {
  const _ResourceList({
    super.key,
    required this.resources,
    required this.onVideoTap,
    required this.onPdfTap,
    required this.onVideoDownload,
    required this.onPdfDownload,
    required this.videoDownloadStates,
    required this.pdfDownloadStates,
  });

  final List<Resource> resources;
  final ValueChanged<Resource> onVideoTap;
  final ValueChanged<Resource> onPdfTap;
  final ValueChanged<Resource> onVideoDownload;
  final ValueChanged<Resource> onPdfDownload;
  final Map<String, _VideoDownloadState> videoDownloadStates;
  final Map<String, _PdfDownloadState> pdfDownloadStates;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < resources.length; index++) ...[
          _ResourceCard(
            resource: resources[index],
            onTap: switch (resources[index].type) {
              'video' => () => onVideoTap(resources[index]),
              'pdf' => () => onPdfTap(resources[index]),
              _ => null,
            },
            onDownload: resources[index].type == 'pdf'
                ? () => onPdfDownload(resources[index])
                : null,
            downloadState: pdfDownloadStates[resources[index].resourceId],
            onVideoDownload: resources[index].type == 'video'
                ? () => onVideoDownload(resources[index])
                : null,
            videoDownloadState:
                videoDownloadStates[resources[index].resourceId],
          ),
          if (index != resources.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.resource,
    this.onTap,
    this.onDownload,
    this.downloadState,
    this.onVideoDownload,
    this.videoDownloadState,
  });

  final Resource resource;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final _PdfDownloadState? downloadState;
  final VoidCallback? onVideoDownload;
  final _VideoDownloadState? videoDownloadState;

  @override
  Widget build(BuildContext context) {
    final isVideo = resource.type == 'video';

    return Material(
      key: Key('resource-card-${resource.resourceId}'),
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVideo
                      ? Icons.play_circle_outline_rounded
                      : Icons.picture_as_pdf_outlined,
                  color: AppTheme.primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isVideo ? 'فيديو' : 'ملخص PDF',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isVideo && onVideoDownload != null) ...[
                const SizedBox(width: 8),
                _VideoDownloadButton(
                  resourceId: resource.resourceId,
                  state: videoDownloadState,
                  onPressed: onVideoDownload!,
                ),
              ],
              if (!isVideo && onDownload != null) ...[
                const SizedBox(width: 8),
                _PdfDownloadButton(
                  resourceId: resource.resourceId,
                  state: downloadState,
                  onPressed: onDownload!,
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textSecondary,
                  size: 17,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfDownloadButton extends StatelessWidget {
  const _PdfDownloadButton({
    required this.resourceId,
    required this.state,
    required this.onPressed,
  });

  final String resourceId;
  final _PdfDownloadState? state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDownloading = state == _PdfDownloadState.downloading;
    final isDownloaded = state == _PdfDownloadState.downloaded;

    return Semantics(
      button: true,
      label: isDownloaded ? 'تم التنزيل' : 'تنزيل ملف PDF',
      child: IconButton(
        key: Key('download-pdf-$resourceId'),
        tooltip: isDownloaded ? 'تم التنزيل' : 'تنزيل',
        onPressed: isDownloading ? null : onPressed,
        color: isDownloaded ? AppTheme.success : AppTheme.primary,
        icon: isDownloading
            ? const SizedBox(
                key: Key('pdf-download-progress'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Icon(
                isDownloaded
                    ? Icons.download_done_rounded
                    : Icons.download_rounded,
              ),
      ),
    );
  }
}

class _VideoDownloadButton extends StatelessWidget {
  const _VideoDownloadButton({
    required this.resourceId,
    required this.state,
    required this.onPressed,
  });

  final String resourceId;
  final _VideoDownloadState? state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDownloading = state == _VideoDownloadState.downloading;
    final isDownloaded = state == _VideoDownloadState.downloaded;

    return Semantics(
      button: true,
      label: isDownloaded ? 'تم تنزيل الفيديو' : 'تنزيل الفيديو',
      child: IconButton(
        key: Key('download-video-$resourceId'),
        tooltip: isDownloaded ? 'تم التنزيل' : 'تنزيل',
        onPressed: isDownloading ? null : onPressed,
        color: isDownloaded ? AppTheme.success : AppTheme.primary,
        icon: isDownloading
            ? const SizedBox(
                key: Key('video-download-progress'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Icon(
                isDownloaded
                    ? Icons.download_done_rounded
                    : Icons.download_rounded,
              ),
      ),
    );
  }
}

class _ResourcesLoadingState extends StatelessWidget {
  const _ResourcesLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'جارٍ تحميل موارد الدرس...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _ResourcesEmptyState extends StatelessWidget {
  const _ResourcesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryLight),
      ),
      child: const Text(
        'لا توجد موارد متاحة لهذا الدرس حاليًا.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }
}

class _ResourcesErrorState extends StatelessWidget {
  const _ResourcesErrorState({
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.error,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const Key('retry-lesson-resources-button'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _LessonContentHeader extends StatelessWidget {
  const _LessonContentHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 14),
      decoration: const BoxDecoration(
        color: AppTheme.card,
        border: Border(
          bottom: BorderSide(color: AppTheme.primaryLight, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('lesson-content-back-button'),
            tooltip: 'رجوع',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.textPrimary,
            ),
          ),
          const AppLogo(width: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              key: const Key('lesson-content-title'),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
