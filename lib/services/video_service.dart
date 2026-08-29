import 'dart:io';

import '../models/resource.dart';
import 'storage_service.dart';

typedef TemporaryVideoFolderFactory = Future<Directory> Function();

enum VideoFailureReason {
  unsupportedType,
  emptyStoragePath,
  invalidStoragePath,
  invalidVideo,
  notFound,
  unauthorized,
  backend,
}

class VideoFailure implements Exception {
  const VideoFailure(this.message, this.reason);

  final String message;
  final VideoFailureReason reason;
}

class VideoPlaybackSource {
  VideoPlaybackSource(this.file, this._temporaryFolder);

  VideoPlaybackSource.persistent(this.file) : _temporaryFolder = null;

  final File file;
  final Directory? _temporaryFolder;

  Future<void> dispose() async {
    final temporaryFolder = _temporaryFolder;
    if (temporaryFolder == null) return;
    try {
      if (await temporaryFolder.exists()) {
        await temporaryFolder.delete(recursive: true);
      }
    } on FileSystemException {
      // Temporary cleanup is best-effort and must not surface raw file errors.
    }
  }
}

class VideoService {
  VideoService([this._storageService, this._temporaryFolderFactory]);

  final StorageService? _storageService;
  final TemporaryVideoFolderFactory? _temporaryFolderFactory;
  StorageService? _defaultStorageService;

  StorageService get _storage =>
      _storageService ?? (_defaultStorageService ??= StorageService());

  Future<VideoPlaybackSource> prepareOnlineVideo(Resource resource) async {
    if (resource.type != 'video') {
      throw const VideoFailure(
        'نوع المورد غير مدعوم للتشغيل.',
        VideoFailureReason.unsupportedType,
      );
    }

    if (resource.storagePath.trim().isEmpty) {
      throw const VideoFailure(
        'ملف الفيديو غير متوفر.',
        VideoFailureReason.emptyStoragePath,
      );
    }

    Directory? temporaryFolder;
    try {
      temporaryFolder =
          await (_temporaryFolderFactory?.call() ??
              Directory.systemTemp.createTemp('student_assist_video_'));
      final extension = _safeFileExtension(resource.storagePath);
      final destination = File(
        '${temporaryFolder.path}/video_resource$extension',
      );
      await _storage.downloadVideoToFile(resource.storagePath, destination);
      return VideoPlaybackSource(destination, temporaryFolder);
    } on StorageFailure catch (error) {
      await _deleteTemporaryFolder(temporaryFolder);
      throw _mapStorageFailure(error);
    } catch (_) {
      await _deleteTemporaryFolder(temporaryFolder);
      throw const VideoFailure(
        'تعذر تجهيز الفيديو. حاول مرة أخرى.',
        VideoFailureReason.backend,
      );
    }
  }

  Future<void> _deleteTemporaryFolder(Directory? folder) async {
    if (folder == null) return;
    try {
      if (await folder.exists()) await folder.delete(recursive: true);
    } on FileSystemException {
      // Preserve the safe domain failure if best-effort cleanup also fails.
    }
  }

  String _safeFileExtension(String storagePath) {
    final fileName = storagePath.split('/').last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0) return '.video';

    final extension = fileName.substring(dotIndex).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)
        ? extension
        : '.video';
  }

  VideoFailure _mapStorageFailure(StorageFailure error) {
    return switch (error.reason) {
      StorageFailureReason.emptyStoragePath => const VideoFailure(
        'ملف الفيديو غير متوفر.',
        VideoFailureReason.emptyStoragePath,
      ),
      StorageFailureReason.invalidStoragePath => const VideoFailure(
        'مسار ملف الفيديو غير صالح.',
        VideoFailureReason.invalidStoragePath,
      ),
      StorageFailureReason.invalidMetadata => const VideoFailure(
        'ملف الفيديو غير صالح.',
        VideoFailureReason.invalidVideo,
      ),
      StorageFailureReason.notFound => const VideoFailure(
        'ملف الفيديو غير متوفر.',
        VideoFailureReason.notFound,
      ),
      StorageFailureReason.unauthorized => const VideoFailure(
        'غير مسموح بالوصول إلى هذا الفيديو.',
        VideoFailureReason.unauthorized,
      ),
      StorageFailureReason.backend => const VideoFailure(
        'تعذر تحميل الفيديو. حاول مرة أخرى.',
        VideoFailureReason.backend,
      ),
    };
  }
}
