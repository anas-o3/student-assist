import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lesson.dart';

enum LessonRepositoryFailureReason { invalidData, backend }

class LessonRepositoryFailure implements Exception {
  const LessonRepositoryFailure([
    this.reason = LessonRepositoryFailureReason.backend,
  ]);

  final LessonRepositoryFailureReason reason;
}

typedef LessonDocument = ({String documentId, Map<String, dynamic> data});
typedef LessonDocumentLoader =
    Future<List<LessonDocument>> Function({
      required String chapterId,
      required bool isActive,
      required String orderByField,
    });

class LessonRepository {
  LessonRepository([this._firestore, this._lessonDocumentLoader]);

  final FirebaseFirestore? _firestore;
  final LessonDocumentLoader? _lessonDocumentLoader;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;

  Future<List<Lesson>> loadActiveLessonsForChapter(String chapterId) async {
    try {
      final documents = await _loadDocuments(chapterId);
      return documents
          .map(
            (document) => Lesson.fromFirestore(
              documentId: document.documentId,
              data: document.data,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      throw const LessonRepositoryFailure(
        LessonRepositoryFailureReason.invalidData,
      );
    } on FirebaseException {
      throw const LessonRepositoryFailure();
    }
  }

  Future<List<LessonDocument>> _loadDocuments(String chapterId) async {
    final loader = _lessonDocumentLoader;
    if (loader != null) {
      return loader(
        chapterId: chapterId,
        isActive: true,
        orderByField: 'order',
      );
    }

    final snapshot = await _database
        .collection('lessons')
        .where('chapterId', isEqualTo: chapterId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((document) => (documentId: document.id, data: document.data()))
        .toList(growable: false);
  }
}
