import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/models/resource.dart';
import 'package:student_assist/repositories/storage_repository.dart';
import 'package:student_assist/services/pdf_download_service.dart';
import 'package:student_assist/services/storage_service.dart';

const _approvedPath =
    'student-content/grades/grade-1/subjects/subject-math-g1/'
    'chapters/chapter-math-g1-1/lessons/lesson-math-g1-ch1-1/'
    'resources/resource-pdf-1/lesson-summary.pdf';

void main() {
  late Directory documents;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp(
      'student_assist_documents_test_',
    );
  });

  tearDown(() async {
    if (await documents.exists()) await documents.delete(recursive: true);
  });

  test('downloads an authenticated PDF to the persistent hierarchy', () async {
    var writes = 0;
    final service = _service(
      documents,
      writer: (_, destination) async {
        writes++;
        await destination.writeAsBytes('%PDF-1.7\n'.codeUnits);
      },
    );

    final result = await service.downloadPdf(_resource());

    expect(writes, 1);
    expect(result.wasAlreadyDownloaded, isFalse);
    expect(result.file.path, contains('student_content'));
    expect(result.file.path, contains('${Platform.pathSeparator}pdf'));
    expect(result.file.path, contains('resource-pdf-1'));
    expect(result.file.path, endsWith('lesson-summary.pdf'));
    expect(result.file.path, isNot(contains('Downloads')));
    expect(await result.file.exists(), isTrue);
  });

  test('does not use Resource.url', () async {
    String? requestedPath;
    final service = _service(
      documents,
      writer: (path, destination) async {
        requestedPath = path;
        await destination.writeAsBytes('%PDF-'.codeUnits);
      },
    );

    await service.downloadPdf(
      _resource(url: 'https://must-not-be-used.example/file.pdf'),
    );

    expect(requestedPath, _approvedPath);
  });

  test('returns an existing valid file without another download', () async {
    var writes = 0;
    final service = _service(
      documents,
      writer: (_, destination) async {
        writes++;
        await destination.writeAsBytes('%PDF-'.codeUnits);
      },
    );

    final first = await service.downloadPdf(_resource());
    final second = await service.downloadPdf(_resource());

    expect(writes, 1);
    expect(second.wasAlreadyDownloaded, isTrue);
    expect(second.file.path, first.file.path);
  });

  test('a missing local file triggers a new download', () async {
    var writes = 0;
    final service = _service(
      documents,
      writer: (_, destination) async {
        writes++;
        await destination.writeAsBytes('%PDF-'.codeUnits);
      },
    );

    final first = await service.downloadPdf(_resource());
    await first.file.delete();
    await service.downloadPdf(_resource());

    expect(writes, 2);
  });

  test('a corrupt existing file is replaced safely', () async {
    var writes = 0;
    final service = _service(
      documents,
      writer: (_, destination) async {
        writes++;
        await destination.writeAsBytes('%PDF-'.codeUnits);
      },
    );

    final first = await service.downloadPdf(_resource());
    await first.file.writeAsString('corrupt');
    final replacement = await service.downloadPdf(_resource());

    expect(writes, 2);
    expect(replacement.wasAlreadyDownloaded, isFalse);
    expect(await replacement.file.readAsString(), startsWith('%PDF-'));
  });

  test('duplicate in-flight requests share one Storage download', () async {
    var writes = 0;
    final gate = Completer<void>();
    final writerStarted = Completer<void>();
    final service = _service(
      documents,
      writer: (_, destination) async {
        writes++;
        writerStarted.complete();
        await gate.future;
        await destination.writeAsBytes('%PDF-'.codeUnits);
      },
    );

    final first = service.downloadPdf(_resource());
    final second = service.downloadPdf(_resource());
    await writerStarted.future;
    expect(writes, 1);
    gate.complete();

    final results = await Future.wait([first, second]);
    expect(writes, 1);
    expect(results.first.file.path, results.last.file.path);
  });

  test('rejects non-pdf types before Storage access', () async {
    var writes = 0;
    final service = _service(documents, writer: (_, _) async => writes++);

    await expectLater(
      service.downloadPdf(_resource(type: 'video')),
      throwsA(
        isA<PdfDownloadFailure>().having(
          (error) => error.reason,
          'reason',
          PdfDownloadFailureReason.unsupportedType,
        ),
      ),
    );
    expect(writes, 0);
  });

  test('rejects an empty storagePath before Storage access', () async {
    var writes = 0;
    final service = _service(documents, writer: (_, _) async => writes++);

    await expectLater(
      service.downloadPdf(_resource(storagePath: '')),
      throwsA(
        isA<PdfDownloadFailure>().having(
          (error) => error.reason,
          'reason',
          PdfDownloadFailureReason.emptyStoragePath,
        ),
      ),
    );
    expect(writes, 0);
  });

  test('rejects an invalid Storage path before local lookup', () async {
    final service = _service(documents, writer: (_, _) async {});

    await expectLater(
      service.findDownloadedPdf(
        _resource(storagePath: 'https://example.com/document.pdf'),
      ),
      throwsA(
        isA<PdfDownloadFailure>()
            .having(
              (error) => error.reason,
              'reason',
              PdfDownloadFailureReason.invalidStoragePath,
            )
            .having(
              (error) => error.message.contains('https://'),
              'safe message',
              isFalse,
            ),
      ),
    );
  });

  test('rejects wrong MIME without leaving a persistent file', () async {
    final service = _service(
      documents,
      contentType: 'text/plain',
      writer: (_, destination) => destination.writeAsString('not pdf'),
    );

    await expectLater(
      service.downloadPdf(_resource()),
      throwsA(
        isA<PdfDownloadFailure>().having(
          (error) => error.reason,
          'reason',
          PdfDownloadFailureReason.invalidPdf,
        ),
      ),
    );
    expect(_allFiles(documents), isEmpty);
  });

  test('deletes invalid downloaded content and fails safely', () async {
    final service = _service(
      documents,
      writer: (_, destination) => destination.writeAsString('not a PDF'),
    );

    await expectLater(
      service.downloadPdf(_resource()),
      throwsA(
        isA<PdfDownloadFailure>()
            .having(
              (error) => error.reason,
              'reason',
              PdfDownloadFailureReason.invalidPdf,
            )
            .having(
              (error) => error.message.contains(_approvedPath),
              'safe message',
              isFalse,
            ),
      ),
    );
    expect(_allFiles(documents), isEmpty);
  });

  test('maps Storage failures to a safe download failure', () async {
    final service = PdfDownloadService(
      StorageService(
        StorageRepository(null, (_) async {
          throw const StorageRepositoryFailure(
            StorageRepositoryFailureReason.unauthorized,
          );
        }),
      ),
      () async => documents,
    );

    await expectLater(
      service.downloadPdf(_resource()),
      throwsA(
        isA<PdfDownloadFailure>()
            .having(
              (error) => error.reason,
              'reason',
              PdfDownloadFailureReason.unauthorized,
            )
            .having(
              (error) => error.message.contains('Firebase'),
              'safe message',
              isFalse,
            ),
      ),
    );
  });

  test('maps local directory or capacity failures safely', () async {
    final service = PdfDownloadService(
      StorageService(),
      () async => throw const FileSystemException('device detail'),
    );

    await expectLater(
      service.downloadPdf(_resource()),
      throwsA(
        isA<PdfDownloadFailure>()
            .having(
              (error) => error.reason,
              'reason',
              PdfDownloadFailureReason.localStorage,
            )
            .having(
              (error) => error.message.contains('device detail'),
              'safe message',
              isFalse,
            ),
      ),
    );
  });

  test('a failed attempt can be retried', () async {
    var attempts = 0;
    final service = _service(
      documents,
      writer: (_, destination) async {
        attempts++;
        if (attempts == 1) {
          throw const StorageRepositoryFailure(
            StorageRepositoryFailureReason.backend,
          );
        }
        await destination.writeAsBytes('%PDF-'.codeUnits);
      },
    );

    await expectLater(
      service.downloadPdf(_resource()),
      throwsA(isA<PdfDownloadFailure>()),
    );
    final result = await service.downloadPdf(_resource());

    expect(attempts, 2);
    expect(await result.file.exists(), isTrue);
  });

  test('findDownloadedPdf removes corrupt persistent content', () async {
    final service = _service(
      documents,
      writer: (_, destination) => destination.writeAsBytes('%PDF-'.codeUnits),
    );
    final result = await service.downloadPdf(_resource());
    await result.file.writeAsString('corrupt');

    expect(await service.findDownloadedPdf(_resource()), isNull);
    expect(await result.file.exists(), isFalse);
  });

  test('persistent file remains after lookup and caller use', () async {
    final service = _service(
      documents,
      writer: (_, destination) => destination.writeAsBytes('%PDF-'.codeUnits),
    );
    final result = await service.downloadPdf(_resource());

    final local = await service.findDownloadedPdf(_resource());

    expect(local?.path, result.file.path);
    expect(await result.file.exists(), isTrue);
  });

  test(
    'downloaded files can be removed later without a UI dependency',
    () async {
      final service = _service(
        documents,
        writer: (_, destination) => destination.writeAsBytes('%PDF-'.codeUnits),
      );
      final result = await service.downloadPdf(_resource());

      await service.removeDownloadedPdf(_resource());

      expect(await result.file.exists(), isFalse);
    },
  );
}

PdfDownloadService _service(
  Directory documents, {
  String contentType = 'application/pdf',
  required StorageFileWriter writer,
}) {
  return PdfDownloadService(
    StorageService(
      StorageRepository(
        null,
        (path) async =>
            StorageObjectMetadata(fullPath: path, contentType: contentType),
        writer,
      ),
    ),
    () async => documents,
  );
}

List<FileSystemEntity> _allFiles(Directory root) {
  if (!root.existsSync()) return const [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .toList(growable: false);
}

Resource _resource({
  String type = 'pdf',
  String storagePath = _approvedPath,
  String url = '',
}) {
  return Resource(
    resourceId: 'resource-pdf-1',
    lessonId: 'lesson-math-g1-ch1-1',
    title: 'ملخص الدرس',
    type: type,
    url: url,
    storagePath: storagePath,
    order: 1,
    isActive: true,
    createdAt: DateTime.utc(2026, 8, 27),
  );
}
