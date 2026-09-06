const fs = require('fs');
const path = require('path');
const { after, before, beforeEach, describe, it } = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDocs,
  orderBy,
  query,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} = require('firebase/firestore');
const assert = require('assert');

let testEnv;

const projectId = 'burnfit-rules-test';
const centerId = 'center-a';
const otherCenterId = 'center-b';
const adminId = 'admin-a';
const trainerId = 'trainer-a';
const newTrainerId = 'trainer-c';
const otherTrainerId = 'trainer-b';
const memberId = 'member-a';
const otherMemberId = 'member-b';
const feedbackId = 'feedback-a';

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

async function seedBaseData() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(doc(db, 'users', adminId), {
      uid: adminId,
      role: 'admin',
      centerId,
      status: 'approved',
      name: '관리자',
    });
    await setDoc(doc(db, 'users', trainerId), {
      uid: trainerId,
      role: 'trainer',
      centerId,
      status: 'approved',
      name: '트레이너',
    });
    await setDoc(doc(db, 'users', otherTrainerId), {
      uid: otherTrainerId,
      role: 'trainer',
      centerId: otherCenterId,
      status: 'approved',
      name: '다른 트레이너',
    });
    await setDoc(doc(db, 'users', newTrainerId), {
      uid: newTrainerId,
      role: 'trainer',
      centerId,
      status: 'approved',
      name: '새 트레이너',
    });
    await setDoc(doc(db, 'users', memberId), {
      uid: memberId,
      role: 'member',
      centerId,
      trainerId,
      status: 'approved',
      name: '회원',
    });
    await setDoc(doc(db, 'users', otherMemberId), {
      uid: otherMemberId,
      role: 'member',
      centerId,
      trainerId,
      status: 'approved',
      name: '다른 회원',
    });
    await setDoc(doc(db, 'feedbacks', feedbackId), {
      id: feedbackId,
      centerId,
      trainerId,
      trainerName: '트레이너',
      memberId,
      memberName: '회원',
      targetType: 'general',
      content: '기본 피드백',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  });
}

