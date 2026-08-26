import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

enum StorageRepositoryFailureReason {
  invalidMetadata,
  notFound,
  unauthorized,
  backend,
}

class StorageRepositoryFailure implements Exception {
  const StorageRepositoryFailure(this.reason);

  final StorageRepositoryFailureReason reason;
}

class StorageObjectMetadata {
  const StorageObjectMetadata({
    required this.fullPath,
    required this.contentType,
  });

  final String fullPath;
  final String? contentType;
}

typedef StorageMetadataLoader =
    Future<StorageObjectMetadata> Function(String storagePath);
typedef StorageFileWriter =
    Future<void> Function(String storagePath, File destination);

class StorageRepository {
  StorageRepository([this._storage, this._metadataLoader, this._fileWriter]);

  final FirebaseStorage? _storage;
  final StorageMetadataLoader? _metadataLoader;
  final StorageFileWriter? _fileWriter;

  FirebaseStorage get _firebaseStorage => _storage ?? FirebaseStorage.instance;

  Future<StorageObjectMetadata> loadObjectMetadata(String storagePath) async {
    try {
      final loader = _metadataLoader;
      final StorageObjectMetadata metadata;
      if (loader != null) {
        metadata = await loader(storagePath);
      } else {
        // storagePath is an object path only. URL-based references are
        // intentionally unsupported by the approved Storage contract.
        final reference = _firebaseStorage.ref(storagePath);
        final firebaseMetadata = await reference.getMetadata();
        metadata = StorageObjectMetadata(
          fullPath: firebaseMetadata.fullPath,
          contentType: firebaseMetadata.contentType,
        );
      }

      if (metadata.fullPath != storagePath) {
        throw const FormatException('Unexpected Storage object path.');
      }

      return metadata;
    } on FormatException {
      throw const StorageRepositoryFailure(
        StorageRepositoryFailureReason.invalidMetadata,
      );
    } on FirebaseException catch (error) {
      throw StorageRepositoryFailure(_mapFirebaseFailure(error.code));
    }
  }

  Future<void> writeObjectToFile(String storagePath, File destination) async {
    try {
      final writer = _fileWriter;
      if (writer != null) {
        await writer(storagePath, destination);
      } else {
        // Authenticated SDK access is intentional. Public download URLs and
        // persisted download tokens are not part of the approved contract.
        await _firebaseStorage.ref(storagePath).writeToFile(destination);
      }
    } on FirebaseException catch (error) {
      throw StorageRepositoryFailure(_mapFirebaseFailure(error.code));
    }
  }

  StorageRepositoryFailureReason _mapFirebaseFailure(String code) {
    return switch (code) {
      'object-not-found' => StorageRepositoryFailureReason.notFound,
      'unauthenticated' ||
      'unauthorized' => StorageRepositoryFailureReason.unauthorized,
      _ => StorageRepositoryFailureReason.backend,
    };
  }
}
