import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/chapter.dart';
import '../../services/chapter_service.dart';
import '../../widgets/app_logo.dart';

class ChapterScreen extends StatefulWidget {
  const ChapterScreen({
    super.key,
    required this.subjectId,
    this.chapterService,
  });

  final String subjectId;
  final ChapterService? chapterService;

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  ChapterService? _defaultChapterService;
  List<Chapter> _chapters = const [];
  String? _loadError;
  bool _isLoading = true;

  ChapterService get _chapterService =>
      widget.chapterService ?? (_defaultChapterService ??= ChapterService());

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final chapters = await _chapterService.loadActiveChaptersForSubject(
        widget.subjectId,
      );
      if (!mounted) return;
      final orderedChapters = List<Chapter>.of(chapters)
        ..sort((first, second) => first.order.compareTo(second.order));
      setState(() {
        _chapters = List.unmodifiable(orderedChapters);
        _isLoading = false;
        _loadError = null;
      });
    } on ChapterFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'تعذر تحميل الأبواب الدراسية. حاول مرة أخرى.';
      });
    }
  }

  void _showDeferredLessonMessage() {
    // Temporary until the approved LessonScreen is implemented.
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('سيتم إضافة الدروس في المرحلة التالية.'),
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
              const _ChapterHeader(),
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
      return const _LoadingState(key: ValueKey('chapters-loading'));
    }

    final loadError = _loadError;
    if (loadError != null) {
      return _LoadErrorState(
        key: const ValueKey('chapters-load-error'),
        message: loadError,
        onRetry: _loadChapters,
      );
    }

    if (_chapters.isEmpty) {
      return const _EmptyState(key: ValueKey('chapters-empty'));
    }

    return _ChapterList(
      key: const ValueKey('chapters-list'),
      chapters: _chapters,
      onChapterTap: _showDeferredLessonMessage,
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader();

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
            key: const Key('chapters-back-button'),
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
              'الأبواب الدراسية',
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

class _ChapterList extends StatelessWidget {
  const _ChapterList({
    super.key,
    required this.chapters,
    required this.onChapterTap,
  });

  final List<Chapter> chapters;
  final VoidCallback onChapterTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: chapters.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            return Card(
              key: Key('chapter-card-${chapter.chapterId}'),
              color: AppTheme.card,
              elevation: 1.5,
              shadowColor: AppTheme.textPrimary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onChapterTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  child: Text(
                    chapter.title,
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
            'جارٍ تحميل الأبواب الدراسية...',
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
              key: const Key('retry-chapters-button'),
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
          'لا توجد أبواب دراسية متاحة لهذه المادة حالياً.',
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
