import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/subject.dart';
import '../../services/subject_service.dart';
import '../../widgets/app_logo.dart';
import 'chapter_screen.dart';

typedef ChapterScreenBuilder = Widget Function(String subjectId);

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    super.key,
    required this.gradeId,
    this.subjectService,
    this.chapterScreenBuilder,
  });

  final String gradeId;
  final SubjectService? subjectService;
  final ChapterScreenBuilder? chapterScreenBuilder;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  SubjectService? _defaultSubjectService;
  List<Subject> _subjects = const [];
  String? _loadError;
  bool _isLoading = true;

  SubjectService get _subjectService =>
      widget.subjectService ?? (_defaultSubjectService ??= SubjectService());

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final subjects = await _subjectService.loadActiveSubjectsForGrade(
        widget.gradeId,
      );
      if (!mounted) return;
      setState(() {
        _subjects = List.unmodifiable(subjects);
        _isLoading = false;
        _loadError = null;
      });
    } on SubjectFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'تعذر تحميل المواد الدراسية. حاول مرة أخرى.';
      });
    }
  }

  void _openSubject(Subject subject) {
    final chapterScreen = widget.chapterScreenBuilder?.call(subject.subjectId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            chapterScreen ?? ChapterScreen(subjectId: subject.subjectId),
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
              const _HomeHeader(),
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
      return const _LoadingState(key: ValueKey('subjects-loading'));
    }

    final loadError = _loadError;
    if (loadError != null) {
      return _LoadErrorState(
        key: const ValueKey('subjects-load-error'),
        message: loadError,
        onRetry: _loadSubjects,
      );
    }

    if (_subjects.isEmpty) {
      return const _EmptyState(key: ValueKey('subjects-empty'));
    }

    return _SubjectGrid(
      key: const ValueKey('subjects-grid'),
      subjects: _subjects,
      onSubjectTap: _openSubject,
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: const BoxDecoration(
        color: AppTheme.card,
        border: Border(
          bottom: BorderSide(color: AppTheme.primaryLight, width: 1.5),
        ),
      ),
      child: const Row(
        children: [
          AppLogo(width: 54),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'المواد الدراسية',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectGrid extends StatelessWidget {
  const _SubjectGrid({
    super.key,
    required this.subjects,
    required this.onSubjectTap,
  });

  final List<Subject> subjects;
  final ValueChanged<Subject> onSubjectTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth > 900
            ? 900.0
            : constraints.maxWidth;
        final columnCount = contentWidth < 360
            ? 1
            : contentWidth < 700
            ? 2
            : 3;

        return Center(
          child: SizedBox(
            width: contentWidth,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: columnCount == 1 ? 1.35 : 0.92,
              ),
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                return _SubjectCard(
                  key: Key('subject-card-${subject.subjectId}'),
                  subject: subject,
                  onTap: () => onSubjectTap(subject),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({super.key, required this.subject, required this.onTap});

  final Subject subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.card,
      elevation: 2,
      shadowColor: AppTheme.textPrimary.withValues(alpha: 0.1),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _SubjectImage(subject: subject)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Text(
                subject.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectImage extends StatelessWidget {
  const _SubjectImage({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final imageUrl = subject.imageUrl.trim();
    if (imageUrl.isEmpty) {
      return _SubjectImagePlaceholder(subjectId: subject.subjectId);
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      cacheWidth: 600,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _SubjectImagePlaceholder(subjectId: subject.subjectId);
      },
      errorBuilder: (context, error, stackTrace) {
        return _SubjectImagePlaceholder(subjectId: subject.subjectId);
      },
    );
  }
}

class _SubjectImagePlaceholder extends StatelessWidget {
  const _SubjectImagePlaceholder({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('subject-image-placeholder-$subjectId'),
      color: AppTheme.primaryLight,
      alignment: Alignment.center,
      child: const Icon(
        Icons.menu_book_rounded,
        color: AppTheme.primary,
        size: 48,
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
            'جارٍ تحميل المواد الدراسية...',
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
              key: const Key('retry-subjects-button'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              color: AppTheme.textSecondary,
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد مواد دراسية متاحة لهذا الصف حالياً.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
