import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

enum UserRepositoryFailureReason { missingProfile, invalidData, backend }

class UserRepositoryFailure implements Exception {
  const UserRepositoryFailure([
    this.reason = UserRepositoryFailureReason.backend,
  ]);

  final UserRepositoryFailureReason reason;
}

typedef UserDocumentLoader = Future<Map<String, dynamic>?> Function(String uid);

class UserRepository {
  UserRepository([this._firestore, this._userDocumentLoader]);

  final FirebaseFirestore? _firestore;
  final UserDocumentLoader? _userDocumentLoader;

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;

  Future<UserProfile> getUser(String uid) async {
    try {
      final data = await _loadUserDocument(uid);
      if (data == null) {
        throw const UserRepositoryFailure(
          UserRepositoryFailureReason.missingProfile,
        );
      }

      return profileFromFirestore(documentId: uid, data: data);
    } on UserRepositoryFailure {
      rethrow;
    } on FormatException {
      throw const UserRepositoryFailure(
        UserRepositoryFailureReason.invalidData,
      );
    } on FirebaseException {
      throw const UserRepositoryFailure();
    }
  }

  Future<Map<String, dynamic>?> _loadUserDocument(String uid) async {
    final loader = _userDocumentLoader;
    if (loader != null) return loader(uid);

    final document = await _database.collection('users').doc(uid).get();
    return document.data();
  }

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

  Future<void> updateGradeId({
    required String uid,
    required String gradeId,
  }) async {
    try {
      await _database
          .collection('users')
          .doc(uid)
          .update(gradeSelectionData(gradeId));
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

  static Map<String, Object> gradeSelectionData(String gradeId) {
    return {'gradeId': gradeId};
  }

  static UserProfile profileFromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final createdAt = data['createdAt'];
    if (createdAt is! Timestamp) {
      throw const FormatException('Invalid user profile timestamp.');
    }

    return UserProfile.fromFirestore(
      documentId: documentId,
      data: data,
      createdAt: createdAt.toDate().toUtc(),
    );
  }
}
