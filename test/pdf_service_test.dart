import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/models/resource.dart';
import 'package:student_assist/repositories/storage_repository.dart';
import 'package:student_assist/services/pdf_service.dart';
import 'package:student_assist/services/storage_service.dart';

const _approvedPath =
    'student-content/grades/grade-1/subjects/subject-math-g1/'
    'chapters/chapter-math-g1-1/lessons/lesson-math-g1-ch1-1/'
    'resources/resource-pdf-1/lesson-summary.pdf';

void main() {
  test('prepares an authenticated temporary PDF without using url', () async {
    String? downloadedPath;
    final service = PdfService(
      StorageService(
        StorageRepository(
          null,
          (storagePath) async => StorageObjectMetadata(
            fullPath: storagePath,
            contentType: 'application/pdf',
          ),
          (storagePath, destination) async {
            downloadedPath = storagePath;
            await destination.writeAsBytes('%PDF-1.7\n'.codeUnits);
          },
        ),
      ),
      _createTemporaryFolder,
    );

    final source = await service.preparePdf(
      _resource(url: 'https://must-not-be-used.example/summary.pdf'),
    );

    expect(downloadedPath, _approvedPath);
    expect(await source.file.exists(), isTrue);
    expect(source.file.path, isNot(contains('Downloads')));
    final folder = source.file.parent;
    await source.dispose();
    expect(await folder.exists(), isFalse);
  });

  test('rejects an empty storagePath before Storage access', () async {
    var calls = 0;
    final service = PdfService(
      StorageService(
        StorageRepository(null, (_) async {
          calls++;
          return const StorageObjectMetadata(
            fullPath: _approvedPath,
            contentType: 'application/pdf',
          );
        }),
      ),
      _createTemporaryFolder,
    );

    await expectLater(
      service.preparePdf(_resource(storagePath: '')),
      throwsA(
        isA<PdfFailure>().having(
          (error) => error.reason,
          'reason',
          PdfFailureReason.emptyStoragePath,
        ),
      ),
    );
    expect(calls, 0);
  });

  test('rejects Resource types other than exact lowercase pdf', () async {
    final service = PdfService();

    for (final type in ['video', 'PDF', 'Pdf', 'sample-a']) {
      await expectLater(
        service.preparePdf(_resource(type: type)),
        throwsA(
          isA<PdfFailure>().having(
            (error) => error.reason,
            'reason',
            PdfFailureReason.unsupportedType,
          ),
        ),
      );
    }
  });

  test('rejects an invalid Storage path safely', () async {
    final service = PdfService(StorageService(), _createTemporaryFolder);

    await expectLater(
      service.preparePdf(_resource(storagePath: 'https://example.com/a.pdf')),
      throwsA(
        isA<PdfFailure>()
            .having(
              (error) => error.reason,
              'reason',
              PdfFailureReason.invalidStoragePath,
            )
            .having(
              (error) => error.message.contains('https://'),
              'safe message',
              isFalse,
            ),
      ),
    );
  });

  test('rejects non-PDF metadata before writing a file', () async {
    var writes = 0;
    final service = PdfService(
      StorageService(
        StorageRepository(
          null,
          (storagePath) async => StorageObjectMetadata(
            fullPath: storagePath,
            contentType: 'video/mp4',
          ),
          (_, _) async => writes++,
        ),
      ),
      _createTemporaryFolder,
    );

    await expectLater(
      service.preparePdf(_resource()),
      throwsA(
        isA<PdfFailure>().having(
          (error) => error.reason,
          'reason',
          PdfFailureReason.invalidPdf,
        ),
      ),
    );
    expect(writes, 0);
  });

  test(
    'rejects invalid PDF contents and removes the temporary folder',
    () async {
      Directory? folder;
      final service = PdfService(
        StorageService(
          StorageRepository(
            null,
            (storagePath) async => StorageObjectMetadata(
              fullPath: storagePath,
              contentType: 'application/pdf',
            ),
            (_, destination) async {
              await destination.writeAsString('not a PDF');
            },
          ),
        ),
        () async {
          folder = await _createTemporaryFolder();
          return folder!;
        },
      );

      await expectLater(
        service.preparePdf(_resource()),
        throwsA(
          isA<PdfFailure>().having(
            (error) => error.reason,
            'reason',
            PdfFailureReason.invalidPdf,
          ),
        ),
      );
      expect(await folder!.exists(), isFalse);
    },
  );

  test('translates authorization failures without raw details', () async {
    final service = PdfService(
      StorageService(
        StorageRepository(null, (_) async {
          throw const StorageRepositoryFailure(
            StorageRepositoryFailureReason.unauthorized,
          );
        }),
      ),
      _createTemporaryFolder,
    );

    await expectLater(
      service.preparePdf(_resource()),
      throwsA(
        isA<PdfFailure>()
            .having(
              (error) => error.reason,
              'reason',
              PdfFailureReason.unauthorized,
            )
            .having(
              (error) => error.message.contains('Firebase'),
              'safe message',
              isFalse,
            ),
      ),
    );
  });

  test('translates a missing Storage object safely', () async {
    final service = PdfService(
      StorageService(
        StorageRepository(null, (_) async {
          throw const StorageRepositoryFailure(
            StorageRepositoryFailureReason.notFound,
          );
        }),
      ),
      _createTemporaryFolder,
    );

    await expectLater(
      service.preparePdf(_resource()),
      throwsA(
        isA<PdfFailure>()
            .having(
              (error) => error.reason,
              'reason',
              PdfFailureReason.notFound,
            )
            .having(
              (error) => error.message.contains(_approvedPath),
              'does not expose the object path',
              isFalse,
            ),
      ),
    );
  });

  test('removes a partial file after a backend failure', () async {
    Directory? folder;
    final service = PdfService(
      StorageService(
        StorageRepository(
          null,
          (storagePath) async => StorageObjectMetadata(
            fullPath: storagePath,
            contentType: 'application/pdf',
          ),
          (_, destination) async {
            await destination.writeAsBytes('%PDF-'.codeUnits);
            throw const StorageRepositoryFailure(
              StorageRepositoryFailureReason.backend,
            );
          },
        ),
      ),
      () async {
        folder = await _createTemporaryFolder();
        return folder!;
      },
    );

    await expectLater(
      service.preparePdf(_resource()),
      throwsA(
        isA<PdfFailure>().having(
          (error) => error.reason,
          'reason',
          PdfFailureReason.backend,
        ),
      ),
    );
    expect(await folder!.exists(), isFalse);
  });
}

Future<Directory> _createTemporaryFolder() {
  return Directory.systemTemp.createTemp('student_assist_pdf_test_');
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