describe('firestore feedback rules', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: fs.readFileSync(
          path.resolve(__dirname, '../../firestore.rules'),
          'utf8',
        ),
      },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await seedBaseData();
  });

  after(async () => {
    await testEnv.cleanup();
  });

  it('회원은 본인 피드백의 readAt과 updatedAt만 수정할 수 있다', async () => {
    const db = authedDb(memberId);

    await assertSucceeds(
      updateDoc(doc(db, 'feedbacks', feedbackId), {
        readAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('회원은 본인 피드백 내용을 수정할 수 없다', async () => {
    const db = authedDb(memberId);

    await assertFails(
      updateDoc(doc(db, 'feedbacks', feedbackId), {
        content: '회원이 바꾼 내용',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('회원은 다른 회원의 피드백 읽음 처리를 할 수 없다', async () => {
    const db = authedDb(otherMemberId);

    await assertFails(
      updateDoc(doc(db, 'feedbacks', feedbackId), {
        readAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('담당 트레이너는 피드백을 생성하고 내용을 수정할 수 있다', async () => {
    const db = authedDb(trainerId);
    const newFeedbackRef = doc(db, 'feedbacks', 'feedback-new');

    await assertSucceeds(
      setDoc(newFeedbackRef, {
        id: 'feedback-new',
        centerId,
        trainerId,
        trainerName: '트레이너',
        memberId,
        memberName: '회원',
        targetType: 'general',
        content: '새 피드백',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );

    await assertSucceeds(
      updateDoc(doc(db, 'feedbacks', feedbackId), {
        content: '수정된 피드백',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('비담당 트레이너는 피드백에 접근할 수 없다', async () => {
    const db = authedDb(otherTrainerId);

    await assertFails(getDoc(doc(db, 'feedbacks', feedbackId)));
    await assertFails(
      updateDoc(doc(db, 'feedbacks', feedbackId), {
        content: '권한 없는 수정',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('같은 센터 관리자는 피드백을 읽고 삭제할 수 있다', async () => {
    const db = authedDb(adminId);

    await assertSucceeds(getDoc(doc(db, 'feedbacks', feedbackId)));
    await assertSucceeds(deleteDoc(doc(db, 'feedbacks', feedbackId)));
  });

  it('담당 트레이너는 피드백 삭제 시 원본 식단 연결을 해제할 수 있다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'meals', 'meal-feedback-a'), {
        id: 'meal-feedback-a',
        centerId,
        memberId,
        memberName: '회원',
        trainerId,
        mealType: 'lunch',
        mealDate: '2026-07-20',
        mealTime: '12:00',
        imageUrls: [],
        description: '점심',
        calories: 500,
        hasFeedback: true,
        feedbackId: 'meal-feedback',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      await setDoc(doc(db, 'feedbacks', 'meal-feedback'), {
        id: 'meal-feedback',
        centerId,
        trainerId,
        trainerName: '트레이너',
        memberId,
        memberName: '회원',
        targetType: 'meal',
        targetId: 'meal-feedback-a',
        targetDate: '2026-07-20',
        content: '식단 피드백',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    const db = authedDb(trainerId);
    const batch = writeBatch(db);
    batch.delete(doc(db, 'feedbacks', 'meal-feedback'));
    batch.update(doc(db, 'meals', 'meal-feedback-a'), {
      hasFeedback: false,
      feedbackId: null,
      updatedAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());
  });

  it('PT권 정보는 회원이 readAt 필드로 수정할 수 없다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'pt_infos', 'pt-info-a'), {
        id: 'pt-info-a',
        centerId,
        trainerId,
        memberId,
        totalSessions: 10,
        remainingSessions: 5,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    await assertFails(
      updateDoc(doc(authedDb(memberId), 'pt_infos', 'pt-info-a'), {
        readAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('PT 일정은 담당 트레이너가 일정 필드만 수정할 수 있다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'pt_sessions', 'pt-session-a'), {
        id: 'pt-session-a',
        centerId,
        trainerId,
        memberId,
        scheduledAt: serverTimestamp(),
        durationMinutes: 50,
        note: '',
        status: 'scheduled',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    await assertSucceeds(
      updateDoc(doc(authedDb(trainerId), 'pt_sessions', 'pt-session-a'), {
        durationMinutes: 60,
        note: '시간 변경',
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(
      updateDoc(doc(authedDb(trainerId), 'pt_sessions', 'pt-session-a'), {
        content: '피드백 필드 오염',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('담당 트레이너는 PT 세션 상태를 완료로 바꾸고 PT권 차감 로그를 만들 수 있다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'pt_sessions', 'pt-session-complete'), {
        id: 'pt-session-complete',
        centerId,
        trainerId,
        trainerName: '트레이너',
        memberId,
        memberName: '회원',
        scheduledAt: serverTimestamp(),
        durationMinutes: 50,
        note: '',
        status: 'scheduled',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      await setDoc(doc(db, 'pt_infos', 'pt-info-complete'), {
        id: 'pt-info-complete',
        centerId,
        trainerId,
        memberId,
        memberName: '회원',
        startDate: serverTimestamp(),
        endDate: serverTimestamp(),
        totalSessions: 10,
        remainingSessions: 5,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    const db = authedDb(trainerId);
    const batch = writeBatch(db);
    batch.update(doc(db, 'pt_sessions', 'pt-session-complete'), {
      status: 'completed',
      updatedAt: serverTimestamp(),
    });
    batch.update(doc(db, 'pt_infos', 'pt-info-complete'), {
      remainingSessions: 4,
      updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, 'pt_info_logs', 'pt-info-log-complete'), {
      id: 'pt-info-log-complete',
      ptInfoId: 'pt-info-complete',
      centerId,
      memberId,
      memberName: '회원',
      changedById: trainerId,
      changedByName: '트레이너',
      type: 'sessionCompleted',
      previousTotalSessions: 10,
      nextTotalSessions: 10,
      previousRemainingSessions: 5,
      nextRemainingSessions: 4,
      ptSessionId: 'pt-session-complete',
      note: null,
      createdAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());
  });

  it('담당 트레이너는 잘못된 PT 세션 상태로 변경할 수 없다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'pt_sessions', 'pt-session-invalid'), {
        id: 'pt-session-invalid',
        centerId,
        trainerId,
        trainerName: '트레이너',
        memberId,
        memberName: '회원',
        scheduledAt: serverTimestamp(),
        durationMinutes: 50,
        note: '',
        status: 'scheduled',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    await assertFails(
      updateDoc(doc(authedDb(trainerId), 'pt_sessions', 'pt-session-invalid'), {
        status: 'archived',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('트레이너는 담당 회원 목록과 본인 PT 일정을 조회할 수 있다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'pt_sessions', 'trainer-home-a'), {
        id: 'trainer-home-a',
        centerId,
        trainerId,
        trainerName: '트레이너',
        memberId,
        memberName: '회원',
        scheduledAt: new Date('2026-07-21T09:00:00.000Z'),
        durationMinutes: 50,
        note: '',
        status: 'scheduled',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    const db = authedDb(trainerId);
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'users'),
          where('centerId', '==', centerId),
          where('role', '==', 'member'),
          where('trainerId', '==', trainerId),
          where('status', '==', 'approved'),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'pt_sessions'),
          where('centerId', '==', centerId),
          where('trainerId', '==', trainerId),
          orderBy('scheduledAt'),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collection(authedDb(otherTrainerId), 'pt_sessions'),
          where('centerId', '==', centerId),
          where('trainerId', '==', trainerId),
          orderBy('scheduledAt'),
        ),
      ),
    );
  });

  it('테스트 시드가 기대한 권한 관계를 가진다', async () => {
    const db = authedDb(memberId);
    const snapshot = await assertSucceeds(
      getDoc(doc(db, 'feedbacks', feedbackId)),
    );

    assert.equal(snapshot.data().memberId, memberId);
  });

  it('가입 요청 작성자는 요청 상태를 직접 바꿀 수 없다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'join_requests', 'join-a'), {
        id: 'join-a',
        userId: memberId,
        userName: '회원',
        userEmail: 'member@example.com',
        centerId,
        centerName: '센터',
        role: 'member',
        status: 'pending',
        createdAt: serverTimestamp(),
      });
    });

    await assertFails(
      updateDoc(doc(authedDb(memberId), 'join_requests', 'join-a'), {
        status: 'approved',
      }),
    );

    await assertSucceeds(
      updateDoc(doc(authedDb(adminId), 'join_requests', 'join-a'), {
        status: 'approved',
      }),
    );
  });

  it('관리자는 회원 승인과 트레이너 배정만 할 수 있고 역할/센터는 바꿀 수 없다', async () => {
    await assertSucceeds(
      updateDoc(doc(authedDb(adminId), 'users', memberId), {
        status: 'approved',
        updatedAt: serverTimestamp(),
      }),
    );

    await assertSucceeds(
      updateDoc(doc(authedDb(adminId), 'users', memberId), {
        trainerId: newTrainerId,
        trainerName: '새 트레이너',
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(
      updateDoc(doc(authedDb(adminId), 'users', memberId), {
        role: 'admin',
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(
      updateDoc(doc(authedDb(adminId), 'users', memberId), {
        centerId: otherCenterId,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('회원은 본인 개인 운동만 정상 생성할 수 있고 피드백 필드를 변조할 수 없다', async () => {
    const db = authedDb(memberId);
    const baseWorkout = {
      id: 'workout-a',
      centerId,
      memberId,
      memberName: '회원',
      trainerId,
      workoutType: 'personal',
      createdById: memberId,
      createdByRole: 'member',
      ptSessionId: null,
      workoutDate: '2026-07-20',
      category: 'chest',
      exercises: [{ name: '벤치프레스', sets: [{ weight: 40, reps: 10 }] }],
      note: null,
      hasFeedback: false,
      feedbackId: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      durationSeconds: 1200,
    };

    await assertSucceeds(setDoc(doc(db, 'workouts', 'workout-a'), baseWorkout));
    await assertFails(
      setDoc(doc(db, 'workouts', 'workout-spoof'), {
        ...baseWorkout,
        id: 'workout-spoof',
        hasFeedback: true,
        feedbackId: 'feedback-spoof',
      }),
    );
  });

  it('회원은 운동의 소유권/작성자 필드를 수정할 수 없다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'workouts', 'workout-owned'), {
        id: 'workout-owned',
        centerId,
        memberId,
        memberName: '회원',
        trainerId,
        workoutType: 'personal',
        createdById: memberId,
        createdByRole: 'member',
        ptSessionId: null,
        workoutDate: '2026-07-20',
        category: 'chest',
        exercises: [{ name: '벤치프레스', sets: [{ weight: 40, reps: 10 }] }],
        note: null,
        hasFeedback: false,
        feedbackId: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        durationSeconds: 1200,
      });
    });

    await assertSucceeds(
      updateDoc(doc(authedDb(memberId), 'workouts', 'workout-owned'), {
        note: '운동 메모 수정',
        durationSeconds: 1500,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(authedDb(memberId), 'workouts', 'workout-owned'), {
        memberId: otherMemberId,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('담당 트레이너는 담당 회원의 PT 운동을 생성할 수 있다', async () => {
    await assertSucceeds(
      setDoc(doc(authedDb(trainerId), 'workouts', 'pt-workout-a'), {
        id: 'pt-workout-a',
        centerId,
        memberId,
        memberName: '회원',
        trainerId,
        workoutType: 'pt',
        createdById: trainerId,
        createdByRole: 'trainer',
        ptSessionId: 'pt-session-a',
        workoutDate: '2026-07-20',
        category: 'back',
        exercises: [{ name: '랫풀다운', sets: [{ weight: 35, reps: 12 }] }],
        note: null,
        hasFeedback: false,
        feedbackId: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        durationSeconds: 1800,
      }),
    );
  });

  it('관리자는 운동 기록의 내용만 정정할 수 있고 소유권 필드는 바꿀 수 없다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'workouts', 'admin-workout-a'), {
        id: 'admin-workout-a',
        centerId,
        memberId,
        memberName: '회원',
        trainerId,
        workoutType: 'personal',
        createdById: memberId,
        createdByRole: 'member',
        ptSessionId: null,
        workoutDate: '2026-07-20',
        category: 'chest',
        exercises: [{ name: '벤치프레스', sets: [{ weight: 40, reps: 10 }] }],
        note: null,
        hasFeedback: false,
        feedbackId: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        durationSeconds: 1200,
      });
    });

    await assertSucceeds(
      updateDoc(doc(authedDb(adminId), 'workouts', 'admin-workout-a'), {
        note: '관리자 메모 정정',
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(
      updateDoc(doc(authedDb(adminId), 'workouts', 'admin-workout-a'), {
        memberId: otherMemberId,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('회원은 트레이너가 작성한 PT 운동 기록을 삭제할 수 없다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'workouts', 'pt-workout-owned'), {
        id: 'pt-workout-owned',
        centerId,
        memberId,
        memberName: '회원',
        trainerId,
        workoutType: 'pt',
        createdById: trainerId,
        createdByRole: 'trainer',
        ptSessionId: 'pt-session-a',
        workoutDate: '2026-07-20',
        category: 'back',
        exercises: [{ name: '랫풀다운', sets: [{ weight: 35, reps: 12 }] }],
        note: null,
        hasFeedback: false,
        feedbackId: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        durationSeconds: 1800,
      });
    });

    await assertFails(deleteDoc(doc(authedDb(memberId), 'workouts', 'pt-workout-owned')));
    await assertSucceeds(deleteDoc(doc(authedDb(trainerId), 'workouts', 'pt-workout-owned')));
  });

  it('회원은 식단 생성 시 피드백 필드를 변조할 수 없다', async () => {
    const baseMeal = {
      id: 'meal-a',
      centerId,
      memberId,
      memberName: '회원',
      trainerId,
      mealType: 'lunch',
      mealDate: '2026-07-20',
      mealTime: '12:00',
      imageUrls: [],
      description: '점심',
      calories: 500,
      hasFeedback: false,
      feedbackId: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    await assertSucceeds(setDoc(doc(authedDb(memberId), 'meals', 'meal-a'), baseMeal));
    await assertFails(
      setDoc(doc(authedDb(memberId), 'meals', 'meal-spoof'), {
        ...baseMeal,
        id: 'meal-spoof',
        hasFeedback: true,
        feedbackId: 'feedback-spoof',
      }),
    );
  });

  it('회원은 유산소 생성 시 피드백 필드를 변조할 수 없다', async () => {
    const baseCardio = {
      id: 'cardio-a',
      centerId,
      memberId,
      memberName: '회원',
      trainerId,
      cardioDate: '2026-07-20',
      type: 'treadmill',
      durationMinutes: 30,
      speed: 6.5,
      intensity: null,
      name: null,
      note: null,
      hasFeedback: false,
      feedbackId: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    await assertSucceeds(
      setDoc(doc(authedDb(memberId), 'cardios', 'cardio-a'), baseCardio),
    );
    await assertFails(
      setDoc(doc(authedDb(memberId), 'cardios', 'cardio-spoof'), {
        ...baseCardio,
        id: 'cardio-spoof',
        hasFeedback: true,
        feedbackId: 'feedback-spoof',
      }),
    );
  });

  it('회원은 허용된 프로필과 공유 설정만 수정할 수 있다', async () => {
    await assertSucceeds(
      updateDoc(doc(authedDb(memberId), 'users', memberId), {
        profile: {
          height: 175,
          weight: 72,
          muscleMass: 32,
          bodyFat: 14,
          goal: '근력 향상',
        },
        updatedAt: serverTimestamp(),
      }),
    );

    await assertSucceeds(
      updateDoc(doc(authedDb(memberId), 'users', memberId), {
        shareSettings: {
          workout: true,
          meal: false,
          body: true,
        },
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(
      updateDoc(doc(authedDb(memberId), 'users', memberId), {
        profile: {
          height: 175,
          role: 'admin',
        },
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(
      updateDoc(doc(authedDb(memberId), 'users', memberId), {
        gender: 'manager',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('담당 트레이너는 인바디를 생성하고 측정값만 수정할 수 있다', async () => {
    const db = authedDb(trainerId);
    await assertSucceeds(
      setDoc(doc(db, 'inbodies', 'inbody-a'), {
        id: 'inbody-a',
        centerId,
        memberId,
        memberName: '회원',
        trainerId,
        measurementDate: '2026-07-20',
        weight: 72,
        muscleMass: 32,
        bodyFat: 14,
        bodyFatPercent: 19.4,
        bmi: 23.5,
        bmr: 1650,
        visceralFat: 7,
        leftArm: null,
        rightArm: null,
        trunk: null,
        leftLeg: null,
        rightLeg: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );

    await assertSucceeds(
      updateDoc(doc(db, 'inbodies', 'inbody-a'), {
        weight: 71.5,
        muscleMass: 32.4,
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(
      updateDoc(doc(db, 'inbodies', 'inbody-a'), {
        memberId: otherMemberId,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('관리자는 PT권 운영 필드만 수정할 수 있고 소유권 필드는 바꿀 수 없다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'pt_infos', 'admin-pt-info-a'), {
        id: 'admin-pt-info-a',
        centerId,
        trainerId,
        memberId,
        memberName: '회원',
        totalSessions: 10,
        remainingSessions: 5,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    await assertSucceeds(
      updateDoc(doc(authedDb(adminId), 'pt_infos', 'admin-pt-info-a'), {
        totalSessions: 12,
        remainingSessions: 7,
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(
      updateDoc(doc(authedDb(adminId), 'pt_infos', 'admin-pt-info-a'), {
        memberId: otherMemberId,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('관리자는 신규 PT권과 변경 로그를 같은 배치로 등록할 수 있다', async () => {
    const db = authedDb(adminId);
    const batch = writeBatch(db);

    batch.set(doc(db, 'pt_infos', 'admin-pt-info-new'), {
      id: 'admin-pt-info-new',
      centerId,
      trainerId,
      memberId,
      memberName: '회원',
      totalSessions: 10,
      remainingSessions: 10,
      startDate: null,
      endDate: null,
      renewalDate: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, 'pt_info_logs', 'admin-pt-log-new'), {
      id: 'admin-pt-log-new',
      ptInfoId: 'admin-pt-info-new',
      centerId,
      memberId,
      memberName: '회원',
      changedById: adminId,
      changedByName: '관리자',
      type: 'created',
      previousTotalSessions: 0,
      nextTotalSessions: 10,
      previousRemainingSessions: 0,
      nextRemainingSessions: 10,
      ptSessionId: null,
      note: null,
      createdAt: serverTimestamp(),
    });

    await assertSucceeds(batch.commit());
  });

  it('관리자는 피드백 내용만 수정할 수 있고 대상 회원은 바꿀 수 없다', async () => {
    await assertSucceeds(
      updateDoc(doc(authedDb(adminId), 'feedbacks', feedbackId), {
        content: '관리자 수정 피드백',
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(
      updateDoc(doc(authedDb(adminId), 'feedbacks', feedbackId), {
        memberId: otherMemberId,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('비담당 트레이너는 인바디를 생성할 수 없다', async () => {
    await assertFails(
      setDoc(doc(authedDb(otherTrainerId), 'inbodies', 'inbody-denied'), {
        id: 'inbody-denied',
        centerId,
        memberId,
        memberName: '회원',
        trainerId: otherTrainerId,
        measurementDate: '2026-07-20',
        weight: 72,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('사용자는 본인 커스텀 운동만 생성하고 수정할 수 없다', async () => {
    await assertSucceeds(
      setDoc(doc(authedDb(trainerId), 'custom_exercises', 'custom-a'), {
        id: 'custom-a',
        memberId: trainerId,
        name: '케이블 로우',
        category: 'back',
        createdAt: serverTimestamp(),
      }),
    );

    await assertFails(
      setDoc(doc(authedDb(trainerId), 'custom_exercises', 'custom-spoof'), {
        id: 'custom-spoof',
        memberId,
        name: '권한 없는 운동',
        category: 'back',
        createdAt: serverTimestamp(),
      }),
    );

    await assertFails(
      updateDoc(doc(authedDb(trainerId), 'custom_exercises', 'custom-a'), {
        name: '수정 시도',
      }),
    );
  });

  it('관리자는 회원 재배정 시 회원, PT권, 예정 PT일정을 함께 갱신할 수 있다', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'pt_infos', 'pt-info-reassign'), {
        id: 'pt-info-reassign',
        centerId,
        trainerId,
        memberId,
        memberName: '회원',
        totalSessions: 10,
        remainingSessions: 5,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      await setDoc(doc(db, 'pt_sessions', 'pt-session-reassign'), {
        id: 'pt-session-reassign',
        centerId,
        trainerId,
        trainerName: '트레이너',
        memberId,
        memberName: '회원',
        scheduledAt: serverTimestamp(),
        durationMinutes: 50,
        note: '',
        status: 'scheduled',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    const db = authedDb(adminId);
    const batch = writeBatch(db);
    const update = {
      trainerId: newTrainerId,
      trainerName: '새 트레이너',
      updatedAt: serverTimestamp(),
    };
    batch.update(doc(db, 'users', memberId), update);
    batch.update(doc(db, 'pt_infos', 'pt-info-reassign'), {
      trainerId: newTrainerId,
      updatedAt: serverTimestamp(),
    });
    batch.update(doc(db, 'pt_sessions', 'pt-session-reassign'), update);

    await assertSucceeds(batch.commit());
  });
});
