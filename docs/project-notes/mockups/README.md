# 시안 모음

2026-10-10 ~ 10-11에 만든 화면 시안이다. 브라우저로 열면 된다 (글꼴이 파일 안에 들어 있어 인터넷이 없어도 열린다). 이미지가 필요한 두 파일은 `img/` 폴더를 함께 둬야 한다.

| 파일 | 내용 | 정한 것 | 앱에 반영 |
|---|---|---|---|
| `01-login.html` | 로그인 재디자인 A~D안 | D안 바탕에 C안(다시 오신 계정 카드)을 얹고, 로고 빼고 가운데 정렬 | `lib/screens/login_screen.dart` |
| `02-register.html` | 가입 재디자인 | 가안(단계형: 역할 → 센터 → 계정 → 확인) | `lib/screens/register_flow_screen.dart` |
| `03-exercise-guide.html` | 종목 설명 화면 (근육 그림 + 운동 방법) | 근육 그림은 `muscle_map` 패키지, 운동 방법은 공개 운동 자료 묶음(free-exercise-db)을 옮겨 앱 안에 둔다 | **아직** (2단계로 미룸. 2026-10-11 다시 확인 — 운동 기록 개선 다음 작업으로) |
| `04-trainer-meal-feed.html` | 트레이너 식단 피드 | 아래 탭 '식단' 추가, 회원 버튼에 '피드백할 수'와 '새 식단 점'을 따로, 카드에서 바로 피드백 | `lib/screens/trainer/trainer_meal_feed_screen.dart`, `lib/widgets/meal_feed.dart` |
| `05-pt-remaining-card.html` | PT 남은 횟수 표시 정리 | A안 — 자세한 카드는 PT 탭에만, 마이는 'PT 이용권 · N회 남음' 한 줄 | `member_pt_schedule_screen.dart`, `member_profile_screen.dart` |
| `06-app-icon.html` | 앱 아이콘 시안 (별자리 계열 + 다른 방향 16가지) | '기울인 아령', 앱 이름 REFIT, 스플래시 마크 없음 | `assets/icon/` |
| `07-app-icon-dot-color.html` | 아이콘 안쪽 점 색 | 세 번째 — 안쪽 점 진한 주황 | `assets/icon/icon.png` |

`img/motif.png`는 아이콘 모티브로 삼은 sharing-gallery 앱 아이콘이다.
