import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chapter.dart';

enum ChapterRepositoryFailureReason { invalidData, backend }

class ChapterRepositoryFailure implements Exception {
  const ChapterRepositoryFailure([
    this.reason = ChapterRepositoryFailureReason.backend,
  ]);

  final ChapterRepositoryFailureReason reason;
}

typedef ChapterDocument = ({String documentId, Map<String, dynamic> data});
typedef ChapterDocumentLoader =
    Future<List<ChapterDocument>> Function(String subjectId);

class ChapterRepository {
  ChapterRepository([this._firestore, this._chapterDocumentLoader]);

  final FirebaseFirestore? _firestore;
  final ChapterDocumentLoader? _chapterDocumentLoader;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;

  Future<List<Chapter>> loadActiveChaptersForSubject(String subjectId) async {
    try {
      final documents = await _loadDocuments(subjectId);
      return documents
          .map(
            (document) => Chapter.fromFirestore(
              documentId: document.documentId,
              data: document.data,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      throw const ChapterRepositoryFailure(
        ChapterRepositoryFailureReason.invalidData,
      );
    } on FirebaseException {
      throw const ChapterRepositoryFailure();
    }
  }

  Future<List<ChapterDocument>> _loadDocuments(String subjectId) async {
    final loader = _chapterDocumentLoader;
    if (loader != null) return loader(subjectId);

    final snapshot = await _database
        .collection('chapters')
        .where('subjectId', isEqualTo: subjectId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((document) => (documentId: document.id, data: document.data()))
        .toList(growable: false);
  }
}
