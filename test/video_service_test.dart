import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/models/resource.dart';
import 'package:student_assist/repositories/storage_repository.dart';
import 'package:student_assist/services/storage_service.dart';
import 'package:student_assist/services/video_service.dart';

const _approvedPath =
    'student-content/grades/grade-1/subjects/subject-math-g1/'
    'chapters/chapter-math-g1-1/lessons/lesson-math-g1-ch1-1/'
    'resources/resource-video-1/lesson-video.mp4';

void main() {
  test('prepares an authenticated temporary video without using url', () async {
    String? downloadedPath;
    final service = VideoService(
      StorageService(
        StorageRepository(
          null,
          (storagePath) async => StorageObjectMetadata(
            fullPath: storagePath,
            contentType: 'video/mp4',
          ),
          (storagePath, destination) async {
            downloadedPath = storagePath;
            await destination.writeAsBytes(const [0, 1, 2]);
          },
        ),
      ),
      _createTemporaryFolder,
    );

    final source = await service.prepareOnlineVideo(
      _resource(url: 'https://must-not-be-used.example/video.mp4'),
    );

    expect(downloadedPath, _approvedPath);
    expect(await source.file.exists(), isTrue);
    final folder = source.file.parent;
    await source.dispose();
    expect(await folder.exists(), isFalse);
  });

  test('rejects an empty storagePath before Storage access', () async {
    var calls = 0;
    final service = VideoService(
      StorageService(
        StorageRepository(null, (_) async {
          calls++;
          return const StorageObjectMetadata(
            fullPath: _approvedPath,
            contentType: 'video/mp4',
          );
        }),
      ),
      _createTemporaryFolder,
    );

    await expectLater(
      service.prepareOnlineVideo(_resource(storagePath: '')),
      throwsA(
        isA<VideoFailure>().having(
          (error) => error.reason,
          'reason',
          VideoFailureReason.emptyStoragePath,
        ),
      ),
    );
    expect(calls, 0);
  });

  test('rejects Resource types other than exact lowercase video', () async {
    final service = VideoService();

    for (final type in ['pdf', 'VIDEO', 'sample-a']) {
      await expectLater(
        service.prepareOnlineVideo(_resource(type: type)),
        throwsA(
          isA<VideoFailure>().having(
            (error) => error.reason,
            'reason',
            VideoFailureReason.unsupportedType,
          ),
        ),
      );
    }
  });

  test('translates Storage failures without exposing raw details', () async {
    final service = VideoService(
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
      service.prepareOnlineVideo(_resource()),
      throwsA(
        isA<VideoFailure>()
            .having(
              (error) => error.reason,
              'reason',
              VideoFailureReason.unauthorized,
            )
            .having(
              (error) => error.message.contains('Firebase'),
              'safe message',
              isFalse,
            ),
      ),
    );
  });

  test(
    'removes a partial temporary file after Storage download failure',
    () async {
      Directory? createdFolder;
      final service = VideoService(
        StorageService(
          StorageRepository(
            null,
            (storagePath) async => StorageObjectMetadata(
              fullPath: storagePath,
              contentType: 'video/mp4',
            ),
            (_, destination) async {
              await destination.writeAsBytes(const [0, 1]);
              throw FirebaseException(
                plugin: 'firebase_storage',
                code: 'unauthorized',
                message: 'raw Firebase detail',
              );
            },
          ),
        ),
        () async {
          createdFolder = await _createTemporaryFolder();
          return createdFolder!;
        },
      );

      await expectLater(
        service.prepareOnlineVideo(_resource()),
        throwsA(
          isA<VideoFailure>().having(
            (error) => error.reason,
            'reason',
            VideoFailureReason.unauthorized,
          ),
        ),
      );

      expect(createdFolder, isNotNull);
      expect(await createdFolder!.exists(), isFalse);
    },
  );
}

Future<Directory> _createTemporaryFolder() async {
  final root = Directory('tmp/video_service_tests');
  await root.create(recursive: true);
  return root.createTemp('case_');
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
    createdAt: DateTime.utc(2026, 8, 24),
  );
}
