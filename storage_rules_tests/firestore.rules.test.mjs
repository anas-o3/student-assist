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
const adminUid = 'trusted-admin';
const gradeId = 'grade-1';
const subjectId = 'subject-math-g1';
const chapterId = 'chapter-math-g1-1';
const lessonId = 'lesson-math-g1-ch1-1';
const questionId = 'question-math-g1-ch1-l1-1';

let testEnvironment;

async function seedAcademicFixture({
  userGradeId = gradeId,
  subjectIsActive = true,
  chapterIsActive = true,
  lessonIsActive = true,
} = {}) {
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
      isActive: subjectIsActive,
    });
    await setDoc(doc(database, 'chapters', chapterId), {
      chapterId,
      subjectId,
      isActive: chapterIsActive,
    });
    await setDoc(doc(database, 'lessons', lessonId), {
      lessonId,
      chapterId,
      isActive: lessonIsActive,
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

function adminFirestore(uid = adminUid, tokenOptions = { admin: true }) {
  return testEnvironment.authenticatedContext(uid, tokenOptions).firestore();
}

async function seedAdminIdentity({ role = 'admin', uid = adminUid } = {}) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', uid), {
      userId: uid,
      name: 'مدير الاختبار',
      email: 'admin@example.test',
      role,
      gradeId: null,
      createdAt: new Date(),
    });
  });
}

