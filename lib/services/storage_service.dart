import 'dart:io';

import '../repositories/storage_repository.dart';

enum StorageFailureReason {
  emptyStoragePath,
  invalidStoragePath,
  invalidMetadata,
  notFound,
  unauthorized,
  backend,
}

class StorageFailure implements Exception {
  const StorageFailure(this.message, this.reason);

  final String message;
  final StorageFailureReason reason;
}

class StorageService {
  StorageService([this._storageRepository]);

  static final RegExp _approvedStoragePath = RegExp(
    r'^student-content/grades/[^/]+/subjects/[^/]+/chapters/[^/]+/'
    r'lessons/[^/]+/resources/[^/]+/[^/]+$',
  );

  final StorageRepository? _storageRepository;
  StorageRepository? _defaultStorageRepository;

  StorageRepository get _storage =>
      _storageRepository ?? (_defaultStorageRepository ??= StorageRepository());

  Future<StorageObjectMetadata> loadObjectMetadata(String storagePath) async {
    validateStoragePath(storagePath);

    try {
      return await _storage.loadObjectMetadata(storagePath);
    } on StorageRepositoryFailure catch (error) {
      throw _mapRepositoryFailure(error);
    }
  }

  Future<StorageObjectMetadata> downloadVideoToFile(
    String storagePath,
    File destination,
  ) async {
    validateStoragePath(storagePath);

    try {
      final metadata = await _storage.loadObjectMetadata(storagePath);
      if (metadata.contentType?.startsWith('video/') != true) {
        throw const StorageFailure(
          'ملف الفيديو غير صالح.',
          StorageFailureReason.invalidMetadata,
        );
      }

      await _storage.writeObjectToFile(storagePath, destination);
      return metadata;
    } on StorageRepositoryFailure catch (error) {
      throw _mapRepositoryFailure(error);
    }
  }

  Future<StorageObjectMetadata> downloadPdfToFile(
    String storagePath,
    File destination,
  ) async {
    validateStoragePath(storagePath);

    try {
      final metadata = await _storage.loadObjectMetadata(storagePath);
      if (metadata.contentType != 'application/pdf') {
        throw const StorageFailure(
          'ملف PDF غير صالح.',
          StorageFailureReason.invalidMetadata,
        );
      }

      await _storage.writeObjectToFile(storagePath, destination);
      return metadata;
    } on StorageRepositoryFailure catch (error) {
      throw _mapRepositoryFailure(error);
    }
  }

  void validateStoragePath(String storagePath) {
    if (storagePath.trim().isEmpty) {
      throw const StorageFailure(
        'تعذر تحديد ملف المورد.',
        StorageFailureReason.emptyStoragePath,
      );
    }

    if (storagePath != storagePath.trim() ||
        !_approvedStoragePath.hasMatch(storagePath)) {
      throw const StorageFailure(
        'مسار ملف المورد غير صالح.',
        StorageFailureReason.invalidStoragePath,
      );
    }
  }

  StorageFailure _mapRepositoryFailure(StorageRepositoryFailure error) {
    return switch (error.reason) {
      StorageRepositoryFailureReason.invalidMetadata => const StorageFailure(
        'بيانات ملف المورد غير صالحة.',
        StorageFailureReason.invalidMetadata,
      ),
      StorageRepositoryFailureReason.notFound => const StorageFailure(
        'ملف المورد غير متوفر.',
        StorageFailureReason.notFound,
      ),
      StorageRepositoryFailureReason.unauthorized => const StorageFailure(
        'غير مسموح بالوصول إلى ملف المورد.',
        StorageFailureReason.unauthorized,
      ),
      StorageRepositoryFailureReason.backend => const StorageFailure(
        'تعذر الوصول إلى ملف المورد. حاول مرة أخرى.',
        StorageFailureReason.backend,
      ),
    };
  }
}
