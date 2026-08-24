import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/repositories/storage_repository.dart';
import 'package:student_assist/services/storage_service.dart';

const _approvedPath =
    'student-content/grades/grade-1/subjects/subject-math-g1/'
    'chapters/chapter-math-g1-1/lessons/lesson-math-g1-ch1-1/'
    'resources/resource-video-1/lesson-video.mp4';

void main() {
  group('StorageRepository', () {
    test('loads metadata through the injected Storage boundary', () async {
      String? receivedPath;
      final repository = StorageRepository(null, (storagePath) async {
        receivedPath = storagePath;
        return const StorageObjectMetadata(
          fullPath: _approvedPath,
          contentType: 'video/mp4',
        );
      });

      final metadata = await repository.loadObjectMetadata(_approvedPath);

      expect(receivedPath, _approvedPath);
      expect(metadata.fullPath, _approvedPath);
      expect(metadata.contentType, 'video/mp4');
    });

    test('rejects metadata returned for a different object path', () async {
      final repository = StorageRepository(
        null,
        (_) async => const StorageObjectMetadata(
          fullPath: 'student-content/unexpected.pdf',
          contentType: 'application/pdf',
        ),
      );

      await expectLater(
        repository.loadObjectMetadata(_approvedPath),
        throwsA(
          isA<StorageRepositoryFailure>().having(
            (error) => error.reason,
            'reason',
            StorageRepositoryFailureReason.invalidMetadata,
          ),
        ),
      );
    });

    test(
      'maps Firebase object-not-found without exposing its message',
      () async {
        final repository = StorageRepository(null, (_) async {
          throw FirebaseException(
            plugin: 'firebase_storage',
            code: 'object-not-found',
            message: 'raw backend details',
          );
        });

        await expectLater(
          repository.loadObjectMetadata(_approvedPath),
          throwsA(
            isA<StorageRepositoryFailure>().having(
              (error) => error.reason,
              'reason',
              StorageRepositoryFailureReason.notFound,
            ),
          ),
        );
      },
    );

    test('maps Firebase authorization failures safely', () async {
      final repository = StorageRepository(null, (_) async {
        throw FirebaseException(
          plugin: 'firebase_storage',
          code: 'unauthorized',
          message: 'raw authorization details',
        );
      });

      await expectLater(
        repository.loadObjectMetadata(_approvedPath),
        throwsA(
          isA<StorageRepositoryFailure>().having(
            (error) => error.reason,
            'reason',
            StorageRepositoryFailureReason.unauthorized,
          ),
        ),
      );
    });
  });

  group('StorageService', () {
    test('delegates an exact approved object path', () async {
      var calls = 0;
      final service = StorageService(
        StorageRepository(null, (storagePath) async {
          calls++;
          return StorageObjectMetadata(
            fullPath: storagePath,
            contentType: 'video/mp4',
          );
        }),
      );

      final metadata = await service.loadObjectMetadata(_approvedPath);

      expect(calls, 1);
      expect(metadata.fullPath, _approvedPath);
    });

    test('rejects an empty path before repository access', () async {
      var calls = 0;
      final service = StorageService(
        StorageRepository(null, (_) async {
          calls++;
          return const StorageObjectMetadata(
            fullPath: _approvedPath,
            contentType: 'video/mp4',
          );
        }),
      );

      await expectLater(
        service.loadObjectMetadata('   '),
        throwsA(
          isA<StorageFailure>().having(
            (error) => error.reason,
            'reason',
            StorageFailureReason.emptyStoragePath,
          ),
        ),
      );
      expect(calls, 0);
    });

    test('rejects URLs and paths outside the approved contract', () async {
      final service = StorageService(
        StorageRepository(
          null,
          (_) async => const StorageObjectMetadata(
            fullPath: _approvedPath,
            contentType: 'video/mp4',
          ),
        ),
      );

      for (final invalidPath in <String>[
        'https://example.com/video.mp4',
        'gs://bucket/video.mp4',
        '/$_approvedPath',
        '$_approvedPath ',
        'student-content/grades/grade-1/resources/video.mp4',
      ]) {
        await expectLater(
          service.loadObjectMetadata(invalidPath),
          throwsA(
            isA<StorageFailure>().having(
              (error) => error.reason,
              'reason',
              StorageFailureReason.invalidStoragePath,
            ),
          ),
        );
      }
    });

    test('translates backend failures to a safe Arabic error', () async {
      final service = StorageService(
        StorageRepository(null, (_) async {
          throw FirebaseException(
            plugin: 'firebase_storage',
            code: 'retry-limit-exceeded',
            message: 'raw backend details',
          );
        }),
      );

      await expectLater(
        service.loadObjectMetadata(_approvedPath),
        throwsA(
          isA<StorageFailure>()
              .having(
                (error) => error.reason,
                'reason',
                StorageFailureReason.backend,
              )
              .having(
                (error) => error.message.contains('raw backend details'),
                'does not expose raw details',
                isFalse,
              ),
        ),
      );
    });
  });
}
