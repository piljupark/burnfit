# BurnFit — 피트니스 센터 관리 솔루션

Flutter 기반 멀티테넌트 피트니스 센터 관리 앱. 회원, 트레이너, 관리자 3개 역할로 구성.

---

## 앱 개요

| 항목 | 내용 |
|------|------|
| 플랫폼 | iOS 기준 (Android/Web 지원) |
| 상태관리 | Provider |
| 백엔드 | Firebase (Auth, Firestore, Storage, FCM) |
| 디자인 | Dark Mode, Material 3, iOS Liquid Glass (네비게이션/모달) |
| 언어 | 한국어 (추후 i18n 구조 확장 예정) |

---아니 

## 사용자 역할 및 권한

### 회원 (Member)
- 개인 운동 기록 (CRUD)
- 식단 기록 + 사진 업로드 (CRUD)
- 유산소 운동 기록 (CRUD)
- PT 세션 일정 확인 (열람만)
- PT 운동 기록 열람 (열람만, 트레이너가 기록)
- 트레이너 피드백 확인
- 본인 프로필 / InBody 히스토리 확인
- 월별 / 일별 기록 조회

### 트레이너 (Trainer)
- 담당 회원 목록 관리
- PT 세션 일정 등록/수정/삭제 → 회원 앱 자동 반영 + 푸시 알림
- PT 세션 중 운동 기록 (트레이너만 입력, 회원은 열람)
- 담당 회원의 개인 운동 / 식단 기록 열람 (자동 공유)
- 회원별 피드백 작성 (댓글 형태, meal/workout/cardio/general)
- 회원별 InBody 데이터 입력 및 히스토리 관리
- 회원 신체 프로필 / 운동 현황 / InBody 그래프 열람

### 관리자 (Admin)
- 전체 회원 / 트레이너 목록 열람 및 관리
- 회원 PT 정보 관리 (시작일, 종료일, 잔여 횟수, 갱신일)
- 회원-트레이너 배정 관리
- 가입 신청 승인 / 거절
- 센터 전체 현황 대시보드

> 멀티테넌트 구조: 모든 데이터는 `centerId` 기준으로 격리되며, 역할별 Firestore 보안 규칙으로 접근 권한 엄격 적용.

---

## 개발 로드맵

### Phase 1 — 핵심 미완성 기능 완성 ← 현재
- [ ] `trainer_pt_workout_screen.dart` 구현 (PT 세션 중 운동 기록)
- [ ] InBody 입력 화면 신규 구현 (트레이너 직접 입력)
- [ ] InBody 히스토리 & 그래프 화면 신규 구현

### Phase 2 — PT 일정 & 알림
- [ ] 트레이너 PT 일정 등록 → 회원 캘린더 자동 반영
- [ ] Firebase Cloud Messaging (FCM) 푸시 알림 연동
- [ ] 알림 종류: PT 일정 등록/변경, 트레이너 피드백, PT 잔여 횟수 경고

### Phase 3 — 데이터 시각화 & 분석
- [ ] 회원 운동 통계 (주간/월간 볼륨, 카테고리별 분포)
- [ ] InBody 추이 그래프 (체중/근육량/체지방 변화)
- [ ] 관리자 대시보드 통계 (센터 전체 현황, 회원별 출석률)

### Phase 4 — UI/UX 고도화
- [ ] iOS Liquid Glass 적용 (네비게이션 바, 모달, 바텀시트)
- [ ] iOS 기준 UI 전체 통일 (Cupertino 스타일)
- [ ] i18n 구조 준비 (intl 기반, 번역은 추후)

### Phase 5 — 보안 & 안정성
- [ ] Firestore 보안 규칙 역할별 엄격 적용
- [ ] 서비스 레이어 입력값 검증 강화
- [ ] 오프라인 캐시 전략 정리

### Phase 6 — AI 기능 추가 (추후)
- [ ] InBody 결과지 사진 → Claude Vision API OCR 자동 파싱
- [ ] 식단 사진 → Claude Vision + 식품안전처 API 칼로리/영양소 자동 인식
- [ ] Nutrition5k 기반 자체 모델 검토 (한국 음식 데이터 추가 학습 후 TFLite 변환)

---

## AI 기능 설계 방향

### InBody OCR (Phase 6)
- 방식: Claude Vision API로 결과지 사진 파싱
- 현재: 트레이너 직접 수동 입력 (API 연동 대비 구조 오픈)

### 식단 영양소 인식 (Phase 6)
- 방식: Claude Vision API (음식명 인식) + 식품안전처 공공 API (영양성분 조회)
- 현재: 사진 업로드 + 칼로리 수동 입력
- 장기 검토: Nutrition5k (CVPR 2021) 기반 온디바이스 모델 (한국 음식 데이터 확보 필요)

---

## 데이터 구조 (Firestore Collections)

```
users/           # 회원, 트레이너, 관리자 통합 (role 필드로 구분)
centers/         # 피트니스 센터 (멀티테넌트 기준 단위)
join_requests/   # 가입 신청 (관리자 승인 대기)
workouts/        # 운동 기록 (personal / pt 구분)
meals/           # 식단 기록 + Firebase Storage 이미지
cardios/         # 유산소 운동 기록
feedbacks/       # 트레이너 피드백 (meal/workout/cardio/general)
pt_sessions/     # PT 세션 일정
pt_infos/        # PT 패키지 정보 (잔여 횟수, 갱신일 등)
inbodies/        # InBody 측정 기록
custom_exercises/ # 회원별 커스텀 운동 종목
```

---

## 프로젝트 구조

```
lib/
├── core/          # 테마, 색상, 상수, 검증
├── models/        # 데이터 모델 (11개)
├── services/      # 비즈니스 로직 / Firebase 연동 (8개)
├── screens/
│   ├── member/    # 회원 화면
│   ├── trainer/   # 트레이너 화면
│   └── admin/     # 관리자 화면
└── widgets/       # 공통 재사용 위젯
```

---

## 개발 원칙

- **보안**: 역할별 데이터 접근 권한 엄격 적용, Firestore 보안 규칙 필수
- **CRUD 일관성**: 모든 기능은 생성/조회/수정/삭제 흐름 완전 구현
- **데이터 검증**: 서비스 레이어에서 입력값 검증, 경계값 처리
- **UI 통일성**: 역할 무관하게 동일한 디자인 시스템 적용
- **재사용성**: 공통 위젯 우선 활용, 중복 코드 최소화
- **확장성**: AI 기능 등 추후 연동을 고려한 서비스 레이어 구조
