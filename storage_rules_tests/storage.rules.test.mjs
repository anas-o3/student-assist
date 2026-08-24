import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import {
  deleteObject,
  getBytes,
  listAll,
  ref,
  uploadBytes,
} from 'firebase/storage';
import { after, before, beforeEach, test } from 'node:test';

const projectId = 'demo-student-assist-storage';
const studentUid = 'student-grade-1';
const gradeId = 'grade-1';
const subjectId = 'subject-math-g1';
const chapterId = 'chapter-math-g1-1';
const lessonId = 'lesson-math-g1-ch1-1';

let testEnvironment;

function resourcePath(resourceId, fileName) {
  return `student-content/grades/${gradeId}/subjects/${subjectId}/chapters/${chapterId}/lessons/${lessonId}/resources/${resourceId}/${fileName}`;
}

async function seedFixture({
  uid = studentUid,
  userGradeId = gradeId,
  resourceId = 'resource-video',
  resourceLessonId = lessonId,
  storagePath = resourcePath(resourceId, 'lesson.mp4'),
  objectPath = storagePath,
  type = 'video',
  isActive = true,
  contentType = 'video/mp4',
  createObject = true,
} = {}) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', uid), {
      gradeId: userGradeId,
    });
    await setDoc(doc(context.firestore(), 'resources', resourceId), {
      resourceId,
      lessonId: resourceLessonId,
      storagePath,
      type,
      isActive,
    });

    if (createObject) {
      await uploadBytes(
        ref(context.storage(), objectPath),
        new Uint8Array([1, 2, 3]),
        { contentType },
      );
    }
  });

  return objectPath;
}

function authenticatedStorage(uid = studentUid, tokenOptions) {
  return testEnvironment.authenticatedContext(uid, tokenOptions).storage();
}

before(async () => {
  testEnvironment = await initializeTestEnvironment({ projectId });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.clearStorage();
});

after(async () => {
  await testEnvironment.cleanup();
});

test('allows a grade-1 student to read a matching active video', async () => {
  const path = await seedFixture();

  await assertSucceeds(getBytes(ref(authenticatedStorage(), path)));
});

test('allows a grade-1 student to read a matching active PDF', async () => {
  const resourceId = 'resource-pdf';
  const path = resourcePath(resourceId, 'summary.pdf');
  await seedFixture({
    resourceId,
    storagePath: path,
    objectPath: path,
    type: 'pdf',
    contentType: 'application/pdf',
  });

  await assertSucceeds(getBytes(ref(authenticatedStorage(), path)));
});

test('denies an unauthenticated read', async () => {
  const path = await seedFixture();

  await assertFails(
    getBytes(ref(testEnvironment.unauthenticatedContext().storage(), path)),
  );
});

test('denies a student whose grade does not match the path', async () => {
  const path = await seedFixture({ userGradeId: 'grade-2' });

  await assertFails(getBytes(ref(authenticatedStorage(), path)));
});

test('denies an inactive Resource', async () => {
  const path = await seedFixture({ isActive: false });

  await assertFails(getBytes(ref(authenticatedStorage(), path)));
});

test('denies a Resource whose lessonId does not match the path', async () => {
  const path = await seedFixture({ resourceLessonId: 'another-lesson' });

  await assertFails(getBytes(ref(authenticatedStorage(), path)));
});

test('denies a Resource whose storagePath does not match the object', async () => {
  const objectPath = resourcePath('resource-video', 'lesson.mp4');
  await seedFixture({
    storagePath: resourcePath('resource-video', 'different.mp4'),
    objectPath,
  });

  await assertFails(getBytes(ref(authenticatedStorage(), objectPath)));
});

test('denies an unsupported Resource type', async () => {
  const path = await seedFixture({ type: 'sample-a' });

  await assertFails(getBytes(ref(authenticatedStorage(), path)));
});

test('denies a video Resource with a non-video contentType', async () => {
  const path = await seedFixture({ contentType: 'application/pdf' });

  await assertFails(getBytes(ref(authenticatedStorage(), path)));
});

test('denies a PDF Resource with a non-PDF contentType', async () => {
  const resourceId = 'resource-pdf';
  const path = resourcePath(resourceId, 'summary.pdf');
  await seedFixture({
    resourceId,
    storagePath: path,
    objectPath: path,
    type: 'pdf',
    contentType: 'text/plain',
  });

  await assertFails(getBytes(ref(authenticatedStorage(), path)));
});

test('denies listing the approved resource directory', async () => {
  const path = await seedFixture();
  const directory = path.substring(0, path.lastIndexOf('/'));

  await assertFails(listAll(ref(authenticatedStorage(), directory)));
});

test('denies a student upload', async () => {
  const path = await seedFixture({ createObject: false });

  await assertFails(
    uploadBytes(ref(authenticatedStorage(), path), new Uint8Array([4]), {
      contentType: 'video/mp4',
    }),
  );
});

test('denies a student overwrite', async () => {
  const path = await seedFixture();

  await assertFails(
    uploadBytes(ref(authenticatedStorage(), path), new Uint8Array([5]), {
      contentType: 'video/mp4',
    }),
  );
});

test('denies a student delete', async () => {
  const path = await seedFixture();

  await assertFails(deleteObject(ref(authenticatedStorage(), path)));
});

test('denies an authenticated read from an unrelated Storage path', async () => {
  const path = 'unrelated/public-file.txt';
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(
      ref(context.storage(), path),
      new Uint8Array([6]),
      { contentType: 'text/plain' },
    );
  });

  await assertFails(getBytes(ref(authenticatedStorage(), path)));
});

test('does not grant Storage writes to a client with an admin claim', async () => {
  const path = await seedFixture({ createObject: false });
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', 'admin-user'), {
      userId: 'admin-user',
      role: 'admin',
      gradeId: null,
    });
  });
  const storage = authenticatedStorage('admin-user', { admin: true });

  await assertFails(
    uploadBytes(ref(storage, path), new Uint8Array([7]), {
      contentType: 'video/mp4',
    }),
  );
});
