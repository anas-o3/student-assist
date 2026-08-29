import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/resource.dart';
import '../utils/video_file_validator.dart';
import 'storage_service.dart';

typedef PersistentVideoDirectoryFactory = Future<Directory> Function();

enum VideoDownloadFailureReason {
  unsupportedType,
  emptyStoragePath,
  invalidStoragePath,
  invalidVideo,
  notFound,
  unauthorized,
  localStorage,
  backend,
}

class VideoDownloadFailure implements Exception {
  const VideoDownloadFailure(this.message, this.reason);

  final String message;
  final VideoDownloadFailureReason reason;
}

class VideoDownloadResult {
  const VideoDownloadResult({
    required this.file,
    required this.wasAlreadyDownloaded,
  });

  final File file;
  final bool wasAlreadyDownloaded;
}

class VideoDownloadService {
  VideoDownloadService([
    this._storageService,
    this._persistentDirectoryFactory,
    this._validator = const VideoFileValidator(),
  ]);

  final StorageService? _storageService;
  final PersistentVideoDirectoryFactory? _persistentDirectoryFactory;
  final VideoFileValidator _validator;
  final Map<String, Future<VideoDownloadResult>> _downloadsInProgress = {};
  StorageService? _defaultStorageService;

  StorageService get _storage =>
      _storageService ?? (_defaultStorageService ??= StorageService());

  Future<VideoDownloadResult> downloadVideo(Resource resource) async {
    _validateResource(resource);

    final existingDownload = _downloadsInProgress[resource.resourceId];
    if (existingDownload != null) return existingDownload;

    final download = _downloadVideo(resource);
    _downloadsInProgress[resource.resourceId] = download;
    return download.whenComplete(() {
      if (identical(_downloadsInProgress[resource.resourceId], download)) {
        _downloadsInProgress.remove(resource.resourceId);
      }
    });
  }

  Future<File?> findDownloadedVideo(Resource resource) async {
    _validateResource(resource);

    try {
      final destination = await _persistentFile(resource);
      if (!await destination.exists()) return null;
      if (await _validator.isValid(destination)) return destination;

      await _deleteFile(destination);
      return null;
    } on VideoDownloadFailure {
      rethrow;
    } on FileSystemException {
      throw const VideoDownloadFailure(
        'تعذر الوصول إلى الفيديو المحفوظ على الجهاز.',
        VideoDownloadFailureReason.localStorage,
      );
    } catch (_) {
      throw const VideoDownloadFailure(
        'تعذر الوصول إلى الفيديو المحفوظ على الجهاز.',
        VideoDownloadFailureReason.localStorage,
      );
    }
  }

  Future<void> removeDownloadedVideo(Resource resource) async {
    _validateResource(resource);
    try {
      final file = await _persistentFile(resource);
      if (await file.exists()) await file.delete();
    } catch (_) {
      throw const VideoDownloadFailure(
        'تعذر حذف الفيديو المحفوظ من الجهاز.',
        VideoDownloadFailureReason.localStorage,
      );
    }
  }

  Future<VideoDownloadResult> _downloadVideo(Resource resource) async {
    File? partialFile;
    File? destination;
    try {
      destination = await _persistentFile(resource);
      if (await destination.exists()) {
        if (await _validator.isValid(destination)) {
          return VideoDownloadResult(
            file: destination,
            wasAlreadyDownloaded: true,
          );
        }
        await _deleteFile(destination);
      }

      await destination.parent.create(recursive: true);
      partialFile = File('${destination.path}.part');
      await _deleteFile(partialFile);

      await _storage.downloadVideoToFile(resource.storagePath, partialFile);
      if (!await _validator.isValid(partialFile)) {
        throw const VideoDownloadFailure(
          'ملف الفيديو الذي تم تنزيله غير صالح.',
          VideoDownloadFailureReason.invalidVideo,
        );
      }

      await partialFile.rename(destination.path);
      return VideoDownloadResult(
        file: destination,
        wasAlreadyDownloaded: false,
      );
    } on StorageFailure catch (error) {
      await _deleteFile(partialFile);
      throw _mapStorageFailure(error);
    } on VideoDownloadFailure {
      await _deleteFile(partialFile);
      rethrow;
    } on FileSystemException {
      await _deleteFile(partialFile);
      if (destination != null && !await _validator.isValid(destination)) {
        await _deleteFile(destination);
      }
      throw const VideoDownloadFailure(
        'تعذر حفظ ملف الفيديو على الجهاز.',
        VideoDownloadFailureReason.localStorage,
      );
    } catch (_) {
      await _deleteFile(partialFile);
      throw const VideoDownloadFailure(
        'تعذر تنزيل ملف الفيديو. حاول مرة أخرى.',
        VideoDownloadFailureReason.backend,
      );
    }
  }

  Future<File> _persistentFile(Resource resource) async {
    final root =
        await (_persistentDirectoryFactory?.call() ??
            getApplicationDocumentsDirectory());
    final separator = Platform.pathSeparator;
    final resourceFolder = _safePathSegment(resource.resourceId);
    final fileName = _safeVideoFileName(resource.storagePath);
    return File(
      '${root.path}${separator}student_content${separator}video$separator'
      '$resourceFolder$separator$fileName',
    );
  }

  String _safePathSegment(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty || safe == '.' || safe == '..') return 'resource';
    return safe;
  }

  String _safeVideoFileName(String storagePath) {
    final storageName = storagePath.split('/').last;
    final safe = storageName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dotIndex = safe.lastIndexOf('.');
    if (dotIndex > 0 &&
        RegExp(r'^\.[A-Za-z0-9]{1,8}$').hasMatch(safe.substring(dotIndex))) {
      return safe;
    }
    return 'video_resource.video';
  }

  void _validateResource(Resource resource) {
    if (resource.type != 'video') {
      throw const VideoDownloadFailure(
        'هذا المورد غير متاح للتنزيل كفيديو.',
        VideoDownloadFailureReason.unsupportedType,
      );
    }
    if (resource.storagePath.trim().isEmpty) {
      throw const VideoDownloadFailure(
        'ملف الفيديو غير متوفر للتنزيل.',
        VideoDownloadFailureReason.emptyStoragePath,
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

  VideoDownloadFailure _mapStorageFailure(StorageFailure error) {
    return switch (error.reason) {
      StorageFailureReason.emptyStoragePath => const VideoDownloadFailure(
        'ملف الفيديو غير متوفر للتنزيل.',
        VideoDownloadFailureReason.emptyStoragePath,
      ),
      StorageFailureReason.invalidStoragePath => const VideoDownloadFailure(
        'تعذر تنزيل ملف الفيديو المطلوب.',
        VideoDownloadFailureReason.invalidStoragePath,
      ),
      StorageFailureReason.invalidMetadata => const VideoDownloadFailure(
        'ملف الفيديو غير صالح.',
        VideoDownloadFailureReason.invalidVideo,
      ),
      StorageFailureReason.notFound => const VideoDownloadFailure(
        'ملف الفيديو غير متوفر.',
        VideoDownloadFailureReason.notFound,
      ),
      StorageFailureReason.unauthorized => const VideoDownloadFailure(
        'غير مسموح بتنزيل هذا الفيديو.',
        VideoDownloadFailureReason.unauthorized,
      ),
      StorageFailureReason.backend => const VideoDownloadFailure(
        'تعذر تنزيل ملف الفيديو. حاول مرة أخرى.',
        VideoDownloadFailureReason.backend,
      ),
    };
  }
}
