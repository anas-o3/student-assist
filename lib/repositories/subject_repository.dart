import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/subject.dart';

enum SubjectRepositoryFailureReason { invalidData, backend }

class SubjectRepositoryFailure implements Exception {
  const SubjectRepositoryFailure([
    this.reason = SubjectRepositoryFailureReason.backend,
  ]);

  final SubjectRepositoryFailureReason reason;
}

typedef SubjectDocument = ({String documentId, Map<String, dynamic> data});
typedef SubjectDocumentLoader =
    Future<List<SubjectDocument>> Function(String gradeId);

class SubjectRepository {
  SubjectRepository([this._firestore, this._subjectDocumentLoader]);

  final FirebaseFirestore? _firestore;
  final SubjectDocumentLoader? _subjectDocumentLoader;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;

  Future<List<Subject>> loadActiveSubjectsForGrade(String gradeId) async {
    try {
      final documents = await _loadDocuments(gradeId);
      return documents
          .map(
            (document) => Subject.fromFirestore(
              documentId: document.documentId,
              data: document.data,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      throw const SubjectRepositoryFailure(
        SubjectRepositoryFailureReason.invalidData,
      );
    } on FirebaseException {
      throw const SubjectRepositoryFailure();
    }
  }

  Future<List<SubjectDocument>> _loadDocuments(String gradeId) async {
    final loader = _subjectDocumentLoader;
    if (loader != null) return loader(gradeId);

    final snapshot = await _database
        .collection('subjects')
        .where('gradeId', isEqualTo: gradeId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((document) => (documentId: document.id, data: document.data()))
        .toList(growable: false);
  }
}
