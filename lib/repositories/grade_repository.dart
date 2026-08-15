import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/grade.dart';

class GradeRepositoryFailure implements Exception {
  const GradeRepositoryFailure();
}

class GradeRepository {
  GradeRepository([this._firestore]);

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;

  Future<List<Grade>> loadActiveGrades() async {
    try {
      final snapshot = await _database
          .collection('grades')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      return snapshot.docs
          .map(
            (document) => Grade.fromFirestore(
              documentId: document.id,
              data: document.data(),
            ),
          )
          .toList(growable: false);
    } on FirebaseException {
      throw const GradeRepositoryFailure();
    } on FormatException {
      throw const GradeRepositoryFailure();
    }
  }
}
