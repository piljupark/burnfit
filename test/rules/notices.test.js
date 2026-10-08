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
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} = require('firebase/firestore');

let testEnv;

const projectId = 'burnfit-notices-rules-test';
const centerId = 'center-a';
const otherCenterId = 'center-b';
const adminId = 'admin-a';
const otherAdminId = 'admin-b';
const trainerId = 'trainer-a';
const memberId = 'member-a';
const otherMemberId = 'member-b';
const pendingMemberId = 'member-pending';

function db(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function validNotice(overrides = {}) {
  return {
    centerId,
    title: '휴관 안내',
    body: '추석 연휴 기간 휴관합니다.',
    audience: 'all',
    pinned: false,
    important: false,
    notify: false,
    authorId: adminId,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const d = context.firestore();
    const users = [
      [adminId, 'admin', centerId, 'approved'],
      [otherAdminId, 'admin', otherCenterId, 'approved'],
      [trainerId, 'trainer', centerId, 'approved'],
      [memberId, 'member', centerId, 'approved'],
      [otherMemberId, 'member', otherCenterId, 'approved'],
      [pendingMemberId, 'member', centerId, 'pending'],
    ];
    for (const [uid, role, c, status] of users) {
      await setDoc(doc(d, 'users', uid), { uid, role, centerId: c, status, name: uid });
    }
    const ts = Timestamp.fromDate(new Date('2026-10-01T00:00:00Z'));
    const base = {
      centerId,
      body: '내용',
      pinned: false,
      important: false,
      authorId: adminId,
      createdAt: ts,
      updatedAt: ts,
    };
    await setDoc(doc(d, 'notices', 'n-all'), { ...base, title: '전체', audience: 'all' });
    await setDoc(doc(d, 'notices', 'n-member'), { ...base, title: '회원', audience: 'member' });
    await setDoc(doc(d, 'notices', 'n-trainer'), { ...base, title: '트레이너', audience: 'trainer' });
  });
}

describe('notices rules', () => {
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

  it('같은 센터 회원은 전체·회원 대상 공지를 읽고 트레이너 대상은 못 읽는다', async () => {
    await assertSucceeds(getDoc(doc(db(memberId), 'notices', 'n-all')));
    await assertSucceeds(getDoc(doc(db(memberId), 'notices', 'n-member')));
    await assertFails(getDoc(doc(db(memberId), 'notices', 'n-trainer')));
  });

  it('트레이너는 회원 대상 공지를 못 읽는다', async () => {
    await assertSucceeds(getDoc(doc(db(trainerId), 'notices', 'n-trainer')));
    await assertFails(getDoc(doc(db(trainerId), 'notices', 'n-member')));
  });

  it('관리자는 자기 센터 공지를 모두 읽는다', async () => {
    await assertSucceeds(getDoc(doc(db(adminId), 'notices', 'n-member')));
    await assertSucceeds(getDoc(doc(db(adminId), 'notices', 'n-trainer')));
    await assertSucceeds(
      getDocs(
        query(
          collection(db(adminId), 'notices'),
          where('centerId', '==', centerId),
          orderBy('pinned', 'desc'),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
  });

  it('다른 센터 사용자·승인 대기·비로그인은 읽을 수 없다', async () => {
    await assertFails(getDoc(doc(db(otherMemberId), 'notices', 'n-all')));
    await assertFails(getDoc(doc(db(otherAdminId), 'notices', 'n-all')));
    await assertFails(getDoc(doc(db(pendingMemberId), 'notices', 'n-all')));
    await assertFails(getDoc(doc(testEnv.unauthenticatedContext().firestore(), 'notices', 'n-all')));
  });

  it('회원 목록 쿼리는 audience in [all, member]일 때만 허용된다', async () => {
    const col = collection(db(memberId), 'notices');
    await assertSucceeds(
      getDocs(
        query(
          col,
          where('centerId', '==', centerId),
          where('audience', 'in', ['all', 'member']),
          orderBy('createdAt', 'desc'),
        ),
      ),
    );
    await assertFails(
      getDocs(query(col, where('centerId', '==', centerId), orderBy('createdAt', 'desc'))),
    );
  });

  it('관리자는 자기 센터에 공지를 작성·수정·삭제할 수 있다', async () => {
    const ref = doc(db(adminId), 'notices', 'new-1');
    await assertSucceeds(setDoc(ref, validNotice({ pinned: true, important: true, notify: true })));
    await assertSucceeds(
      updateDoc(ref, { title: '수정된 제목', audience: 'member', updatedAt: serverTimestamp() }),
    );
    await assertSucceeds(deleteDoc(ref));
  });

  it('다른 센터로의 작성, 회원·트레이너의 작성은 거부된다', async () => {
    await assertFails(
      setDoc(doc(db(adminId), 'notices', 'x1'), validNotice({ centerId: otherCenterId })),
    );
    await assertFails(
      setDoc(doc(db(memberId), 'notices', 'x2'), validNotice({ authorId: memberId })),
    );
    await assertFails(
      setDoc(doc(db(trainerId), 'notices', 'x3'), validNotice({ authorId: trainerId })),
    );
    await assertFails(updateDoc(doc(db(memberId), 'notices', 'n-all'), { title: '해킹', updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(db(memberId), 'notices', 'n-all')));
    await assertFails(deleteDoc(doc(db(otherAdminId), 'notices', 'n-all')));
  });

  it('필드·길이·대상 값·작성자·시각 검증', async () => {
    const d = db(adminId);
    await assertFails(setDoc(doc(d, 'notices', 'b1'), validNotice({ title: 'a'.repeat(41) })));
    await assertFails(setDoc(doc(d, 'notices', 'b2'), validNotice({ title: '' })));
    await assertFails(setDoc(doc(d, 'notices', 'b3'), validNotice({ body: 'a'.repeat(2001) })));
    await assertFails(setDoc(doc(d, 'notices', 'b4'), validNotice({ audience: 'everyone' })));
    await assertFails(setDoc(doc(d, 'notices', 'b5'), validNotice({ extra: 1 })));
    await assertFails(setDoc(doc(d, 'notices', 'b6'), validNotice({ authorId: 'someone' })));
    await assertFails(setDoc(doc(d, 'notices', 'b7'), validNotice({ pinned: 'yes' })));
    await assertFails(
      setDoc(doc(d, 'notices', 'b8'), validNotice({ createdAt: Timestamp.fromDate(new Date('2020-01-01')) })),
    );
    await assertFails(setDoc(doc(d, 'notices', 'b9'), validNotice({ notify: 'true' })));
    await assertSucceeds(setDoc(doc(d, 'notices', 'ok'), validNotice({ title: 'a'.repeat(40) })));
  });

  it('수정 시 centerId·authorId·createdAt은 바꿀 수 없고 updatedAt은 서버 시각이어야 한다', async () => {
    const ref = doc(db(adminId), 'notices', 'n-all');
    await assertFails(updateDoc(ref, { authorId: 'other', updatedAt: serverTimestamp() }));
    await assertFails(
      updateDoc(ref, { createdAt: serverTimestamp(), updatedAt: serverTimestamp() }),
    );
    await assertFails(updateDoc(ref, { centerId: otherCenterId, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { title: '시각 누락' }));
    await assertSucceeds(updateDoc(ref, { pinned: true, updatedAt: serverTimestamp() }));
  });
});
