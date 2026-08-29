import 'dart:io';

import '../models/resource.dart';
import '../utils/pdf_file_validator.dart';
import 'storage_service.dart';

typedef TemporaryPdfFolderFactory = Future<Directory> Function();

enum PdfFailureReason {
  unsupportedType,
  emptyStoragePath,
  invalidStoragePath,
  invalidPdf,
  notFound,
  unauthorized,
  backend,
}

class PdfFailure implements Exception {
  const PdfFailure(this.message, this.reason);

  final String message;
  final PdfFailureReason reason;
}

class PdfViewSource {
  PdfViewSource(this.file, this._temporaryFolder);

  PdfViewSource.persistent(this.file) : _temporaryFolder = null;

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
      // Temporary cleanup is best-effort and never exposes file-system details.
    }
  }
}

class PdfService {
  PdfService([
    this._storageService,
    this._temporaryFolderFactory,
    this._validator = const PdfFileValidator(),
  ]);

  final StorageService? _storageService;
  final TemporaryPdfFolderFactory? _temporaryFolderFactory;
  final PdfFileValidator _validator;
  StorageService? _defaultStorageService;

  StorageService get _storage =>
      _storageService ?? (_defaultStorageService ??= StorageService());

  Future<PdfViewSource> preparePdf(Resource resource) async {
    if (resource.type != 'pdf') {
      throw const PdfFailure(
        'نوع المورد غير مدعوم للعرض.',
        PdfFailureReason.unsupportedType,
      );
    }

    if (resource.storagePath.trim().isEmpty) {
      throw const PdfFailure(
        'ملف PDF غير متوفر.',
        PdfFailureReason.emptyStoragePath,
      );
    }

    Directory? temporaryFolder;
    try {
      temporaryFolder =
          await (_temporaryFolderFactory?.call() ??
              Directory.systemTemp.createTemp('student_assist_pdf_'));
      final destination = File('${temporaryFolder.path}/lesson_resource.pdf');
      await _storage.downloadPdfToFile(resource.storagePath, destination);

      if (!await _validator.isValid(destination)) {
        throw const PdfFailure(
          'ملف PDF غير صالح.',
          PdfFailureReason.invalidPdf,
        );
      }

      return PdfViewSource(destination, temporaryFolder);
    } on StorageFailure catch (error) {
      await _deleteTemporaryFolder(temporaryFolder);
      throw _mapStorageFailure(error);
    } on PdfFailure {
      await _deleteTemporaryFolder(temporaryFolder);
      rethrow;
    } catch (_) {
      await _deleteTemporaryFolder(temporaryFolder);
      throw const PdfFailure(
        'تعذر تجهيز ملف PDF. حاول مرة أخرى.',
        PdfFailureReason.backend,
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

  PdfFailure _mapStorageFailure(StorageFailure error) {
    return switch (error.reason) {
      StorageFailureReason.emptyStoragePath => const PdfFailure(
        'ملف PDF غير متوفر.',
        PdfFailureReason.emptyStoragePath,
      ),
      StorageFailureReason.invalidStoragePath => const PdfFailure(
        'مسار ملف PDF غير صالح.',
        PdfFailureReason.invalidStoragePath,
      ),
      StorageFailureReason.invalidMetadata => const PdfFailure(
        'ملف PDF غير صالح.',
        PdfFailureReason.invalidPdf,
      ),
      StorageFailureReason.notFound => const PdfFailure(
        'ملف PDF غير متوفر.',
        PdfFailureReason.notFound,
      ),
      StorageFailureReason.unauthorized => const PdfFailure(
        'غير مسموح بالوصول إلى هذا الملف.',
        PdfFailureReason.unauthorized,
      ),
      StorageFailureReason.backend => const PdfFailure(
        'تعذر تحميل ملف PDF. حاول مرة أخرى.',
        PdfFailureReason.backend,
      ),
    };
  }
}