async function seedCompleteContentFixture() {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    const timestamp = new Date();
    await setDoc(doc(database, 'grades', gradeId), {
      gradeId,
      name: 'الصف الأول',
      order: 1,
      isActive: true,
    });
    await setDoc(doc(database, 'subjects', subjectId), {
      subjectId,
      name: 'الرياضيات',
      gradeId,
      imageUrl: '',
      order: 1,
      isActive: true,
    });
    await setDoc(doc(database, 'chapters', chapterId), {
      chapterId,
      title: 'الباب الأول',
      subjectId,
      order: 1,
      isActive: true,
    });
    await setDoc(doc(database, 'lessons', lessonId), {
      lessonId,
      title: 'الدرس الأول',
      chapterId,
      explanation: 'شرح الدرس',
      order: 1,
      isActive: true,
      createdAt: timestamp,
      updatedAt: timestamp,
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
    await setDoc(doc(database, 'resources', 'resource-video'), {
      resourceId: 'resource-video',
      lessonId,
      title: 'فيديو الدرس',
      type: 'video',
      url: '',
      storagePath:
        'student-content/grades/grade-1/subjects/subject-math-g1/chapters/chapter-math-g1-1/lessons/lesson-math-g1-ch1-1/resources/resource-video/lesson.mp4',
      order: 1,
      isActive: true,
      createdAt: timestamp,
    });
  });
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

test('denies a question query when the referenced Lesson is inactive', async () => {
  await seedAcademicFixture({ lessonIsActive: false });

  await assertFails(getDocs(activeQuestionQuery(studentFirestore())));
});

test('denies a question query when the referenced Chapter is inactive', async () => {
  await seedAcademicFixture({ chapterIsActive: false });

  await assertFails(getDocs(activeQuestionQuery(studentFirestore())));
});

test('denies a question query when the referenced Subject is inactive', async () => {
  await seedAcademicFixture({ subjectIsActive: false });

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

test('allows a student to read their own attempt', async () => {
  await seedAcademicFixture();
  const attemptId = 'attempt-readable-own';
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'quizAttempts', attemptId), {
      ...validAttempt(attemptId),
      completedAt: new Date(),
    });
  });

  await assertSucceeds(
    getDoc(doc(studentFirestore(), 'quizAttempts', attemptId)),
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

test('allows a trusted Admin to create the approved academic content schemas', async () => {
  await seedAdminIdentity();
  const database = adminFirestore();

  await assertSucceeds(setDoc(doc(database, 'grades', gradeId), {
    gradeId,
    name: 'الصف الأول',
    order: 1,
    isActive: true,
  }));
  await assertSucceeds(setDoc(doc(database, 'subjects', subjectId), {
    subjectId,
    name: 'الرياضيات',
    gradeId,
    imageUrl: '',
    order: 1,
    isActive: true,
  }));
  await assertSucceeds(setDoc(doc(database, 'chapters', chapterId), {
    chapterId,
    title: 'الباب الأول',
    subjectId,
    order: 1,
    isActive: true,
  }));
  await assertSucceeds(setDoc(doc(database, 'lessons', lessonId), {
    lessonId,
    title: 'الدرس الأول',
    chapterId,
    explanation: 'شرح الدرس',
    order: 1,
    isActive: true,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(setDoc(doc(database, 'questions', questionId), {
    questionId,
    lessonId,
    questionText: 'سؤال اختباري',
    options: ['أ', 'ب'],
    correctAnswerIndex: 0,
    explanation: 'تفسير الإجابة',
    order: 1,
    isActive: true,
  }));
  await assertSucceeds(setDoc(doc(database, 'resources', 'resource-video'), {
    resourceId: 'resource-video',
    lessonId,
    title: 'فيديو الدرس',
    type: 'video',
    url: '',
    storagePath:
      'student-content/grades/grade-1/subjects/subject-math-g1/chapters/chapter-math-g1-1/lessons/lesson-math-g1-ch1-1/resources/resource-video/lesson.mp4',
    order: 1,
    isActive: false,
    createdAt: serverTimestamp(),
  }));
});

test('allows a trusted Admin to update approved content without changing identities', async () => {
  await seedAdminIdentity();
  await seedCompleteContentFixture();
  const database = adminFirestore();

  await assertSucceeds(updateDoc(doc(database, 'grades', gradeId), { name: 'الصف الأول المحدث' }));
  await assertSucceeds(updateDoc(doc(database, 'subjects', subjectId), { name: 'رياضيات' }));
  await assertSucceeds(updateDoc(doc(database, 'chapters', chapterId), { title: 'باب محدث' }));
  await assertSucceeds(updateDoc(doc(database, 'lessons', lessonId), {
    explanation: 'شرح محدث',
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(database, 'questions', questionId), { questionText: 'سؤال محدث' }));
  await assertSucceeds(updateDoc(doc(database, 'resources', 'resource-video'), { title: 'فيديو محدث' }));
});

test('allows a trusted Admin to read inactive content for management', async () => {
  await seedAdminIdentity();
  await seedCompleteContentFixture();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'grades', gradeId), { isActive: false });
  });

  await assertSucceeds(getDoc(doc(adminFirestore(), 'grades', gradeId)));
});

test('denies academic writes without authentication', async () => {
  const database = testEnvironment.unauthenticatedContext().firestore();

  await assertFails(setDoc(doc(database, 'grades', gradeId), {
    gradeId,
    name: 'الصف الأول',
    order: 1,
    isActive: true,
  }));
});

test('denies a student from writing every Admin-managed content category', async () => {
  await seedAcademicFixture();
  await seedCompleteContentFixture();
  const database = studentFirestore();

  await assertFails(setDoc(doc(database, 'grades', 'grade-new'), {
    gradeId: 'grade-new',
    name: 'صف جديد',
    order: 2,
    isActive: true,
  }));
  await assertFails(updateDoc(doc(database, 'subjects', subjectId), { name: 'مزور' }));
  await assertFails(updateDoc(doc(database, 'chapters', chapterId), { title: 'مزور' }));
  await assertFails(deleteDoc(doc(database, 'lessons', lessonId)));
  await assertFails(updateDoc(doc(database, 'questions', questionId), { questionText: 'مزور' }));
  await assertFails(updateDoc(doc(database, 'resources', 'resource-video'), { title: 'مزور' }));
});

test('denies a forged Firestore admin role without the trusted Auth claim', async () => {
  await seedAdminIdentity({ uid: 'forged-role' });
  const database = adminFirestore('forged-role', {});

  await assertFails(setDoc(doc(database, 'grades', 'grade-forged'), {
    gradeId: 'grade-forged',
    name: 'صف مزور',
    order: 1,
    isActive: true,
  }));
});

test('denies student self-promotion on profile create and update', async () => {
  await seedAcademicFixture();
  await assertFails(
    updateDoc(doc(studentFirestore(), 'users', studentUid), {
      role: 'admin',
    }),
  );

  const newUid = 'self-promoter';
  const email = 'self-promoter@example.test';
  const database = testEnvironment.authenticatedContext(newUid, { email })
    .firestore();
  await assertFails(setDoc(doc(database, 'users', newUid), {
    userId: newUid,
    name: 'طالب',
    email,
    role: 'admin',
    gradeId: null,
    createdAt: serverTimestamp(),
  }));
});

test('denies an admin claim when the protected user profile is not admin', async () => {
  await seedAdminIdentity({ role: 'student', uid: 'claim-only' });
  const database = adminFirestore('claim-only', { admin: true });

  await assertFails(setDoc(doc(database, 'grades', 'grade-claim-only'), {
    gradeId: 'grade-claim-only',
    name: 'صف غير موثوق',
    order: 1,
    isActive: true,
  }));
});

test('rejects unexpected fields from a trusted Admin', async () => {
  await seedAdminIdentity();

  await assertFails(setDoc(doc(adminFirestore(), 'grades', gradeId), {
    gradeId,
    name: 'الصف الأول',
    order: 1,
    isActive: true,
    owner: adminUid,
  }));
});

test('keeps hard deletion denied even for a trusted Admin', async () => {
  await seedAdminIdentity();
  await seedCompleteContentFixture();

  await assertFails(deleteDoc(doc(adminFirestore(), 'grades', gradeId)));
  await assertFails(deleteDoc(doc(adminFirestore(), 'resources', 'resource-video')));
});

test('keeps unrelated collection writes denied for a trusted Admin', async () => {
  await seedAdminIdentity();

  await assertFails(setDoc(doc(adminFirestore(), 'unimplemented', 'item'), {
    value: true,
  }));
});
