import '../models/lesson.dart';
import '../repositories/lesson_repository.dart';

enum LessonFailureReason { emptyChapterId, invalidData, backend }

class LessonFailure implements Exception {
  const LessonFailure(this.message, this.reason);

  final String message;
  final LessonFailureReason reason;
}

class LessonService {
  LessonService([this._lessonRepository]);

  final LessonRepository? _lessonRepository;
  LessonRepository? _defaultLessonRepository;

  LessonRepository get _lessons =>
      _lessonRepository ?? (_defaultLessonRepository ??= LessonRepository());

  Future<List<Lesson>> loadActiveLessonsForChapter(String chapterId) async {
    final normalizedChapterId = chapterId.trim();
    if (normalizedChapterId.isEmpty) {
      throw const LessonFailure(
        'تعذر تحديد الباب الدراسي.',
        LessonFailureReason.emptyChapterId,
      );
    }

    try {
      return await _lessons.loadActiveLessonsForChapter(normalizedChapterId);
    } on LessonRepositoryFailure catch (error) {
      throw switch (error.reason) {
        LessonRepositoryFailureReason.invalidData => const LessonFailure(
          'بيانات الدروس غير صالحة.',
          LessonFailureReason.invalidData,
        ),
        LessonRepositoryFailureReason.backend => const LessonFailure(
          'تعذر تحميل الدروس. حاول مرة أخرى.',
          LessonFailureReason.backend,
        ),
      };
    }
  }
}
