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
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} = require('firebase/firestore');

let testEnv;

const projectId = 'burnfit-rules-users-test';
const centerId = 'center-a';
const inactiveCenterId = 'center-closed';
const adminId = 'admin-a';
const trainerId = 'trainer-a';
const pendingTrainerId = 'trainer-pending';
const memberId = 'member-a';
const ptInfoId = 'pt-info-a';
const newUid = 'new-user';
const newEmail = 'new@example.com';

function authedDb(uid, email = `${uid}@example.com`) {
  return testEnv.authenticatedContext(uid, { email }).firestore();
}

function newUserDoc(overrides = {}) {
  return {
    uid: newUid,
    email: newEmail,
    name: '신규',
    role: 'member',
    status: 'pending',
    centerId,
    centerName: '강남 센터',
    trainerId: null,
    trainerName: null,
    birthDate: null,
    gender: null,
    profile: null,
    shareSettings: { workout: true, meal: true, body: true },
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'centers', centerId), {
      id: centerId,
      name: '강남 센터',
      adminId,
      status: 'active',
    });
    await setDoc(doc(db, 'centers', inactiveCenterId), {
      id: inactiveCenterId,
      name: '폐업 센터',
      adminId: 'someone',
      status: 'inactive',
    });
    await setDoc(doc(db, 'users', adminId), {
      uid: adminId, role: 'admin', status: 'approved', centerId, name: '관리자',
    });
    await setDoc(doc(db, 'users', trainerId), {
      uid: trainerId, role: 'trainer', status: 'approved', centerId, name: '트레이너',
    });
    await setDoc(doc(db, 'users', pendingTrainerId), {
      uid: pendingTrainerId, role: 'trainer', status: 'pending', centerId, name: '대기 트레이너',
    });
    await setDoc(doc(db, 'users', memberId), {
      uid: memberId, role: 'member', status: 'approved', centerId, trainerId, name: '회원',
    });
    await setDoc(doc(db, 'pt_infos', ptInfoId), {
      id: ptInfoId,
      memberId,
      trainerId,
      centerId,
      totalSessions: 30,
      remainingSessions: 12,
    });
  });
}

