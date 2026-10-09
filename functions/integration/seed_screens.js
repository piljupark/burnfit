// 화면 투어(integration_test/screen_tour_test.dart)용 예시 데이터를 로컬 에뮬레이터에 넣는다.
// 실제 Firebase에는 절대 쓰지 않도록 에뮬레이터 주소가 없으면 멈춘다.
//
// 실행: firebase emulators:start --project burnfit-v01 --only auth,firestore,storage,functions
//       (다른 터미널) cd functions && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
//         FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=burnfit-v01 node integration/seed_screens.js
// 계정: member@burnfit.test / trainer@burnfit.test / admin@burnfit.test,
//       pending@burnfit.test(승인 대기) / newbie@burnfit.test(온보딩 전), 비밀번호 password123

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.error('에뮬레이터 주소(FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST)가 없어 중단합니다.');
  process.exit(1);
}

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'burnfit-v01' });
const db = getFirestore();
const auth = getAuth();

const PASSWORD = 'password123';
const CENTER = { id: 'center-gangnam', name: '강남 센터' };
const now = new Date();
const ts = (d) => Timestamp.fromDate(d);
const day = (offset, h = 9, m = 0) => {
  const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset, h, m);
  return d;
};
const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const share = { workout: true, meal: true, body: true };

function userDoc({ uid, email, name, role, status = 'approved', trainer = null, birthDate = null, gender = null, profile = null }) {
  return {
    uid, email, name, role, status,
    centerId: CENTER.id, centerName: CENTER.name,
    trainerId: trainer ? trainer.uid : null, trainerName: trainer ? trainer.name : null,
    birthDate, gender, profile, shareSettings: share,
    createdAt: ts(day(-120)), updatedAt: ts(day(-1)),
  };
}

async function authUser(email, name) {
  try {
    return (await auth.getUserByEmail(email)).uid;
  } catch {
    return (await auth.createUser({ email, password: PASSWORD, displayName: name })).uid;
  }
}

