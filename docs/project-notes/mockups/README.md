# 시안 모음

2026-10-10 ~ 10-13에 만든 화면 시안이다. 브라우저로 열면 된다 (글꼴이 파일 안에 들어 있어 인터넷이 없어도 열린다). 이미지가 필요한 두 파일은 `img/` 폴더를 함께 둬야 한다.

| 파일 | 내용 | 정한 것 | 앱에 반영 |
|---|---|---|---|
| `01-login.html` | 로그인 재디자인 A~D안 | D안 바탕에 C안(다시 오신 계정 카드)을 얹고, 로고 빼고 가운데 정렬 | `lib/screens/login_screen.dart` |
| `02-register.html` | 가입 재디자인 | 가안(단계형: 역할 → 센터 → 계정 → 확인) | `lib/screens/register_flow_screen.dart` |
| `03-exercise-guide.html` | 종목 설명 화면 (근육 그림 + 운동 방법) | 근육 그림은 `muscle_map` 패키지, 운동 방법은 공개 운동 자료 묶음(free-exercise-db)을 옮겨 앱 안에 둔다 | `lib/widgets/exercise_guide_sheet.dart`, `lib/core/exercise_guide_data.dart` (2026-10-11. 종목 248개 전부, 운동 방법은 검수 전) |
| `04-trainer-meal-feed.html` | 트레이너 식단 피드 | 아래 탭 '식단' 추가, 회원 버튼에 '피드백할 수'와 '새 식단 점'을 따로, 카드에서 바로 피드백 | `lib/screens/trainer/trainer_meal_feed_screen.dart`, `lib/widgets/meal_feed.dart` |
| `05-pt-remaining-card.html` | PT 남은 횟수 표시 정리 | A안 — 자세한 카드는 PT 탭에만, 마이는 'PT 이용권 · N회 남음' 한 줄 | `member_pt_schedule_screen.dart`, `member_profile_screen.dart` |
| `06-app-icon.html` | 앱 아이콘 시안 (별자리 계열 + 다른 방향 16가지) | '기울인 아령', 앱 이름 REFIT, 스플래시 마크 없음 | `assets/icon/` |
| `07-app-icon-dot-color.html` | 아이콘 안쪽 점 색 | 세 번째 — 안쪽 점 진한 주황 | `assets/icon/icon.png` |
| `08-trainer-members-tab.html` | 트레이너 '회원' 탭 (아래 탭 홈 · 일정 · 회원 · 식단 · 마이) + 회원 이름을 눌러 회원 상세로 가는 길 (식단 피드 · PT 기록 · 일정 ⋯) + 식단 목표 화면 지금 · 정리안 비교 + 식단 탭에 목표 잇기(지금 · 정리안, 회원별 5가지 경우 — 2026-10-13 반영, `trainer_meal_feed_screen.dart` · `NutritionGoalStrip`). 주소 끝 `#v=npNew`처럼 화면을 골라 열 수 있다 | 그대로 — 탭 점 없음 · 알약 4개 · 피드백할 식단이 있으면 식단 탭으로 열기. 식단 목표는 정리안 (반경은 토큰 18) | `trainer_members_screen.dart`, `trainer_home_screen.dart`, `nutrition_plan_screen.dart` |
| `09-consent-roster-feedback.html` | 가입 동의(필수 · 건강 정보 따로) · 엑셀 명단을 휴대폰 번호로 가입 계정과 잇기(가입 휴대폰 · 명단 올리기 · 미가입 목록 · 가입 요청 '명단과 일치') · 트레이너 '보낸 피드백' 목록 | 건강 정보 동의 필수 · 휴대폰 필수 · 표준 동의서 형식에 앱 실제 내용 | 동의 · 가입 휴대폰 반영 (`register_flow_screen.dart`, `consent_screen.dart`). 보낸 피드백 반영 (`trainer_sent_feedback_screen.dart`). 명단 반영 (`admin_roster_screen.dart`, `admin_roster_upload_screen.dart`, 가입 요청 '명단과 일치') — 회원 · 트레이너 탭 '명단 업로드' + '미가입' 알약 (시안대로, 탭마다 그 구분만 올림). 양식 내려받기 · 줄 고치기 · 직접 잇기는 **아직** |

`img/motif.png`는 아이콘 모티브로 삼은 sharing-gallery 앱 아이콘이다.
