const fs = require('fs');
const path = require('path');
const { after, before, beforeEach, describe, it } = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { deleteDoc, doc, getDoc, serverTimestamp, setDoc } = require('firebase/firestore');

let testEnv;

const projectId = 'burnfit-rules-test-nutrition';
const centerId = 'center-a';
const adminId = 'admin-a';
const trainerId = 'trainer-a';
const otherTrainerId = 'trainer-b';
const memberId = 'member-a';
const otherMemberId = 'member-b';

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function plan(overrides = {}) {
  return {
    memberId,
    centerId,
    trainerId,
    trainerName: '트레이너',
    calories: 2100,
    carbs: 230,
    protein: 140,
    fat: 60,
    mealGuides: { breakfast: '단백질 손바닥 1개', dinner: '밥 반 공기' },
    note: '저녁 탄수화물 줄이기',
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const users = [
      { uid: adminId, role: 'admin', name: '관리자' },
      { uid: trainerId, role: 'trainer', name: '트레이너' },
      { uid: otherTrainerId, role: 'trainer', name: '다른 트레이너' },
      { uid: memberId, role: 'member', name: '회원', trainerId },
      { uid: otherMemberId, role: 'member', name: '다른 회원', trainerId: otherTrainerId },
    ];
    for (const u of users) {
      await setDoc(doc(db, 'users', u.uid), { ...u, centerId, status: 'approved' });
    }
  });
}

describe('식단 목표 (nutrition_plans)', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8'),
      },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await seed();
  });

  after(async () => {
    await testEnv.cleanup();
  });

  it('담당 트레이너는 정하고 고칠 수 있고, 회원 · 관리자는 읽을 수 있다', async () => {
    const ref = doc(authedDb(trainerId), 'nutrition_plans', memberId);
    await assertSucceeds(setDoc(ref, plan()));
    await assertSucceeds(setDoc(ref, plan({ calories: 1900, note: null })));
    await assertSucceeds(getDoc(doc(authedDb(memberId), 'nutrition_plans', memberId)));
    await assertSucceeds(getDoc(doc(authedDb(adminId), 'nutrition_plans', memberId)));
  });

  it('숫자를 모두 비워도 끼니 가이드만으로 저장할 수 있다', async () => {
    const ref = doc(authedDb(trainerId), 'nutrition_plans', memberId);
    await assertSucceeds(
      setDoc(ref, plan({ calories: null, carbs: null, protein: null, fat: null })),
    );
  });

  it('회원 본인은 쓸 수 없고, 다른 회원 목표는 읽을 수 없다', async () => {
    await assertFails(setDoc(doc(authedDb(memberId), 'nutrition_plans', memberId), plan()));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'nutrition_plans', otherMemberId),
        plan({ memberId: otherMemberId, trainerId: otherTrainerId }),
      );
    });
    await assertFails(getDoc(doc(authedDb(memberId), 'nutrition_plans', otherMemberId)));
  });

  it('담당이 아닌 트레이너는 쓰지도 읽지도 못한다', async () => {
    const ref = doc(authedDb(otherTrainerId), 'nutrition_plans', memberId);
    await assertFails(setDoc(ref, plan({ trainerId: otherTrainerId })));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'nutrition_plans', memberId), plan());
    });
    await assertFails(getDoc(ref));
    await assertFails(deleteDoc(ref));
  });

  it('작성자를 남으로 적거나, 범위 밖 숫자 · 모르는 칸 · 다른 끼니 이름은 막는다', async () => {
    const ref = doc(authedDb(trainerId), 'nutrition_plans', memberId);
    await assertFails(setDoc(ref, plan({ trainerId: otherTrainerId })));
    await assertFails(setDoc(ref, plan({ memberId: otherMemberId })));
    await assertFails(setDoc(ref, plan({ calories: 50000 })));
    await assertFails(setDoc(ref, plan({ protein: -1 })));
    await assertFails(setDoc(ref, plan({ extra: 1 })));
    await assertFails(setDoc(ref, plan({ mealGuides: { brunch: '아점' } })));
    await assertFails(setDoc(ref, plan({ note: 'ㄱ'.repeat(501) })));
  });

  it('담당 트레이너는 지울 수 있다', async () => {
    const ref = doc(authedDb(trainerId), 'nutrition_plans', memberId);
    await assertSucceeds(setDoc(ref, plan()));
    await assertSucceeds(deleteDoc(ref));
  });
});
