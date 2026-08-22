import '../models/resource.dart';
import '../repositories/resource_repository.dart';

enum ResourceFailureReason { emptyLessonId, invalidData, backend }

class ResourceFailure implements Exception {
  const ResourceFailure(this.message, this.reason);

  final String message;
  final ResourceFailureReason reason;
}

class ResourceService {
  ResourceService([this._resourceRepository]);

  final ResourceRepository? _resourceRepository;
  ResourceRepository? _defaultResourceRepository;

  ResourceRepository get _resources =>
      _resourceRepository ??
      (_defaultResourceRepository ??= ResourceRepository());

  Future<List<Resource>> loadActiveResourcesForLesson(String lessonId) async {
    final normalizedLessonId = lessonId.trim();
    if (normalizedLessonId.isEmpty) {
      throw const ResourceFailure(
        'تعذر تحديد الدرس.',
        ResourceFailureReason.emptyLessonId,
      );
    }

    try {
      return await _resources.loadActiveResourcesForLesson(normalizedLessonId);
    } on ResourceRepositoryFailure catch (error) {
      throw switch (error.reason) {
        ResourceRepositoryFailureReason.invalidData => const ResourceFailure(
          'بيانات موارد الدرس غير صالحة.',
          ResourceFailureReason.invalidData,
        ),
        ResourceRepositoryFailureReason.backend => const ResourceFailure(
          'تعذر تحميل موارد الدرس. حاول مرة أخرى.',
          ResourceFailureReason.backend,
        ),
      };
    }
  }
}
