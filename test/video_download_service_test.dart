import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/models/resource.dart';
import 'package:student_assist/repositories/storage_repository.dart';
import 'package:student_assist/services/storage_service.dart';
import 'package:student_assist/services/video_download_service.dart';

const _approvedPath =
    'student-content/grades/grade-1/subjects/subject-math-g1/'
    'chapters/chapter-math-g1-1/lessons/lesson-math-g1-ch1-1/'
    'resources/resource-video-1/lesson-video.mp4';

void main() {
  late Directory documents;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp(
      'student_assist_video_documents_test_',
    );
  });

  tearDown(() async {
    if (await documents.exists()) await documents.delete(recursive: true);
  });

  test('downloads a video to the persistent app-private hierarchy', () async {
    var writes = 0;
    final service = _service(
      documents,
      writer: (_, destination) async {
        writes++;
        await destination.writeAsBytes(const [0, 1, 2, 3]);
      },
    );

    final result = await service.downloadVideo(_resource());

    expect(writes, 1);
    expect(result.wasAlreadyDownloaded, isFalse);
    expect(result.file.path, contains('student_content'));
    expect(result.file.path, contains('${Platform.pathSeparator}video'));
    expect(result.file.path, contains('resource-video-1'));
    expect(result.file.path, endsWith('lesson-video.mp4'));
    expect(result.file.path, isNot(contains('Downloads')));
    expect(await result.file.length(), 4);
  });

  test('uses storagePath and never Resource.url', () async {
    String? requestedPath;
    final service = _service(
      documents,
      writer: (path, destination) async {
        requestedPath = path;
        await destination.writeAsBytes(const [1]);
      },
    );

    await service.downloadVideo(
      _resource(url: 'https://must-not-be-used.example/video.mp4'),
    );

    expect(requestedPath, _approvedPath);
  });

  test('reuses an existing valid video without another download', () async {
    var writes = 0;
    final service = _service(
      documents,
      writer: (_, destination) async {
        writes++;
        await destination.writeAsBytes(const [1, 2]);
      },
    );

    final first = await service.downloadVideo(_resource());
    final second = await service.downloadVideo(_resource());

    expect(writes, 1);
    expect(second.wasAlreadyDownloaded, isTrue);
    expect(second.file.path, first.file.path);
  });

  test('a missing persistent file triggers a fresh download', () async {
    var writes = 0;
    final service = _service(
      documents,
      writer: (_, destination) async {
        writes++;
        await destination.writeAsBytes(const [1]);
      },
    );

    final first = await service.downloadVideo(_resource());
    await first.file.delete();
    await service.downloadVideo(_resource());

    expect(writes, 2);
  });

  test('a zero-byte persistent file is replaced safely', () async {
    var writes = 0;
    final service = _service(
      documents,
      writer: (_, destination) async {
        writes++;
        await destination.writeAsBytes(const [9]);
      },
    );

    final first = await service.downloadVideo(_resource());
    await first.file.writeAsBytes(const []);
    final replacement = await service.downloadVideo(_resource());

    expect(writes, 2);
    expect(replacement.wasAlreadyDownloaded, isFalse);
    expect(await replacement.file.length(), 1);
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
        await destination.writeAsBytes(const [1]);
      },
    );

    final first = service.downloadVideo(_resource());
    final second = service.downloadVideo(_resource());
    await writerStarted.future;
    expect(writes, 1);
    gate.complete();

    final results = await Future.wait([first, second]);
    expect(writes, 1);
    expect(results.first.file.path, results.last.file.path);
  });

  test('rejects non-video Resource types before Storage access', () async {
    var writes = 0;
    final service = _service(documents, writer: (_, _) async => writes++);

    await expectLater(
      service.downloadVideo(_resource(type: 'pdf')),
      throwsA(
        isA<VideoDownloadFailure>().having(
          (error) => error.reason,
          'reason',
          VideoDownloadFailureReason.unsupportedType,
        ),
      ),
    );
    expect(writes, 0);
  });

  test('rejects an empty storagePath before Storage access', () async {
    var writes = 0;
    final service = _service(documents, writer: (_, _) async => writes++);

    await expectLater(
      service.downloadVideo(_resource(storagePath: '')),
      throwsA(
        isA<VideoDownloadFailure>().having(
          (error) => error.reason,
          'reason',
          VideoDownloadFailureReason.emptyStoragePath,
        ),
      ),
    );
    expect(writes, 0);
  });

  test('rejects a URL storagePath without exposing it', () async {
    final service = _service(documents, writer: (_, _) async {});

    await expectLater(
      service.downloadVideo(
        _resource(storagePath: 'https://example.com/video.mp4'),
      ),
      throwsA(
        isA<VideoDownloadFailure>()
            .having(
              (error) => error.reason,
              'reason',
              VideoDownloadFailureReason.invalidStoragePath,
            )
            .having(
              (error) => error.message.contains('https://'),
              'safe message',
              isFalse,
            ),
      ),
    );
  });

  test('rejects a non-video MIME without writing a local file', () async {
    final service = _service(
      documents,
      contentType: 'application/pdf',
      writer: (_, destination) => destination.writeAsBytes(const [1]),
    );

    await expectLater(
      service.downloadVideo(_resource()),
      throwsA(
        isA<VideoDownloadFailure>().having(
          (error) => error.reason,
          'reason',
          VideoDownloadFailureReason.invalidVideo,
        ),
      ),
    );
    expect(_allFiles(documents), isEmpty);
  });

  test('deletes a zero-byte partial download and fails safely', () async {
    final service = _service(
      documents,
      writer: (_, destination) => destination.writeAsBytes(const []),
    );

    await expectLater(
      service.downloadVideo(_resource()),
      throwsA(
        isA<VideoDownloadFailure>()
            .having(
              (error) => error.reason,
              'reason',
              VideoDownloadFailureReason.invalidVideo,
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

  test('cleans a partial file after a Storage write failure', () async {
    final service = _service(
      documents,
      writer: (_, destination) async {
        await destination.writeAsBytes(const [1, 2]);
        throw const StorageRepositoryFailure(
          StorageRepositoryFailureReason.backend,
        );
      },
    );

    await expectLater(
      service.downloadVideo(_resource()),
      throwsA(
        isA<VideoDownloadFailure>().having(
          (error) => error.reason,
          'reason',
          VideoDownloadFailureReason.backend,
        ),
      ),
    );
    expect(_allFiles(documents), isEmpty);
  });

  test('maps Storage authorization failures to a safe Arabic error', () async {
    final service = VideoDownloadService(
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
      service.downloadVideo(_resource()),
      throwsA(
        isA<VideoDownloadFailure>()
            .having(
              (error) => error.reason,
              'reason',
              VideoDownloadFailureReason.unauthorized,
            )
            .having(
              (error) => error.message.contains('Firebase'),
              'safe message',
              isFalse,
            ),
      ),
    );
  });

  test('maps local directory failures without raw device details', () async {
    final service = VideoDownloadService(
      StorageService(),
      () async => throw const FileSystemException('private device detail'),
    );

    await expectLater(
      service.downloadVideo(_resource()),
      throwsA(
        isA<VideoDownloadFailure>()
            .having(
              (error) => error.reason,
              'reason',
              VideoDownloadFailureReason.localStorage,
            )
            .having(
              (error) => error.message.contains('device detail'),
              'safe message',
              isFalse,
            ),
      ),
    );
  });

  test('a failed download can be retried', () async {
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
        await destination.writeAsBytes(const [1]);
      },
    );

    await expectLater(
      service.downloadVideo(_resource()),
      throwsA(isA<VideoDownloadFailure>()),
    );
    final result = await service.downloadVideo(_resource());

    expect(attempts, 2);
    expect(await result.file.exists(), isTrue);
  });

  test('findDownloadedVideo removes an invalid local copy', () async {
    final service = _service(
      documents,
      writer: (_, destination) => destination.writeAsBytes(const [1]),
    );
    final result = await service.downloadVideo(_resource());
    await result.file.writeAsBytes(const []);

    expect(await service.findDownloadedVideo(_resource()), isNull);
    expect(await result.file.exists(), isFalse);
  });

  test('persistent video remains after lookup and caller use', () async {
    final service = _service(
      documents,
      writer: (_, destination) => destination.writeAsBytes(const [1]),
    );
    final result = await service.downloadVideo(_resource());

    final local = await service.findDownloadedVideo(_resource());

    expect(local?.path, result.file.path);
    expect(await result.file.exists(), isTrue);
  });

  test(
    'downloaded video can be removed later without a UI dependency',
    () async {
      final service = _service(
        documents,
        writer: (_, destination) => destination.writeAsBytes(const [1]),
      );
      final result = await service.downloadVideo(_resource());

      await service.removeDownloadedVideo(_resource());

      expect(await result.file.exists(), isFalse);
    },
  );
}

VideoDownloadService _service(
  Directory documents, {
  String contentType = 'video/mp4',
  required StorageFileWriter writer,
}) {
  return VideoDownloadService(
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
  String type = 'video',
  String storagePath = _approvedPath,
  String url = '',
}) {
  return Resource(
    resourceId: 'resource-video-1',
    lessonId: 'lesson-math-g1-ch1-1',
    title: 'شرح مرئي',
    type: type,
    url: url,
    storagePath: storagePath,
    order: 1,
    isActive: true,
    createdAt: DateTime.utc(2026, 8, 29),
  );
}
