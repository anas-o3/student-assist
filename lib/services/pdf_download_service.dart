import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/resource.dart';
import '../utils/pdf_file_validator.dart';
import 'storage_service.dart';

typedef PersistentPdfDirectoryFactory = Future<Directory> Function();

enum PdfDownloadFailureReason {
  unsupportedType,
  emptyStoragePath,
  invalidStoragePath,
  invalidPdf,
  notFound,
  unauthorized,
  localStorage,
  backend,
}

class PdfDownloadFailure implements Exception {
  const PdfDownloadFailure(this.message, this.reason);

  final String message;
  final PdfDownloadFailureReason reason;
}

class PdfDownloadResult {
  const PdfDownloadResult({
    required this.file,
    required this.wasAlreadyDownloaded,
  });

  final File file;
  final bool wasAlreadyDownloaded;
}

class PdfDownloadService {
  PdfDownloadService([
    this._storageService,
    this._persistentDirectoryFactory,
    this._validator = const PdfFileValidator(),
  ]);

  final StorageService? _storageService;
  final PersistentPdfDirectoryFactory? _persistentDirectoryFactory;
  final PdfFileValidator _validator;
  final Map<String, Future<PdfDownloadResult>> _downloadsInProgress = {};
  StorageService? _defaultStorageService;

  StorageService get _storage =>
      _storageService ?? (_defaultStorageService ??= StorageService());

  Future<PdfDownloadResult> downloadPdf(Resource resource) async {
    _validateResource(resource);

    final existingDownload = _downloadsInProgress[resource.resourceId];
    if (existingDownload != null) return existingDownload;

    final download = _downloadPdf(resource);
    _downloadsInProgress[resource.resourceId] = download;
    return download.whenComplete(() {
      if (identical(_downloadsInProgress[resource.resourceId], download)) {
        _downloadsInProgress.remove(resource.resourceId);
      }
    });
  }

  Future<File?> findDownloadedPdf(Resource resource) async {
    _validateResource(resource);

    try {
      final destination = await _persistentFile(resource);
      if (!await destination.exists()) return null;
      if (await _validator.isValid(destination)) return destination;

      await _deleteFile(destination);
      return null;
    } on PdfDownloadFailure {
      rethrow;
    } on FileSystemException {
      throw const PdfDownloadFailure(
        'تعذر الوصول إلى الملف المحفوظ على الجهاز.',
        PdfDownloadFailureReason.localStorage,
      );
    } catch (_) {
      throw const PdfDownloadFailure(
        'تعذر الوصول إلى الملف المحفوظ على الجهاز.',
        PdfDownloadFailureReason.localStorage,
      );
    }
  }

  Future<void> removeDownloadedPdf(Resource resource) async {
    _validateResource(resource);
    try {
      final file = await _persistentFile(resource);
      if (await file.exists()) await file.delete();
    } catch (_) {
      throw const PdfDownloadFailure(
        'تعذر حذف الملف المحفوظ من الجهاز.',
        PdfDownloadFailureReason.localStorage,
      );
    }
  }

  Future<PdfDownloadResult> _downloadPdf(Resource resource) async {
    File? partialFile;
    File? destination;
    try {
      destination = await _persistentFile(resource);
      if (await destination.exists()) {
        if (await _validator.isValid(destination)) {
          return PdfDownloadResult(
            file: destination,
            wasAlreadyDownloaded: true,
          );
        }
        await _deleteFile(destination);
      }

      await destination.parent.create(recursive: true);
      partialFile = File('${destination.path}.part');
      await _deleteFile(partialFile);

      await _storage.downloadPdfToFile(resource.storagePath, partialFile);
      if (!await _validator.isValid(partialFile)) {
        throw const PdfDownloadFailure(
          'ملف PDF الذي تم تنزيله غير صالح.',
          PdfDownloadFailureReason.invalidPdf,
        );
      }

      await partialFile.rename(destination.path);
      return PdfDownloadResult(file: destination, wasAlreadyDownloaded: false);
    } on StorageFailure catch (error) {
      await _deleteFile(partialFile);
      throw _mapStorageFailure(error);
    } on PdfDownloadFailure {
      await _deleteFile(partialFile);
      rethrow;
    } on FileSystemException {
      await _deleteFile(partialFile);
      if (destination != null && !await _validator.isValid(destination)) {
        await _deleteFile(destination);
      }
      throw const PdfDownloadFailure(
        'تعذر حفظ ملف PDF على الجهاز.',
        PdfDownloadFailureReason.localStorage,
      );
    } catch (_) {
      await _deleteFile(partialFile);
      throw const PdfDownloadFailure(
        'تعذر تنزيل ملف PDF. حاول مرة أخرى.',
        PdfDownloadFailureReason.backend,
      );
    }
  }

  Future<File> _persistentFile(Resource resource) async {
    final root =
        await (_persistentDirectoryFactory?.call() ??
            getApplicationDocumentsDirectory());
    final separator = Platform.pathSeparator;
    final resourceFolder = _safePathSegment(resource.resourceId);
    final fileName = _safePdfFileName(resource.storagePath);
    return File(
      '${root.path}${separator}student_content${separator}pdf$separator'
      '$resourceFolder$separator$fileName',
    );
  }

  String _safePathSegment(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty || safe == '.' || safe == '..') return 'resource';
    return safe;
  }

  String _safePdfFileName(String storagePath) {
    final storageName = storagePath.split('/').last;
    final safe = storageName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.toLowerCase().endsWith('.pdf') && safe.length > 4) return safe;
    return 'document.pdf';
  }

  void _validateResource(Resource resource) {
    if (resource.type != 'pdf') {
      throw const PdfDownloadFailure(
        'هذا المورد غير متاح للتنزيل كملف PDF.',
        PdfDownloadFailureReason.unsupportedType,
      );
    }
    if (resource.storagePath.trim().isEmpty) {
      throw const PdfDownloadFailure(
        'ملف PDF غير متوفر للتنزيل.',
        PdfDownloadFailureReason.emptyStoragePath,
      );
    }
    try {
      _storage.validateStoragePath(resource.storagePath);
    } on StorageFailure catch (error) {
      throw _mapStorageFailure(error);
    }
  }

  Future<void> _deleteFile(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Best-effort cleanup preserves the safe primary failure.
    }
  }

  PdfDownloadFailure _mapStorageFailure(StorageFailure error) {
    return switch (error.reason) {
      StorageFailureReason.emptyStoragePath => const PdfDownloadFailure(
        'ملف PDF غير متوفر للتنزيل.',
        PdfDownloadFailureReason.emptyStoragePath,
      ),
      StorageFailureReason.invalidStoragePath => const PdfDownloadFailure(
        'تعذر تنزيل ملف PDF المطلوب.',
        PdfDownloadFailureReason.invalidStoragePath,
      ),
      StorageFailureReason.invalidMetadata => const PdfDownloadFailure(
        'ملف PDF غير صالح.',
        PdfDownloadFailureReason.invalidPdf,
      ),
      StorageFailureReason.notFound => const PdfDownloadFailure(
        'ملف PDF غير متوفر.',
        PdfDownloadFailureReason.notFound,
      ),
      StorageFailureReason.unauthorized => const PdfDownloadFailure(
        'غير مسموح بتنزيل هذا الملف.',
        PdfDownloadFailureReason.unauthorized,
      ),
      StorageFailureReason.backend => const PdfDownloadFailure(
        'تعذر تنزيل ملف PDF. حاول مرة أخرى.',
        PdfDownloadFailureReason.backend,
      ),
    };
  }
}
