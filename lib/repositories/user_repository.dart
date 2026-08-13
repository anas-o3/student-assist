import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepositoryFailure implements Exception {
  const UserRepositoryFailure();
}

class UserRepository {
  UserRepository([this._firestore]);

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;

  Future<void> createStudentProfile({
    required String uid,
    required String name,
    required String email,
  }) async {
    try {
      // The Authentication uid is used as the document id to keep the
      // approved Authentication-to-user relationship direct.
      await _database
          .collection('users')
          .doc(uid)
          .set(studentProfileData(uid: uid, name: name, email: email));
    } on FirebaseException {
      throw const UserRepositoryFailure();
    }
  }

  static Map<String, Object?> studentProfileData({
    required String uid,
    required String name,
    required String email,
  }) {
    return {
      'userId': uid,
      'name': name,
      'email': email,
      // Only Student has public registration in the approved Use Cases.
      'role': 'student',
      // The Class Diagram defines gradeId as nullable until grade selection.
      'gradeId': null,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
