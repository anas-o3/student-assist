import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import { after, before, beforeEach, test } from 'node:test';

const projectId = 'demo-student-assist-firestore';
const studentUid = 'student-grade-1';
const otherStudentUid = 'student-grade-2';
const gradeId = 'grade-1';
const subjectId = 'subject-math-g1';
const chapterId = 'chapter-math-g1-1';
const lessonId = 'lesson-math-g1-ch1-1';
const questionId = 'question-math-g1-ch1-l1-1';

let testEnvironment;

async function seedAcademicFixture({ userGradeId = gradeId } = {}) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    await setDoc(doc(database, 'users', studentUid), {
      userId: studentUid,
      role: 'student',
      gradeId: userGradeId,
    });
    await setDoc(doc(database, 'users', otherStudentUid), {
      userId: otherStudentUid,
      role: 'student',
      gradeId: 'grade-2',
    });
    await setDoc(doc(database, 'subjects', subjectId), {
      subjectId,
      gradeId,
      isActive: true,
    });
    await setDoc(doc(database, 'chapters', chapterId), {
      chapterId,
      subjectId,
      isActive: true,
    });
    await setDoc(doc(database, 'lessons', lessonId), {
      lessonId,
      chapterId,
      isActive: true,
    });
    await setDoc(doc(database, 'questions', questionId), {
      questionId,
      lessonId,
      questionText: 'سؤال اختباري',
      options: ['أ', 'ب'],
      correctAnswerIndex: 0,
      explanation: 'تفسير الإجابة',
      order: 1,
      isActive: true,
    });
  });
}

function studentFirestore(uid = studentUid) {
  return testEnvironment.authenticatedContext(uid).firestore();
}

function activeQuestionQuery(database) {
  return query(
    collection(database, 'questions'),
    where('lessonId', '==', lessonId),
    where('isActive', '==', true),
    orderBy('order'),
  );
}

function validAttempt(attemptId = 'attempt-1', userId = studentUid) {
  return {
    attemptId,
    userId,
    lessonId,
    score: 1,
    totalQuestions: 1,
    percentage: 100,
    completedAt: serverTimestamp(),
  };
}

before(async () => {
  testEnvironment = await initializeTestEnvironment({ projectId });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

test('allows an eligible authenticated student to query active questions', async () => {
  await seedAcademicFixture();

  await assertSucceeds(getDocs(activeQuestionQuery(studentFirestore())));
});

test('denies an unauthenticated question query', async () => {
  await seedAcademicFixture();

  await assertFails(
    getDocs(activeQuestionQuery(testEnvironment.unauthenticatedContext().firestore())),
  );
});

test('denies a question query when the student grade does not match', async () => {
  await seedAcademicFixture({ userGradeId: 'grade-2' });

  await assertFails(getDocs(activeQuestionQuery(studentFirestore())));
});

test('denies student question creation', async () => {
  await seedAcademicFixture();

  await assertFails(
    setDoc(doc(studentFirestore(), 'questions', 'question-new'), {
      questionId: 'question-new',
      lessonId,
      isActive: true,
    }),
  );
});

test('denies student question updates', async () => {
  await seedAcademicFixture();

  await assertFails(
    updateDoc(doc(studentFirestore(), 'questions', questionId), {
      correctAnswerIndex: 1,
    }),
  );
});

test('denies student question deletion', async () => {
  await seedAcademicFixture();

  await assertFails(deleteDoc(doc(studentFirestore(), 'questions', questionId)));
});

test('allows an eligible student to create their own valid attempt', async () => {
  await seedAcademicFixture();
  const attemptId = 'attempt-own';

  await assertSucceeds(
    setDoc(
      doc(studentFirestore(), 'quizAttempts', attemptId),
      validAttempt(attemptId),
    ),
  );
});

test('denies creating an attempt for another user', async () => {
  await seedAcademicFixture();
  const attemptId = 'attempt-forged-user';

  await assertFails(
    setDoc(
      doc(studentFirestore(), 'quizAttempts', attemptId),
      validAttempt(attemptId, otherStudentUid),
    ),
  );
});

test('denies an attempt whose document identity is inconsistent', async () => {
  await seedAcademicFixture();

  await assertFails(
    setDoc(
      doc(studentFirestore(), 'quizAttempts', 'attempt-path-id'),
      validAttempt('different-attempt-id'),
    ),
  );
});

test('denies a malformed attempt with unexpected fields', async () => {
  await seedAcademicFixture();
  const attemptId = 'attempt-malformed';

  await assertFails(
    setDoc(doc(studentFirestore(), 'quizAttempts', attemptId), {
      ...validAttempt(attemptId),
      role: 'admin',
    }),
  );
});

test('denies an attempt with an impossible score', async () => {
  await seedAcademicFixture();
  const attemptId = 'attempt-impossible-score';

  await assertFails(
    setDoc(doc(studentFirestore(), 'quizAttempts', attemptId), {
      ...validAttempt(attemptId),
      score: 2,
      totalQuestions: 1,
    }),
  );
});

test('denies an attempt whose percentage does not match its score', async () => {
  await seedAcademicFixture();
  const attemptId = 'attempt-invalid-percentage';

  await assertFails(
    setDoc(doc(studentFirestore(), 'quizAttempts', attemptId), {
      ...validAttempt(attemptId),
      score: 0,
      percentage: 100,
    }),
  );
});

test('denies creating an attempt for a lesson outside the student grade', async () => {
  await seedAcademicFixture({ userGradeId: 'grade-2' });
  const attemptId = 'attempt-wrong-grade';

  await assertFails(
    setDoc(
      doc(studentFirestore(), 'quizAttempts', attemptId),
      validAttempt(attemptId),
    ),
  );
});

test('denies modifying protected attempt fields', async () => {
  await seedAcademicFixture();
  const attemptId = 'attempt-protected';
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'quizAttempts', attemptId),
      {
        ...validAttempt(attemptId),
        completedAt: new Date(),
      },
    );
  });

  await assertFails(
    updateDoc(doc(studentFirestore(), 'quizAttempts', attemptId), { score: 0 }),
  );
});

test('denies reading another student attempt', async () => {
  await seedAcademicFixture();
  const attemptId = 'attempt-other';
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'quizAttempts', attemptId), {
      ...validAttempt(attemptId, otherStudentUid),
      completedAt: new Date(),
    });
  });

  await assertFails(
    getDoc(doc(studentFirestore(), 'quizAttempts', attemptId)),
  );
});

test('denies deleting an own attempt', async () => {
  await seedAcademicFixture();
  const attemptId = 'attempt-delete';
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'quizAttempts', attemptId), {
      ...validAttempt(attemptId),
      completedAt: new Date(),
    });
  });

  await assertFails(deleteDoc(doc(studentFirestore(), 'quizAttempts', attemptId)));
});

test('keeps unrelated collections denied', async () => {
  await seedAcademicFixture();

  await assertFails(getDoc(doc(studentFirestore(), 'unimplemented', 'item')));
  await assertFails(
    setDoc(doc(studentFirestore(), 'unimplemented', 'item'), { value: true }),
  );
});
