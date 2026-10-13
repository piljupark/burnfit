const fs = require('fs');
const path = require('path');
const { after, before, beforeEach, describe, it } = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
} = require('firebase/firestore');

let testEnv;

const projectId = 'burnfit-rules-test-roster';
const centerId = 'center-a';
const otherCenterId = 'center-b';
const adminId = 'admin-a';
const otherAdminId = 'admin-b';
const trainerId = 'trainer-a';
const memberId = 'member-a';

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function row(overrides = {}) {
  return {
    centerId,
    role: 'member',
    name: '이서준',
    phone: '010-1234-5678',
    trainerId,
    trainerName: '박코치',
    ptTotal: 10,
    ptStart: Timestamp.fromDate(new Date('2026-10-01')),
    ptEnd: Timestamp.fromDate(new Date('2027-01-31')),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function rowRef(db, id = '01012345678', center = centerId) {
  return doc(db, 'centers', center, 'roster', id);
}

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const users = [
      { uid: adminId, role: 'admin', name: '관리자', centerId },
      { uid: otherAdminId, role: 'admin', name: '다른 관리자', centerId: otherCenterId },
      { uid: trainerId, role: 'trainer', name: '박코치', centerId },
      { uid: memberId, role: 'member', name: '회원', centerId, trainerId },
    ];
    for (const u of users) {
      await setDoc(doc(db, 'users', u.uid), { ...u, status: 'approved' });
    }
    await setDoc(rowRef(db, '01099998888'), {
      ...row({ name: '정도윤', phone: '010-9999-8888' }),
      updatedAt: Timestamp.now(),
    });
  });
}

describe('센터 명단 (centers/{id}/roster)', () => {
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

  it('그 센터 관리자는 올리고 · 덮어쓰고 · 읽고 · 지울 수 있다', async () => {
    const db = authedDb(adminId);
    await assertSucceeds(setDoc(rowRef(db), row()));
    await assertSucceeds(setDoc(rowRef(db), row({ ptTotal: 20, trainerId: null, trainerName: null })));
    await assertSucceeds(
      setDoc(rowRef(db, '01011112222'), row({
        role: 'trainer', name: '최코치', phone: '010-1111-2222',
        trainerId: null, trainerName: null, ptTotal: null, ptStart: null, ptEnd: null,
      })),
    );
    await assertSucceeds(getDocs(collection(db, 'centers', centerId, 'roster')));
    await assertSucceeds(deleteDoc(rowRef(db)));
  });

  it('트레이너 · 회원 · 다른 센터 관리자는 읽지도 쓰지도 못한다', async () => {
    for (const uid of [trainerId, memberId, otherAdminId]) {
      const db = authedDb(uid);
      await assertFails(getDoc(rowRef(db, '01099998888')));
      await assertFails(getDocs(collection(db, 'centers', centerId, 'roster')));
      await assertFails(setDoc(rowRef(db), row()));
      await assertFails(deleteDoc(rowRef(db, '01099998888')));
    }
  });

  it('문서 이름은 번호 숫자와 같아야 하고, 번호 형식을 지켜야 한다', async () => {
    const db = authedDb(adminId);
    await assertFails(setDoc(rowRef(db, '01000000000'), row()));
    await assertFails(setDoc(rowRef(db, '0101234567'), row({ phone: '0101234567' })));
    await assertFails(setDoc(rowRef(db, '02123456'), row({ phone: '02-123-456' })));
  });

  it('칸 · 값 검사: 모르는 칸, 틀린 구분 · 센터 · 횟수 · 기간, 트레이너 줄의 PT', async () => {
    const db = authedDb(adminId);
    await assertFails(setDoc(rowRef(db), row({ email: 'a@b.c' })));
    await assertFails(setDoc(rowRef(db), row({ role: 'admin' })));
    await assertFails(setDoc(rowRef(db), row({ centerId: otherCenterId })));
    await assertFails(setDoc(rowRef(db), row({ ptTotal: 0 })));
    await assertFails(setDoc(rowRef(db), row({ ptTotal: 501 })));
    await assertFails(setDoc(rowRef(db), row({ ptTotal: '10' })));
    await assertFails(
      setDoc(rowRef(db), row({ ptEnd: Timestamp.fromDate(new Date('2026-09-01')) })),
    );
    await assertFails(setDoc(rowRef(db), row({ role: 'trainer', trainerId: null, trainerName: null })));
    await assertFails(setDoc(rowRef(db), row({ name: '김' })));
    await assertFails(setDoc(rowRef(db), row({ updatedAt: Timestamp.now() })));
  });
});
