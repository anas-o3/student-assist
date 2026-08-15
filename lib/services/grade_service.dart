import '../models/grade.dart';
import '../repositories/grade_repository.dart';

class GradeFailure implements Exception {
  const GradeFailure(this.message);

  final String message;
}

class GradeService {
  GradeService([this._gradeRepository]);

  final GradeRepository? _gradeRepository;
  GradeRepository? _defaultGradeRepository;

  GradeRepository get _grades =>
      _gradeRepository ?? (_defaultGradeRepository ??= GradeRepository());

  Future<List<Grade>> loadActiveGrades() async {
    try {
      return await _grades.loadActiveGrades();
    } on GradeRepositoryFailure {
      throw const GradeFailure('تعذر تحميل الصفوف الدراسية. حاول مرة أخرى.');
    }
  }
}
