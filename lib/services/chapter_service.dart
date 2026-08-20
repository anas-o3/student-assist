import '../models/chapter.dart';
import '../repositories/chapter_repository.dart';

enum ChapterFailureReason { emptySubjectId, invalidData, backend }

class ChapterFailure implements Exception {
  const ChapterFailure(this.message, this.reason);

  final String message;
  final ChapterFailureReason reason;
}

class ChapterService {
  ChapterService([this._chapterRepository]);

  final ChapterRepository? _chapterRepository;
  ChapterRepository? _defaultChapterRepository;

  ChapterRepository get _chapters =>
      _chapterRepository ?? (_defaultChapterRepository ??= ChapterRepository());

  Future<List<Chapter>> loadActiveChaptersForSubject(String subjectId) async {
    final normalizedSubjectId = subjectId.trim();
    if (normalizedSubjectId.isEmpty) {
      throw const ChapterFailure(
        'تعذر تحديد المادة الدراسية.',
        ChapterFailureReason.emptySubjectId,
      );
    }

    try {
      return await _chapters.loadActiveChaptersForSubject(normalizedSubjectId);
    } on ChapterRepositoryFailure catch (error) {
      throw switch (error.reason) {
        ChapterRepositoryFailureReason.invalidData => const ChapterFailure(
          'بيانات الأبواب الدراسية غير صالحة.',
          ChapterFailureReason.invalidData,
        ),
        ChapterRepositoryFailureReason.backend => const ChapterFailure(
          'تعذر تحميل الأبواب الدراسية. حاول مرة أخرى.',
          ChapterFailureReason.backend,
        ),
      };
    }
  }
}