async function main() {
  const adminUid = await authUser('admin@burnfit.test', '박관리');
  const trainerUid = await authUser('trainer@burnfit.test', '김도윤');
  const memberUid = await authUser('member@burnfit.test', '이민지');
  // 승인 대기 화면·온보딩 화면 확인용 계정
  const pendingUid = await authUser('pending@burnfit.test', '최대기');
  const newbieUid = await authUser('newbie@burnfit.test', '신입회원');
  const trainer = { uid: trainerUid, name: '김도윤' };
  const others = [
    { uid: 'member-seojun', name: '박서준', email: 'seojun@example.com' },
    { uid: 'member-haneul', name: '정하늘', email: 'haneul@example.com' },
  ];

  const batch = db.batch();
  const set = (path, data) => batch.set(db.doc(path), data);

  set(`centers/${CENTER.id}`, { id: CENTER.id, name: CENTER.name, address: '서울 강남구 테헤란로 123', adminId: adminUid, status: 'active', createdAt: ts(day(-200)) });
  // 센터 선택 시트용 다른 센터들 (시안 Com-CenterPicker)
  for (const [id, name, address] of [
    ['center-yeoksam', '역삼 센터', '서울 강남구 역삼로 45'],
    ['center-seolleung', '선릉 센터', '서울 강남구 선릉로 210'],
    ['center-pangyo', '판교 센터', '경기 성남시 분당구 판교역로 8'],
    ['center-jamsil', '잠실 센터', '서울 송파구 올림픽로 300'],
  ]) {
    set(`centers/${id}`, { id, name, address, adminId: adminUid, status: 'active', createdAt: ts(day(-200)) });
  }
  set(`users/${adminUid}`, userDoc({ uid: adminUid, email: 'admin@burnfit.test', name: '박관리', role: 'admin' }));
  set(`users/${trainerUid}`, userDoc({ uid: trainerUid, email: 'trainer@burnfit.test', name: '김도윤', role: 'trainer' }));
  set(`users/${memberUid}`, userDoc({
    uid: memberUid, email: 'member@burnfit.test', name: '이민지', role: 'member', trainer,
    birthDate: '19980312', gender: 'female',
    profile: { height: 165, weight: 68.2, muscleMass: 31.4, bodyFat: 12.4, goal: '체지방률 15%' },
  }));
  for (const o of others) {
    set(`users/${o.uid}`, userDoc({ uid: o.uid, email: o.email, name: o.name, role: 'member', trainer, birthDate: '19950101', gender: 'male' }));
  }
  set(`users/${pendingUid}`, userDoc({ uid: pendingUid, email: 'pending@burnfit.test', name: '최대기', role: 'member', status: 'pending' }));
  set(`users/${newbieUid}`, userDoc({ uid: newbieUid, email: 'newbie@burnfit.test', name: '신입회원', role: 'member' }));
  set('users/member-seoyun', userDoc({ uid: 'member-seoyun', email: 'seoyun@example.com', name: '한서윤', role: 'member', birthDate: '20000505', gender: 'female' }));
  // 가입 신청 대기
  for (const [uid, name, role] of [['pending-seojun', '이서준', 'member'], ['pending-jihoon', '이지훈', 'trainer']]) {
    set(`users/${uid}`, userDoc({ uid, email: `${uid}@example.com`, name, role, status: 'pending' }));
    set(`join_requests/req-${uid}`, {
      id: `req-${uid}`, userId: uid, userName: name, userEmail: `${uid}@example.com`,
      centerId: CENTER.id, centerName: CENTER.name, role, status: 'pending', createdAt: ts(day(-1)),
    });
  }

  // 공지 (관리자 공지 목록·상세 화면용). 알림은 보내지 않게 notify는 끈다.
  const notice = (id, title, body, extra) => set(`notices/${id}`, {
    centerId: CENTER.id, authorId: adminUid, title, body, audience: 'all',
    pinned: false, important: false, notify: false,
    createdAt: ts(day(-1, 14, 10)), updatedAt: ts(day(-1, 14, 10)), ...extra,
  });
  notice('notice-holiday', '추석 연휴 운영 시간 안내',
    '추석 연휴 기간 센터 운영 시간이 바뀌어요.\n10월 4일 (토) ~ 10월 6일 (월): 휴관\n10월 7일 (화): 10:00 ~ 18:00',
    { pinned: true, important: true });
  notice('notice-gx', '10월 GX 시간표 변경', '10월부터 저녁 GX 시간이 30분 늦춰져요.',
    { audience: 'member', createdAt: ts(day(-7)), updatedAt: ts(day(-7)) });

  // PT 정보
  const ptInfo = (id, m, total, remaining, end) => set(`pt_infos/${id}`, {
    id, centerId: CENTER.id, memberId: m.uid, memberName: m.name, trainerId,
    startDate: ts(day(-180)), endDate: ts(end), totalSessions: total, remainingSessions: remaining,
    renewalDate: ts(end), createdAt: ts(day(-180)), updatedAt: ts(day(-1)),
  });
  const trainerId = trainerUid;
  ptInfo('pt-minji', { uid: memberUid, name: '이민지' }, 30, 12, day(85));
  ptInfo('pt-seojun', others[0], 20, 2, day(6));
  ptInfo('pt-haneul', others[1], 30, 6, day(41));

  // PT 세션
  const session = (id, m, offset, h, status, note = null) => set(`pt_sessions/${id}`, {
    id, centerId: CENTER.id, trainerId, trainerName: '김도윤', memberId: m.uid, memberName: m.name,
    scheduledAt: ts(day(offset, h)), durationMinutes: 50, note, status,
    createdAt: ts(day(offset - 3)), updatedAt: ts(day(offset - 1)),
  });
  const minji = { uid: memberUid, name: '이민지' };
  session('s-today-haneul', others[1], 0, 9, 'completed');
  session('s-today-seojun', others[0], 0, 11, 'scheduled');
  session('s-today-minji', minji, 0, 14, 'scheduled', '무릎 통증 체크');
  session('s-next-minji', minji, 2, 14, 'scheduled');
  session('s-next2-minji', minji, 6, 19, 'scheduled');
  session('s-past-minji', minji, -5, 14, 'completed');
  session('s-past2-minji', minji, -12, 14, 'completed');

  // 운동 기록 (회원 개인 + PT)
  const workout = (id, offset, type, category, exercises, minutes) => set(`workouts/${id}`, {
    id, centerId: CENTER.id, memberId: memberUid, memberName: '이민지', trainerId,
    workoutType: type, createdById: type === 'pt' ? trainerUid : memberUid,
    createdByRole: type === 'pt' ? 'trainer' : 'member', ptSessionId: type === 'pt' ? 's-past-minji' : null,
    workoutDate: ymd(day(offset)), category, exercises, note: null, hasFeedback: false, feedbackId: null,
    createdAt: ts(day(offset, 20)), updatedAt: ts(day(offset, 20)), durationSeconds: minutes * 60,
  });
  const sets = (w, r, n) => Array.from({ length: n }, () => ({ weight: w, reps: r }));
  workout('w-today', 0, 'personal', 'chest', [
    { name: '벤치프레스', sets: sets(60, 10, 4) },
    { name: '인클라인 덤벨 프레스', sets: sets(22, 12, 4) },
  ], 52);
  workout('w-2', -2, 'personal', 'lower', [{ name: '바벨 스쿼트', sets: sets(55, 8, 5) }], 48);
  workout('w-4', -4, 'personal', 'back', [{ name: '랫풀다운', sets: sets(40, 12, 4) }], 40);
  workout('w-pt', -5, 'pt', 'lower', [
    { name: '바벨 스쿼트', sets: sets(50, 10, 4) },
    { name: '루마니안 데드리프트', sets: sets(40, 10, 4) },
  ], 50);

  // 식단 + 피드백
  set('meals/meal-breakfast', {
    id: 'meal-breakfast', centerId: CENTER.id, memberId: memberUid, memberName: '이민지', trainerId,
    mealType: 'breakfast', mealDate: ymd(day(0)), mealTime: '08:10', imageUrls: [],
    description: '그릭요거트, 블루베리, 그래놀라', calories: 320, hasFeedback: true, feedbackId: 'fb-breakfast',
    createdAt: ts(day(0, 8, 15)), updatedAt: ts(day(0, 9)),
  });
  set('meals/meal-lunch', {
    id: 'meal-lunch', centerId: CENTER.id, memberId: memberUid, memberName: '이민지', trainerId,
    mealType: 'lunch', mealDate: ymd(day(0)), mealTime: '12:40', imageUrls: [],
    description: '현미밥, 닭가슴살, 브로콜리', calories: 920, hasFeedback: false, feedbackId: null,
    createdAt: ts(day(0, 12, 45)), updatedAt: ts(day(0, 12, 45)),
  });
  set('feedbacks/fb-breakfast', {
    id: 'fb-breakfast', centerId: CENTER.id, trainerId, trainerName: '김도윤', memberId: memberUid, memberName: '이민지',
    targetType: 'meal', targetId: 'meal-breakfast', targetDate: ymd(day(0)),
    content: '단백질 구성 좋아요. 점심엔 탄수화물을 조금 더 챙겨 주세요.', readAt: null,
    createdAt: ts(day(0, 9, 2)), updatedAt: ts(day(0, 9, 2)),
  });
  set('feedbacks/fb-workout', {
    id: 'fb-workout', centerId: CENTER.id, trainerId, trainerName: '김도윤', memberId: memberUid, memberName: '이민지',
    targetType: 'workout', targetId: 'w-2', targetDate: ymd(day(-2)),
    content: '스쿼트 깊이가 좋아졌어요. 다음엔 55kg로 5세트 가봅시다.', readAt: ts(day(-1)),
    createdAt: ts(day(-2, 21)), updatedAt: ts(day(-2, 21)),
  });

  // InBody
  const inbody = (id, offset, weight, muscle, fatPct) => set(`inbodies/${id}`, {
    id, centerId: CENTER.id, memberId: memberUid, memberName: '이민지', trainerId,
    measurementDate: ymd(day(offset)), weight, muscleMass: muscle, bodyFat: +(weight * fatPct / 100).toFixed(1),
    bodyFatPercent: fatPct, bmi: +(weight / (1.65 * 1.65)).toFixed(1), bmr: 1380, visceralFat: 5,
    leftArm: null, rightArm: null, trunk: null, leftLeg: null, rightLeg: null,
    createdAt: ts(day(offset)), updatedAt: ts(day(offset)),
  });
  inbody('ib-1', -150, 70.6, 30.2, 21.4);
  inbody('ib-2', -120, 70.1, 30.4, 20.9);
  inbody('ib-3', -90, 69.8, 30.6, 20.4);
  inbody('ib-4', -60, 69.4, 30.8, 20.0);
  inbody('ib-5', -9, 68.2, 31.4, 18.2);

  // 알림함
  const note = (uid, id, type, title, body, offsetMin, read) => set(`users/${uid}/notifications/${id}`, {
    type, title, body, targetId: null,
    createdAt: ts(new Date(now.getTime() - offsetMin * 60000)), readAt: read ? ts(now) : null,
  });
  note(memberUid, 'n1', 'feedback_created', '김도윤 트레이너가 피드백을 남겼습니다', '식단 기록에 새 피드백: 단백질 구성 좋아요.', 35, false);
  note(memberUid, 'n2', 'pt_session_created', 'PT 일정이 등록됐습니다', '김도윤 트레이너 · 10월 9일 오후 2:00 · 50분', 60 * 26, true);
  note(trainerUid, 'n3', 'pt_remaining_warning', '박서준님 PT 잔여 횟수 알림', 'PT 잔여 횟수가 2회 남았습니다. 갱신을 확인해주세요.', 90, false);

  await batch.commit();
  console.log('seeded', { adminUid, trainerUid, memberUid });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
