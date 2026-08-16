import '../models/subject.dart';
import '../repositories/subject_repository.dart';

enum SubjectFailureReason { emptyGradeId, invalidData, backend }

class SubjectFailure implements Exception {
  const SubjectFailure(this.message, this.reason);

  final String message;
  final SubjectFailureReason reason;
}

class SubjectService {
  SubjectService([this._subjectRepository]);

  final SubjectRepository? _subjectRepository;
  SubjectRepository? _defaultSubjectRepository;

  SubjectRepository get _subjects =>
      _subjectRepository ?? (_defaultSubjectRepository ??= SubjectRepository());

  Future<List<Subject>> loadActiveSubjectsForGrade(String gradeId) async {
    final normalizedGradeId = gradeId.trim();
    if (normalizedGradeId.isEmpty) {
      throw const SubjectFailure(
        'تعذر تحديد الصف الدراسي.',
        SubjectFailureReason.emptyGradeId,
      );
    }

    try {
      return await _subjects.loadActiveSubjectsForGrade(normalizedGradeId);
    } on SubjectRepositoryFailure catch (error) {
      throw switch (error.reason) {
        SubjectRepositoryFailureReason.invalidData => const SubjectFailure(
          'بيانات المواد الدراسية غير صالحة.',
          SubjectFailureReason.invalidData,
        ),
        SubjectRepositoryFailureReason.backend => const SubjectFailure(
          'تعذر تحميل المواد الدراسية. حاول مرة أخرى.',
          SubjectFailureReason.backend,
        ),
      };
    }
  }
}
