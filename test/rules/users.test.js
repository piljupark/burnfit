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
  writeBatch,
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

// 관리자 PT 변경 기록 (기본: 시드 PT권 30/12 그대로, 서버 시각)
function ptLog(id, overrides = {}) {
  return {
    id,
    ptInfoId,
    centerId,
    memberId,
    memberName: '회원',
    changedById: adminId,
    changedByName: '관리자',
    type: 'updated',
    previousTotalSessions: 30,
    nextTotalSessions: 30,
    previousRemainingSessions: 12,
    nextRemainingSessions: 12,
    ptSessionId: null,
    note: null,
    createdAt: serverTimestamp(),
    ...overrides,
  };
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

  describe('보안 강화 (2026-10-08 전수 점검)', () => {
    it('가입 시 사용자 문서와 가입 신청을 한 배치로 만들 수 있다', async () => {
      const db = authedDb(newUid, newEmail);
      const batch = writeBatch(db);
      batch.set(doc(db, 'users', newUid), newUserDoc());
      batch.set(doc(db, 'join_requests', 'req-batch'), {
        id: 'req-batch', userId: newUid, userName: '신규', userEmail: newEmail,
        role: 'member', status: 'pending', centerId, createdAt: new Date(),
      });
      await assertSucceeds(batch.commit());
    });

    it('가입 시 허용되지 않은 필드(예: 탈퇴 보관 정보)를 넣을 수 없다', async () => {
      const db = authedDb(newUid, newEmail);
      await assertFails(setDoc(doc(db, 'users', newUid), newUserDoc({
        deletionPrep: { memberAlias: 'x', expireAt: new Date(0) },
      })));
    });

    it('관리자도 사용자 문서·PT권을 지울 수 없고 센터 정보를 바꿀 수 없다', async () => {
      const db = authedDb(adminId);
      await assertFails(deleteDoc(doc(db, 'users', memberId)));
      await assertFails(deleteDoc(doc(db, 'users', adminId)));
      await assertFails(deleteDoc(doc(db, 'pt_infos', ptInfoId)));
      await assertFails(updateDoc(doc(db, 'centers', centerId), { status: 'inactive' }));
    });

    it('관리자는 자기 자신이나 다른 관리자의 상태를 바꿀 수 없다', async () => {
      await assertFails(updateDoc(doc(authedDb(adminId), 'users', adminId), { status: 'rejected', updatedAt: new Date() }));
    });

    it('트레이너는 PT권을 만들 수 없다', async () => {
      await assertFails(setDoc(doc(authedDb(trainerId), 'pt_infos', 'pt-forged'), {
        id: 'pt-forged', centerId, trainerId, memberId, memberName: '회원',
        startDate: new Date(), endDate: new Date(), totalSessions: 999, remainingSessions: 999,
        createdAt: new Date(), updatedAt: new Date(),
      }));
    });

    it('관리자 PT권은 횟수가 올바라야 한다 (잔여 ≤ 전체, 전체 1 이상, 0 이상 정수)', async () => {
      const edit = (fields, logId) => {
        const db = authedDb(adminId);
        const batch = writeBatch(db);
        const next = { totalSessions: 30, remainingSessions: 12, ...fields };
        batch.update(doc(db, 'pt_infos', ptInfoId), { ...fields, lastLogId: logId, updatedAt: serverTimestamp() });
        batch.set(doc(db, 'pt_info_logs', logId), ptLog(logId, {
          previousTotalSessions: 30, previousRemainingSessions: 12,
          nextTotalSessions: next.totalSessions, nextRemainingSessions: next.remainingSessions,
        }));
        return batch.commit();
      };
      await assertFails(edit({ remainingSessions: 31 }, 'l1'));
      await assertFails(edit({ remainingSessions: -1 }, 'l2'));
      await assertFails(edit({ totalSessions: 0, remainingSessions: 0 }, 'l3'));
      await assertSucceeds(edit({ remainingSessions: 20 }, 'l4'));
    });

    it('PT 변경 기록은 관리자 본인 이름 · 서버 시각으로, PT권 변경과 함께만 남길 수 있다', async () => {
      const db = authedDb(adminId);
      const withPt = (log) => {
        const batch = writeBatch(db);
        batch.update(doc(db, 'pt_infos', ptInfoId), { remainingSessions: 11, lastLogId: log.id, updatedAt: serverTimestamp() });
        batch.set(doc(db, 'pt_info_logs', log.id), log);
        return batch.commit();
      };
      const changed = { nextRemainingSessions: 11 };
      // 다른 사람 이름
      await assertFails(withPt(ptLog('log-forged', { ...changed, changedById: trainerId })));
      // 기기 시각
      await assertFails(withPt(ptLog('log-time', { ...changed, createdAt: new Date(0) })));
      // 숫자가 실제 변경과 다름
      await assertFails(withPt(ptLog('log-lie', { nextRemainingSessions: 30 })));
      // 서버만 쓰는 종류
      await assertFails(withPt(ptLog('log-type', { ...changed, type: 'sessionCompleted' })));
      // PT권 변경 없이 기록만
      await assertFails(setDoc(doc(db, 'pt_info_logs', 'log-alone'), ptLog('log-alone')));
      // 트레이너는 못 쓴다
      await assertFails(setDoc(doc(authedDb(trainerId), 'pt_info_logs', 'log-t'), ptLog('log-t', { changedById: trainerId })));
      await assertSucceeds(withPt(ptLog('log-ok', changed)));
    });

    it('PT권 횟수·날짜는 변경 기록 없이 바꿀 수 없고, 날짜는 시각 · 순서가 맞아야 한다', async () => {
      const db = authedDb(adminId);
      await assertFails(updateDoc(doc(db, 'pt_infos', ptInfoId), { remainingSessions: 11, updatedAt: serverTimestamp() }));
      const dated = (start, end, logId) => {
        const batch = writeBatch(db);
        batch.update(doc(db, 'pt_infos', ptInfoId), { startDate: start, endDate: end, lastLogId: logId, updatedAt: serverTimestamp() });
        batch.set(doc(db, 'pt_info_logs', logId), ptLog(logId));
        return batch.commit();
      };
      await assertFails(dated(new Date(2026, 9, 10), new Date(2026, 9, 1), 'd1'));
      await assertFails(dated('2026-10-01', null, 'd2'));
      await assertSucceeds(dated(new Date(2026, 9, 1), new Date(2026, 11, 31), 'd3'));
    });

    it('PT 일정은 예약 상태로만 만들 수 있다 (완료로 바로 만들기 금지)', async () => {
      const session = (status, id) => ({
        id, centerId, trainerId, trainerName: '트레이너', memberId, memberName: '회원',
        scheduledAt: new Date(), durationMinutes: 50, note: '', status,
        createdAt: new Date(), updatedAt: new Date(),
      });
      await assertFails(setDoc(doc(authedDb(trainerId), 'pt_sessions', 's-done'), session('completed', 's-done')));
      await assertSucceeds(setDoc(doc(authedDb(trainerId), 'pt_sessions', 's-ok'), session('scheduled', 's-ok')));
      await assertFails(deleteDoc(doc(authedDb(trainerId), 'pt_sessions', 's-ok')));
    });

    it('트레이너 재배정 조회: centerId를 넣으면 허용, 빼면 거부 (규칙은 필터가 아니다)', async () => {
      const db = authedDb(adminId);
      await assertSucceeds(getDocs(query(collection(db, 'pt_infos'),
        where('centerId', '==', centerId), where('memberId', '==', memberId))));
      await assertSucceeds(getDocs(query(collection(db, 'pt_sessions'),
        where('centerId', '==', centerId), where('memberId', '==', memberId), where('status', '==', 'scheduled'))));
      await assertFails(getDocs(query(collection(db, 'pt_infos'), where('memberId', '==', memberId))));
    });

    it('예전에 운동 공유를 꺼 둔 회원이어도 담당 트레이너는 PT·개인 기록을 모두 읽는다', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await updateDoc(doc(db, 'users', memberId), { shareSettings: { workout: false, meal: true, body: true } });
        const w = (id, type, by) => ({ id, centerId, memberId, trainerId: by, workoutType: type, workoutDate: '2026-10-08' });
        await setDoc(doc(db, 'workouts', 'w-pt'), w('w-pt', 'pt', trainerId));
        await setDoc(doc(db, 'workouts', 'w-personal'), w('w-personal', 'personal', trainerId));
      });
      const db = authedDb(trainerId);
      await assertSucceeds(getDoc(doc(db, 'workouts', 'w-pt')));
      await assertSucceeds(getDoc(doc(db, 'workouts', 'w-personal')));
      await assertSucceeds(getDocs(query(collection(db, 'workouts'),
        where('centerId', '==', centerId), where('memberId', '==', memberId),
        where('workoutType', '==', 'pt'), where('trainerId', '==', trainerId))));
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

  describe('본인 기본 정보 수정 (생년월일·성별)', () => {
    it('8자리 생년월일과 성별은 바꿀 수 있다', async () => {
      const db = authedDb(memberId);
      await assertSucceeds(updateDoc(doc(db, 'users', memberId), {
        birthDate: '19940512',
        gender: 'female',
        updatedAt: new Date(),
      }));
    });

    it('형식이 다른 생년월일은 거부된다', async () => {
      const db = authedDb(memberId);
      for (const birthDate of ['1994-05-12', '1994051', 'x'.repeat(5000), 19940512]) {
        await assertFails(updateDoc(doc(db, 'users', memberId), { birthDate, updatedAt: new Date() }));
      }
    });

    it('목록에 없는 성별은 거부된다', async () => {
      const db = authedDb(memberId);
      await assertFails(updateDoc(doc(db, 'users', memberId), { gender: 'unknown', updatedAt: new Date() }));
    });

    it('예전 형식으로 남은 생년월일이 있어도 다른 필드는 고칠 수 있다', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'users', memberId), { birthDate: '1994.05.12' });
      });
      const db = authedDb(memberId);
      await assertSucceeds(updateDoc(doc(db, 'users', memberId), { name: '회원2', updatedAt: new Date() }));
    });
  });

  describe('PT 잔여 횟수 변경 (트레이너는 직접 못 바꾼다 — 서버 함수 setPtSessionStatus 전용)', () => {
    it('1회 차감도 직접 쓸 수 없다', async () => {
      const db = authedDb(trainerId);
      await assertFails(updateDoc(doc(db, 'pt_infos', ptInfoId), {
        remainingSessions: 11,
        updatedAt: new Date(),
      }));
    });

    it('1회 복구도 직접 쓸 수 없다', async () => {
      const db = authedDb(trainerId);
      await assertFails(updateDoc(doc(db, 'pt_infos', ptInfoId), {
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

  describe('권한 보강 (담당 배정·센터 읽기·운동 생성·나만의 운동)', () => {
    const otherCenterTrainerId = 'trainer-other-center';
    const closedAdminId = 'admin-closed';

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, 'users', otherCenterTrainerId), {
          uid: otherCenterTrainerId,
          role: 'trainer',
          status: 'approved',
          centerId: 'center-other',
          name: '다른 센터 트레이너',
        });
        await setDoc(doc(db, 'users', closedAdminId), {
          uid: closedAdminId,
          role: 'admin',
          status: 'approved',
          centerId: inactiveCenterId,
          name: '폐업 센터 관리자',
        });
      });
    });

    const names = { [trainerId]: '트레이너', [pendingTrainerId]: '대기 트레이너' };
    const assign = (uid, trainer, name = trainer == null ? null : names[trainer] ?? '이름') =>
      updateDoc(doc(authedDb(adminId), 'users', uid), {
        trainerId: trainer,
        trainerName: name,
        updatedAt: serverTimestamp(),
      });

    it('관리자는 같은 센터의 승인된 트레이너만 회원에게 배정할 수 있다', async () => {
      await assertSucceeds(assign(memberId, trainerId));
      await assertSucceeds(assign(memberId, null));
      // 담당 이름은 그 트레이너의 실제 이름이어야 한다
      await assertFails(assign(memberId, trainerId, '꾸민 이름'));
      await assertFails(assign(memberId, pendingTrainerId));
      await assertFails(assign(memberId, otherCenterTrainerId));
      await assertFails(assign(memberId, adminId));
      await assertFails(assign(memberId, 'no-such-user'));
      // 트레이너 문서에는 담당 트레이너를 둘 수 없다.
      await assertFails(assign(pendingTrainerId, trainerId));
    });

    it('운영 중이 아닌 센터는 그 센터 소속만 읽는다', async () => {
      const unauthed = testEnv.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(unauthed, 'centers', inactiveCenterId)));
      await assertFails(getDoc(doc(authedDb(memberId), 'centers', inactiveCenterId)));
      await assertSucceeds(getDoc(doc(authedDb(closedAdminId), 'centers', inactiveCenterId)));
      await assertSucceeds(getDoc(doc(authedDb(memberId), 'centers', centerId)));
      // 가입 화면의 운영 중 센터 검색 쿼리는 비로그인도 된다.
      await assertSucceeds(
        getDocs(query(collection(unauthed, 'centers'), where('status', '==', 'active'))),
      );
    });

    it('관리자는 운동 기록을 새로 만들 수 없다', async () => {
      await assertFails(
        setDoc(doc(authedDb(adminId), 'workouts', 'admin-made'), {
          id: 'admin-made',
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
          exercises: [],
          note: null,
          hasFeedback: false,
          feedbackId: null,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }),
      );
    });

    it('승인되지 않은 계정은 나만의 운동을 만들 수 없다', async () => {
      const exercise = (uid) => ({
        id: `custom-${uid}`,
        memberId: uid,
        name: '케이블 로우',
        category: 'back',
        createdAt: serverTimestamp(),
      });
      await assertFails(
        setDoc(doc(authedDb(pendingTrainerId), 'custom_exercises', `custom-${pendingTrainerId}`), exercise(pendingTrainerId)),
      );
      await assertSucceeds(
        setDoc(doc(authedDb(memberId), 'custom_exercises', `custom-${memberId}`), exercise(memberId)),
      );
    });
  });

  describe('관리자 처리 보강 (2026-10-09 관리자 점검)', () => {
    const pendingUid = 'pending-member';
    const reqId = `req-${pendingUid}`;

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, 'users', pendingUid), {
          uid: pendingUid, role: 'member', status: 'pending', centerId, name: '대기 회원',
        });
        await setDoc(doc(db, 'join_requests', reqId), {
          id: reqId, userId: pendingUid, userName: '대기 회원', userEmail: 'p@example.com',
          centerId, centerName: '강남 센터', role: 'member', status: 'pending', createdAt: new Date(),
        });
      });
    });

    const decide = (status, userId = pendingUid) => {
      const db = authedDb(adminId);
      const batch = writeBatch(db);
      batch.update(doc(db, 'join_requests', reqId), { status });
      batch.update(doc(db, 'users', userId), { status, updatedAt: serverTimestamp() });
      return batch.commit();
    };

    it('가입 요청은 대기 중일 때 한 번만 승인·거절할 수 있다', async () => {
      await assertSucceeds(decide('approved'));
      // 승인한 뒤 다시 거절하거나 대기로 되돌릴 수 없다
      await assertFails(decide('rejected'));
      await assertFails(decide('pending'));
    });

    it('요청과 다른 사람의 상태를 함께 바꿀 수 없다', async () => {
      await assertFails(decide('approved', 'pending-trainer-x'));
      // 요청만 바꾸고 사용자 문서는 그대로 두는 것도 안 된다
      await assertFails(updateDoc(doc(authedDb(adminId), 'join_requests', reqId), { status: 'approved' }));
    });

    it('승인된 계정의 상태는 관리자가 바꿀 수 없다', async () => {
      await assertFails(updateDoc(doc(authedDb(adminId), 'users', memberId), { status: 'rejected', updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(authedDb(adminId), 'users', trainerId), { status: 'pending', updatedAt: serverTimestamp() }));
    });

    const newTrainer = 'trainer-b';
    const trainerChange = (overrides = {}) => {
      const db = authedDb(adminId);
      const batch = writeBatch(db);
      batch.update(doc(db, 'users', memberId), {
        trainerId: newTrainer, trainerName: '새 트레이너', updatedAt: serverTimestamp(),
      });
      batch.set(doc(db, 'pt_info_logs', 'log-trainer'), ptLog('log-trainer', {
        type: 'trainerChanged', previousTrainerId: trainerId, nextTrainerId: newTrainer,
        note: '트레이너 → 새 트레이너', ...overrides,
      }));
      return batch.commit();
    };

    it('담당 변경 기록은 실제 담당 변경과 함께만 남길 수 있다', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'users', newTrainer), {
          uid: newTrainer, role: 'trainer', status: 'approved', centerId, name: '새 트레이너',
        });
      });
      await assertFails(trainerChange({ nextTrainerId: 'someone-else' }));
      await assertFails(trainerChange({ previousTrainerId: 'someone-else' }));
      await assertFails(setDoc(doc(authedDb(adminId), 'pt_info_logs', 'log-alone'), ptLog('log-alone', {
        type: 'trainerChanged', previousTrainerId: trainerId, nextTrainerId: newTrainer,
      })));
      await assertSucceeds(trainerChange());
    });

    it('예약이 많아도 담당 변경(회원 · 기록 · PT권 · 예약 30개)을 한 배치로 할 수 있다 (규칙 읽기 상한)', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, 'users', newTrainer), {
          uid: newTrainer, role: 'trainer', status: 'approved', centerId, name: '새 트레이너',
        });
        for (let i = 0; i < 30; i++) {
          await setDoc(doc(db, 'pt_sessions', `many-${i}`), {
            id: `many-${i}`, centerId, trainerId, trainerName: '트레이너', memberId, memberName: '회원',
            scheduledAt: new Date(), durationMinutes: 50, note: '', status: 'scheduled',
            createdAt: new Date(), updatedAt: new Date(),
          });
        }
      });
      const db = authedDb(adminId);
      const batch = writeBatch(db);
      const assigned = { trainerId: newTrainer, trainerName: '새 트레이너', updatedAt: serverTimestamp() };
      batch.update(doc(db, 'users', memberId), assigned);
      batch.set(doc(db, 'pt_info_logs', 'log-many'), ptLog('log-many', {
        type: 'trainerChanged', previousTrainerId: trainerId, nextTrainerId: newTrainer,
      }));
      batch.update(doc(db, 'pt_infos', ptInfoId), { trainerId: newTrainer, updatedAt: serverTimestamp() });
      for (let i = 0; i < 30; i++) batch.update(doc(db, 'pt_sessions', `many-${i}`), assigned);
      await assertSucceeds(batch.commit());
    });

    it('예약·PT권의 담당은 같은 센터의 승인된 트레이너로, 실제 이름으로만 바꾼다', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'pt_sessions', 's-1'), {
          id: 's-1', centerId, trainerId, trainerName: '트레이너', memberId, memberName: '회원',
          scheduledAt: new Date(), durationMinutes: 50, note: '', status: 'scheduled',
          createdAt: new Date(), updatedAt: new Date(),
        });
      });
      const db = authedDb(adminId);
      const move = (id, name) => updateDoc(doc(db, 'pt_sessions', 's-1'), {
        trainerId: id, trainerName: name, updatedAt: serverTimestamp(),
      });
      await assertFails(move(pendingTrainerId, '대기 트레이너'));
      await assertFails(move('no-such-trainer', '누구'));
      await assertFails(move(trainerId, '꾸민 이름'));
      await assertSucceeds(move(trainerId, '트레이너'));

      await assertFails(updateDoc(doc(db, 'pt_infos', ptInfoId), { trainerId: pendingTrainerId, updatedAt: serverTimestamp() }));
      await assertSucceeds(updateDoc(doc(db, 'pt_infos', ptInfoId), { trainerId, updatedAt: serverTimestamp() }));
    });
  });
});
