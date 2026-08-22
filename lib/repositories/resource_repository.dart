import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/resource.dart';

enum ResourceRepositoryFailureReason { invalidData, backend }

class ResourceRepositoryFailure implements Exception {
  const ResourceRepositoryFailure([
    this.reason = ResourceRepositoryFailureReason.backend,
  ]);

  final ResourceRepositoryFailureReason reason;
}

typedef ResourceDocument = ({String documentId, Map<String, dynamic> data});
typedef ResourceDocumentLoader =
    Future<List<ResourceDocument>> Function({
      required String lessonId,
      required bool isActive,
      required String orderByField,
    });

class ResourceRepository {
  ResourceRepository([this._firestore, this._resourceDocumentLoader]);

  final FirebaseFirestore? _firestore;
  final ResourceDocumentLoader? _resourceDocumentLoader;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;

  Future<List<Resource>> loadActiveResourcesForLesson(String lessonId) async {
    try {
      final documents = await _loadDocuments(lessonId);
      return documents
          .map(
            (document) => Resource.fromFirestore(
              documentId: document.documentId,
              data: document.data,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      throw const ResourceRepositoryFailure(
        ResourceRepositoryFailureReason.invalidData,
      );
    } on FirebaseException {
      throw const ResourceRepositoryFailure();
    }
  }

  Future<List<ResourceDocument>> _loadDocuments(String lessonId) async {
    final loader = _resourceDocumentLoader;
    if (loader != null) {
      return loader(lessonId: lessonId, isActive: true, orderByField: 'order');
    }

    final snapshot = await _database
        .collection('resources')
        .where('lessonId', isEqualTo: lessonId)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    return snapshot.docs
        .map((document) => (documentId: document.id, data: document.data()))
        .toList(growable: false);
  }
}
