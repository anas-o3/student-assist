import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/question.dart';

enum QuestionRepositoryFailureReason { invalidData, backend }

class QuestionRepositoryFailure implements Exception {
  const QuestionRepositoryFailure([
    this.reason = QuestionRepositoryFailureReason.backend,
  ]);

  final QuestionRepositoryFailureReason reason;
}

typedef QuestionDocument = ({String documentId, Map<String, dynamic> data});
typedef QuestionDocumentLoader =
    Future<List<QuestionDocument>> Function({
      required String lessonId,
      required bool isActive,
      required String orderByField,
    });

class QuestionRepository {
  QuestionRepository([this._firestore, this._questionDocumentLoader]);

  final FirebaseFirestore? _firestore;
  final QuestionDocumentLoader? _questionDocumentLoader;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;

  Future<List<Question>> loadActiveQuestionsForLesson(String lessonId) async {
    try {
      final documents = await _loadDocuments(lessonId);
      return documents
          .map(
            (document) => Question.fromFirestore(
              documentId: document.documentId,
              data: document.data,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      throw const QuestionRepositoryFailure(
        QuestionRepositoryFailureReason.invalidData,
      );
    } on FirebaseException {
      throw const QuestionRepositoryFailure();
    }
  }

  Future<List<QuestionDocument>> _loadDocuments(String lessonId) async {
    final loader = _questionDocumentLoader;
    if (loader != null) {
      return loader(
        lessonId: lessonId,
        isActive: true,
        orderByField: 'order',
      );
    }

    final snapshot = await _database
        .collection('questions')
        .where('lessonId', isEqualTo: lessonId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((document) => (documentId: document.id, data: document.data()))
        .toList(growable: false);
  }
}
