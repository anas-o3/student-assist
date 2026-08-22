import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_assist/models/resource.dart';
import 'package:student_assist/repositories/resource_repository.dart';
import 'package:student_assist/services/resource_service.dart';

void main() {
  final createdAt = DateTime.utc(2026, 2, 10, 8, 30);

  Map<String, dynamic> validResourceData() => {
    'resourceId': 'resource-introduction',
    'lessonId': 'lesson-equations',
    'title': 'مورد تمهيدي',
    'type': 'unapproved-future-type',
    'url': '',
    'storagePath': '',
    'order': 1,
    'isActive': true,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  group('Resource', () {
    test('parses the approved Firestore schema and timestamp', () {
      final resource = Resource.fromFirestore(
        documentId: 'resource-introduction',
        data: validResourceData(),
      );

      expect(resource.resourceId, 'resource-introduction');
      expect(resource.lessonId, 'lesson-equations');
      expect(resource.title, 'مورد تمهيدي');
      expect(resource.type, 'unapproved-future-type');
      expect(resource.url, isEmpty);
      expect(resource.storagePath, isEmpty);
      expect(resource.order, 1);
      expect(resource.isActive, isTrue);
      expect(resource.createdAt.isAtSameMomentAs(createdAt), isTrue);
    });

    test('rejects a resourceId that differs from the document id', () {
      final data = validResourceData()..['resourceId'] = 'different-id';

      expect(
        () => Resource.fromFirestore(
          documentId: 'resource-introduction',
          data: data,
        ),
        throwsFormatException,
      );
    });

    for (final invalidField in const ['lessonId', 'title']) {
      test('rejects an invalid $invalidField', () {
        final data = validResourceData()..[invalidField] = '   ';

        expect(
          () => Resource.fromFirestore(
            documentId: 'resource-introduction',
            data: data,
          ),
          throwsFormatException,
        );
      });
    }

    for (final invalidField in const ['type', 'url', 'storagePath']) {
      test('rejects a non-string $invalidField', () {
        final data = validResourceData()..[invalidField] = 12;

        expect(
          () => Resource.fromFirestore(
            documentId: 'resource-introduction',
            data: data,
          ),
          throwsFormatException,
        );
      });
    }

    test('accepts unknown type values without normalization', () {
      final data = validResourceData()..['type'] = 'FutureCustomTYPE';

      final resource = Resource.fromFirestore(
        documentId: 'resource-introduction',
        data: data,
      );

      expect(resource.type, 'FutureCustomTYPE');
    });

    test('rejects a non-integer order', () {
      final data = validResourceData()..['order'] = 1.5;

      expect(
        () => Resource.fromFirestore(
          documentId: 'resource-introduction',
          data: data,
        ),
        throwsFormatException,
      );
    });

    test('rejects an invalid isActive value', () {
      final data = validResourceData()..['isActive'] = 'true';

      expect(
        () => Resource.fromFirestore(
          documentId: 'resource-introduction',
          data: data,
        ),
        throwsFormatException,
      );
    });

    test('rejects an invalid createdAt timestamp', () {
      final data = validResourceData()..['createdAt'] = createdAt;

      expect(
        () => Resource.fromFirestore(
          documentId: 'resource-introduction',
          data: data,
        ),
        throwsFormatException,
      );
    });
  });

  group('ResourceRepository', () {
    test('delegates the exact active resource query contract', () async {
      String? requestedLessonId;
      bool? requestedIsActive;
      String? requestedOrderByField;
      final repository = ResourceRepository(null, ({
        required lessonId,
        required isActive,
        required orderByField,
      }) async {
        requestedLessonId = lessonId;
        requestedIsActive = isActive;
        requestedOrderByField = orderByField;
        return [
          (documentId: 'resource-introduction', data: validResourceData()),
        ];
      });

      final resources = await repository.loadActiveResourcesForLesson(
        'lesson-equations',
      );

      expect(requestedLessonId, 'lesson-equations');
      expect(requestedIsActive, isTrue);
      expect(requestedOrderByField, 'order');
      expect(resources.single.resourceId, 'resource-introduction');
      expect(resources.single.type, 'unapproved-future-type');
    });

    test('classifies malformed documents as invalid data', () async {
      final repository = ResourceRepository(null, ({
        required lessonId,
        required isActive,
        required orderByField,
      }) async {
        return [
          (
            documentId: 'resource-introduction',
            data: validResourceData()..['title'] = '',
          ),
        ];
      });

      await expectLater(
        repository.loadActiveResourcesForLesson('lesson-equations'),
        throwsA(
          isA<ResourceRepositoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            ResourceRepositoryFailureReason.invalidData,
          ),
        ),
      );
    });

    test('converts Firebase failures into repository-safe failures', () async {
      final repository = ResourceRepository(null, ({
        required lessonId,
        required isActive,
        required orderByField,
      }) async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'private Firebase detail',
        );
      });

      await expectLater(
        repository.loadActiveResourcesForLesson('lesson-equations'),
        throwsA(
          isA<ResourceRepositoryFailure>().having(
            (failure) => failure.reason,
            'reason',
            ResourceRepositoryFailureReason.backend,
          ),
        ),
      );
    });
  });

  group('ResourceService', () {
    test('trims lessonId and delegates loading to the repository', () async {
      final repository = _FakeResourceRepository(resources: [_resource]);
      final service = ResourceService(repository);

      final resources = await service.loadActiveResourcesForLesson(
        ' lesson-equations ',
      );

      expect(repository.loadCalls, 1);
      expect(repository.lastLessonId, 'lesson-equations');
      expect(resources.single.resourceId, 'resource-introduction');
    });

    test('rejects an empty lessonId without repository access', () async {
      final repository = _FakeResourceRepository();
      final service = ResourceService(repository);

      await expectLater(
        service.loadActiveResourcesForLesson('   '),
        throwsA(
          isA<ResourceFailure>().having(
            (failure) => failure.reason,
            'reason',
            ResourceFailureReason.emptyLessonId,
          ),
        ),
      );
      expect(repository.loadCalls, 0);
    });

    test('translates invalid data failures safely', () async {
      final service = ResourceService(
        _FakeResourceRepository(
          failure: const ResourceRepositoryFailure(
            ResourceRepositoryFailureReason.invalidData,
          ),
        ),
      );

      await expectLater(
        service.loadActiveResourcesForLesson('lesson-equations'),
        throwsA(
          isA<ResourceFailure>()
              .having(
                (failure) => failure.reason,
                'reason',
                ResourceFailureReason.invalidData,
              )
              .having(
                (failure) => failure.message,
                'message',
                isNot(contains('private Firebase detail')),
              ),
        ),
      );
    });

    test('translates backend failures safely', () async {
      final service = ResourceService(
        _FakeResourceRepository(failure: const ResourceRepositoryFailure()),
      );

      await expectLater(
        service.loadActiveResourcesForLesson('lesson-equations'),
        throwsA(
          isA<ResourceFailure>()
              .having(
                (failure) => failure.reason,
                'reason',
                ResourceFailureReason.backend,
              )
              .having(
                (failure) => failure.message,
                'message',
                contains('تعذر تحميل موارد الدرس'),
              ),
        ),
      );
    });
  });
}

final _resource = Resource(
  resourceId: 'resource-introduction',
  lessonId: 'lesson-equations',
  title: 'مورد تمهيدي',
  type: 'unapproved-future-type',
  url: '',
  storagePath: '',
  order: 1,
  isActive: true,
  createdAt: DateTime.utc(2026, 2, 10, 8, 30),
);

class _FakeResourceRepository extends ResourceRepository {
  _FakeResourceRepository({this.resources = const [], this.failure});

  final List<Resource> resources;
  final ResourceRepositoryFailure? failure;
  int loadCalls = 0;
  String? lastLessonId;

  @override
  Future<List<Resource>> loadActiveResourcesForLesson(String lessonId) async {
    loadCalls++;
    lastLessonId = lessonId;
    final repositoryFailure = failure;
    if (repositoryFailure != null) throw repositoryFailure;
    return resources;
  }
}
