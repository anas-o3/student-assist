import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/lesson.dart';
import '../../services/lesson_service.dart';
import '../../widgets/app_logo.dart';

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({
    super.key,
    required this.chapterId,
    this.lessonService,
  });

  final String chapterId;
  final LessonService? lessonService;

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  LessonService? _defaultLessonService;
  List<Lesson> _lessons = const [];
  String? _loadError;
  bool _isLoading = true;

  LessonService get _lessonService =>
      widget.lessonService ?? (_defaultLessonService ??= LessonService());

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final lessons = await _lessonService.loadActiveLessonsForChapter(
        widget.chapterId,
      );
      if (!mounted) return;
      final orderedLessons = List<Lesson>.of(lessons)
        ..sort((first, second) => first.order.compareTo(second.order));
      setState(() {
        _lessons = List.unmodifiable(orderedLessons);
        _isLoading = false;
        _loadError = null;
      });
    } on LessonFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'تعذر تحميل الدروس. حاول مرة أخرى.';
      });
    }
  }

  void _showDeferredContentMessage() {
    // Temporary until the approved LessonContentScreen is implemented.
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('سيتم إضافة محتوى الدرس في المرحلة التالية.'),
          backgroundColor: AppTheme.primary,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              const _LessonHeader(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const _LoadingState(key: ValueKey('lessons-loading'));
    }

    final loadError = _loadError;
    if (loadError != null) {
      return _LoadErrorState(
        key: const ValueKey('lessons-load-error'),
        message: loadError,
        onRetry: _loadLessons,
      );
    }

    if (_lessons.isEmpty) {
      return const _EmptyState(key: ValueKey('lessons-empty'));
    }

    return _LessonList(
      key: const ValueKey('lessons-list'),
      lessons: _lessons,
      onLessonTap: _showDeferredContentMessage,
    );
  }
}

class _LessonHeader extends StatelessWidget {
  const _LessonHeader();

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
            key: const Key('lessons-back-button'),
            tooltip: 'رجوع',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.textPrimary,
            ),
          ),
          const AppLogo(width: 48),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'الدروس',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonList extends StatelessWidget {
  const _LessonList({
    super.key,
    required this.lessons,
    required this.onLessonTap,
  });

  final List<Lesson> lessons;
  final VoidCallback onLessonTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: lessons.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            return Card(
              key: Key('lesson-card-${lesson.lessonId}'),
              color: AppTheme.card,
              elevation: 1.5,
              shadowColor: AppTheme.textPrimary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onLessonTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  child: Text(
                    lesson.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 16),
          Text(
            'جارٍ تحميل الدروس...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.error,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              key: const Key('retry-lessons-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'لا توجد دروس متاحة لهذا الباب حالياً.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
