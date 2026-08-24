import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/lesson.dart';
import '../../models/resource.dart';
import '../../services/resource_service.dart';
import '../../widgets/app_logo.dart';

class LessonContentScreen extends StatefulWidget {
  const LessonContentScreen({
    super.key,
    required this.lesson,
    this.resourceService,
  });

  final Lesson lesson;
  final ResourceService? resourceService;

  @override
  State<LessonContentScreen> createState() => _LessonContentScreenState();
}

class _LessonContentScreenState extends State<LessonContentScreen> {
  ResourceService? _defaultResourceService;
  List<Resource> _resources = const [];
  String? _loadError;
  bool _isLoading = true;

  ResourceService get _resourceService =>
      widget.resourceService ?? (_defaultResourceService ??= ResourceService());

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
    );
  }
}

class _ResourceList extends StatelessWidget {
  const _ResourceList({super.key, required this.resources});

  final List<Resource> resources;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < resources.length; index++) ...[
          _ResourceCard(resource: resources[index]),
          if (index != resources.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource});

  final Resource resource;

  @override
  Widget build(BuildContext context) {
    final isVideo = resource.type == 'video';

    return Container(
      key: Key('resource-card-${resource.resourceId}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
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
        ],
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