describe('users / centers / pt_infos security rules', () => {
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

  describe('가입 시 사용자 문서 생성', () => {
    it('승인 대기 회원은 운영 중인 센터로 가입할 수 있다', async () => {
      const db = authedDb(newUid, newEmail);
      await assertSucceeds(setDoc(doc(db, 'users', newUid), newUserDoc()));
    });

    it('승인 대기 트레이너도 가입할 수 있다', async () => {
      const db = authedDb(newUid, newEmail);
      await assertSucceeds(setDoc(doc(db, 'users', newUid), newUserDoc({ role: 'trainer' })));
    });

    it('스스로 관리자(approved)로 가입할 수 없다', async () => {
      const db = authedDb(newUid, newEmail);
      await assertFails(setDoc(doc(db, 'users', newUid), newUserDoc({
        role: 'admin',
        status: 'approved',
      })));
    });

    it('스스로 승인된 회원으로 가입할 수 없다', async () => {
      const db = authedDb(newUid, newEmail);
      await assertFails(setDoc(doc(db, 'users', newUid), newUserDoc({ status: 'approved' })));
    });

    it('존재하지 않는 센터로 가입할 수 없다', async () => {
      const db = authedDb(newUid, newEmail);
      await assertFails(setDoc(doc(db, 'users', newUid), newUserDoc({ centerId: 'no-center' })));
    });

    it('운영 중이 아닌 센터로 가입할 수 없다', async () => {
      const db = authedDb(newUid, newEmail);
      await assertFails(setDoc(doc(db, 'users', newUid), newUserDoc({
        centerId: inactiveCenterId,
        centerName: '폐업 센터',
      })));
    });

    it('센터 이름을 다르게 꾸며 가입할 수 없다', async () => {
      const db = authedDb(newUid, newEmail);
      await assertFails(setDoc(doc(db, 'users', newUid), newUserDoc({ centerName: '가짜 센터' })));
    });

    it('담당 트레이너를 스스로 지정할 수 없다', async () => {
      const db = authedDb(newUid, newEmail);
      await assertFails(setDoc(doc(db, 'users', newUid), newUserDoc({
        trainerId,
        trainerName: '트레이너',
      })));
    });

    it('로그인한 이메일과 다른 이메일로 가입할 수 없다', async () => {
      const db = authedDb(newUid, newEmail);
      await assertFails(setDoc(doc(db, 'users', newUid), newUserDoc({ email: 'other@example.com' })));
    });

    it('이메일 대소문자 차이는 허용한다', async () => {
      const db = authedDb(newUid, newEmail);
      await assertSucceeds(setDoc(doc(db, 'users', newUid), newUserDoc({ email: 'New@Example.com' })));
    });
  });

  describe('센터 생성', () => {
    it('클라이언트는 센터를 직접 만들 수 없다 (서버 함수 전용)', async () => {
      const db = authedDb(newUid, newEmail);
      await assertFails(setDoc(doc(db, 'centers', 'center-new'), {
        id: 'center-new',
        name: '새 센터',
        adminId: newUid,
        status: 'active',
      }));
    });

    it('비로그인 사용자도 운영 중인 센터는 검색할 수 있다 (가입 화면)', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertSucceeds(getDoc(doc(db, 'centers', centerId)));
    });
  });

  describe('가입 신청', () => {
    it('본인 센터로만 가입 신청할 수 있다', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'users', newUid), newUserDoc());
      });
      const db = authedDb(newUid, newEmail);
      const base = {
        userId: newUid,
        userName: '신규',
        userEmail: newEmail,
        role: 'member',
        status: 'pending',
        createdAt: new Date(),
      };
      await assertFails(setDoc(doc(db, 'join_requests', 'req-other'), {
        ...base, id: 'req-other', centerId: 'center-b',
      }));
      await assertSucceeds(setDoc(doc(db, 'join_requests', 'req-own'), {
        ...base, id: 'req-own', centerId,
      }));
    });
  });

  describe('승인되지 않은 사용자의 역할 권한', () => {
    it('승인 대기 트레이너는 같은 센터 트레이너 정보를 읽을 수 없다', async () => {
      const db = authedDb(pendingTrainerId);
      await assertFails(getDoc(doc(db, 'users', trainerId)));
    });

    it('승인 대기 트레이너는 센터 사용자 목록을 조회할 수 없다', async () => {
      const db = authedDb(pendingTrainerId);
      await assertFails(getDocs(query(
        collection(db, 'users'),
        where('centerId', '==', centerId),
        where('role', '==', 'trainer'),
      )));
    });

    it('승인 대기 사용자도 자기 문서는 읽을 수 있다 (승인 대기 화면)', async () => {
      const db = authedDb(pendingTrainerId);
      await assertSucceeds(getDoc(doc(db, 'users', pendingTrainerId)));
    });

    it('승인된 트레이너는 같은 센터 트레이너 정보를 읽을 수 있다', async () => {
      const db = authedDb(trainerId);
      await assertSucceeds(getDoc(doc(db, 'users', pendingTrainerId)));
    });

    it('거절된 관리자는 관리자 권한을 잃는다', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'users', adminId), { status: 'rejected' });
      });
      const db = authedDb(adminId);
      await assertFails(getDoc(doc(db, 'users', memberId)));
    });
  });

  describe('탈퇴 회원 PT 이력 보관 (retained_pt_records)', () => {
    const recordPath = 'retained_pt_records/pt_session_s1';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, recordPath), {
          kind: 'pt_session', sourceId: 's1', centerId, memberAlias: 'withdrawn_x', data: {},
        });
        await setDoc(doc(db, 'users', 'admin-b'), {
          uid: 'admin-b', role: 'admin', status: 'approved', centerId: 'center-b', name: '다른 관리자',
        });
      });
    });

    it('같은 센터 관리자는 읽을 수 있다', async () => {
      await assertSucceeds(getDoc(doc(authedDb(adminId), recordPath)));
    });

    it('다른 센터 관리자·트레이너·회원은 읽을 수 없다', async () => {
      await assertFails(getDoc(doc(authedDb('admin-b'), recordPath)));
      await assertFails(getDoc(doc(authedDb(trainerId), recordPath)));
      await assertFails(getDoc(doc(authedDb(memberId), recordPath)));
    });

    it('관리자 화면의 목록 조회(센터 + 종류, 센터 + 별칭)가 허용된다', async () => {
      const db = authedDb(adminId);
      await assertSucceeds(getDocs(query(
        collection(db, 'retained_pt_records'),
        where('centerId', '==', centerId),
        where('kind', '==', 'pt_info'),
      )));
      await assertSucceeds(getDocs(query(
        collection(db, 'retained_pt_records'),
        where('centerId', '==', centerId),
        where('memberAlias', '==', 'withdrawn_x'),
      )));
    });

    it('센터 조건 없는 조회나 다른 센터 조회는 거부된다', async () => {
      await assertFails(getDocs(query(
        collection(authedDb(adminId), 'retained_pt_records'),
        where('kind', '==', 'pt_info'),
      )));
      await assertFails(getDocs(query(
        collection(authedDb('admin-b'), 'retained_pt_records'),
        where('centerId', '==', centerId),
      )));
      await assertFails(getDocs(query(
        collection(authedDb(trainerId), 'retained_pt_records'),
        where('centerId', '==', centerId),
      )));
    });

    it('관리자도 만들거나 고칠 수 없다 (서버 전용)', async () => {
      const db = authedDb(adminId);
      await assertFails(setDoc(doc(db, 'retained_pt_records', 'forged'), { centerId }));
      await assertFails(updateDoc(doc(db, recordPath), { memberAlias: 'changed' }));
    });
  });

  describe('알림함 (users/{uid}/notifications)', () => {
    const inboxPath = `users/${memberId}/notifications/n1`;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), inboxPath), {
          type: 'feedback_created', title: '제목', body: '내용', targetId: 'f1',
          createdAt: new Date(), readAt: null,
        });
      });
    });

    it('본인만 읽을 수 있다 (트레이너·관리자도 불가)', async () => {
      await assertSucceeds(getDoc(doc(authedDb(memberId), inboxPath)));
      await assertSucceeds(getDocs(collection(authedDb(memberId), `users/${memberId}/notifications`)));
      await assertFails(getDoc(doc(authedDb(trainerId), inboxPath)));
      await assertFails(getDoc(doc(authedDb(adminId), inboxPath)));
    });

    it('본인은 서버 시각으로 읽음 처리만 할 수 있다', async () => {
      const db = authedDb(memberId);
      await assertSucceeds(updateDoc(doc(db, inboxPath), { readAt: serverTimestamp() }));
    });

    it('읽음 시각을 꾸미거나 내용을 바꿀 수 없다', async () => {
      const db = authedDb(memberId);
      await assertFails(updateDoc(doc(db, inboxPath), { readAt: new Date(2000, 0, 1) }));
      await assertFails(updateDoc(doc(db, inboxPath), { title: '바꿈' }));
    });

    it('앱에서는 알림을 만들 수 없다', async () => {
      await assertFails(setDoc(doc(authedDb(memberId), `users/${memberId}/notifications/forged`), {
        type: 'feedback_created', title: '가짜', body: '', readAt: null,
      }));
      await assertFails(setDoc(doc(authedDb(adminId), `users/${memberId}/notifications/forged`), {
        type: 'feedback_created', title: '가짜', body: '', readAt: null,
      }));
    });

    it('본인은 지울 수 있고 남은 지울 수 없다', async () => {
      await assertFails(deleteDoc(doc(authedDb(trainerId), inboxPath)));
      await assertSucceeds(deleteDoc(doc(authedDb(memberId), inboxPath)));
    });
  });

  describe('PT 잔여 횟수 변경 (트레이너)', () => {
    it('1회 차감은 허용한다', async () => {
      const db = authedDb(trainerId);
      await assertSucceeds(updateDoc(doc(db, 'pt_infos', ptInfoId), {
        remainingSessions: 11,
        updatedAt: new Date(),
      }));
    });

    it('1회 복구(완료 취소)는 허용한다', async () => {
      const db = authedDb(trainerId);
      await assertSucceeds(updateDoc(doc(db, 'pt_infos', ptInfoId), {
        remainingSessions: 13,
        updatedAt: new Date(),
      }));
    });

    it('임의 값으로 바꿀 수 없다', async () => {
      const db = authedDb(trainerId);
      await assertFails(updateDoc(doc(db, 'pt_infos', ptInfoId), {
        remainingSessions: 30,
        updatedAt: new Date(),
      }));
    });

    it('총 횟수를 넘길 수 없다', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'pt_infos', ptInfoId), { remainingSessions: 30 });
      });
      const db = authedDb(trainerId);
      await assertFails(updateDoc(doc(db, 'pt_infos', ptInfoId), {
        remainingSessions: 31,
        updatedAt: new Date(),
      }));
    });

    it('0 아래로 내릴 수 없다', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'pt_infos', ptInfoId), { remainingSessions: 0 });
      });
      const db = authedDb(trainerId);
      await assertFails(updateDoc(doc(db, 'pt_infos', ptInfoId), {
        remainingSessions: -1,
        updatedAt: new Date(),
      }));
    });
  });
});
