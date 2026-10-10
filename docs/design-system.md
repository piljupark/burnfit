# BurnFit 디자인 시스템

미니멀 · 한 가지 강조색(주황 #FF7A33) · 작은 움직임. 라이트(기본)·다크 두 테마.
기준: `BurnFit-디자인-시안/screens/*.html`. **목차 맨 위 '화면' 묶음(`Main`·`Workout`·`Done`·`Meal`·`My`, 트레이너 `Trainer*`, 관리자 `Admin*`)이 최우선 기준**이고(2026-10-08 결정), 그 묶음에 없는 화면은 역할별 상세 시안(`MemA-*`·`MemB-*`·`Tr-*`·`Ad-*`·`Com-*`·`Nt-*`)과 C0~C4 컴포넌트 스펙을 따른다. 값이 헷갈리면 시안 HTML의 숫자를 따른다.

## 원칙

1. **캔버스는 하나, 테마는 둘.** 모든 화면 바탕은 `AppColors.canvas`. 라이트(기본, #FFFFFF)와 다크(#0A0A0A)는 같은 구조에서 면·글자 색만 뒤집는다. 테마는 마이 → 계정 → '화면 테마'에서 시스템 설정 · 라이트 · 다크 중에 고르고 기기에 저장된다 (`ThemeController`).
2. **모서리는 토큰으로만.** 아이콘 상자 12 · 입력창·안내 줄·꽉 찬 중간 버튼 14 · 큰 버튼·토스트 18 · 카드 20 · 시트 28 · 칩·태그·작은 버튼 pill (`AppRadius`).
3. **굵기는 화면 계열을 따른다.** Wanted Sans 하나만 쓴다. 기본은 400·500(Medium) — 상세 시안(`MemA-*`·`MemB-*`·`Com-*`·`Nt-*`·`Tr-*`·`Ad-*`)의 500은 Medium이다. 기준 시안 `Main` 계열(회원 홈 오늘 보기·운동·운동 완료·식단·마이), 트레이너 기준 시안 `Trainer*`(홈 오늘 보기·일정·PT 예약 시트·회원 상세·PT 완료), 관리자 기준 시안 `Admin*`(홈·가입 요청·회원·회원 상세·대시보드)만 `font-weight:500` 자리에 Bold 글꼴을 묶어 두었으므로 그 화면 요소에만 `.bold`(700)를 붙인다. 관리자 탭 제목(`AppHero`)도 Bold. 시안의 `line-height: normal`은 `.natural`(1.193).
4. **화면 글자는 한글.** 영어 라벨(`DONE`, `10.07 WED`, `KCAL` 등)을 쓰지 않는다. 남기는 것: 단위(`kg`, `kcal`, `g` — 소문자), `PT`, `BMI`, `InBody`, 앱 이름. 날짜는 `10월 7일 (수)`, 달은 `2026년 10월`. 큰 수는 천 단위 쉼표(`11,440kg`).
5. **그림자 대신 면과 선.** 층은 면 색(`canvas` → `canvasCard`)과 1px `hairline`으로 나눈다. `BoxShadow`, gradient, elevation 금지.
6. **강조색은 주황 하나.** 주 행동 채움(`primary`)과 눈에 띄어야 할 데이터 점(캘린더 PT 표시, 토글 on, 그래프 최신값)에 쓴다. "새 글"·"새 알림" 점은 `newDot`(#FF5A1F). 안내·경고·PT 강조 줄은 연한 주황 면 `noticeBg` + 진한 주황 글자 `noticeText`. 역할·성별 같은 **선택 pill**은 주황이 아니라 검정(`ink`) 채움.
7. **빨강(`danger`)은 되돌릴 수 없는 행동의 글자에만.** 빨간 채움 배경은 쓰지 않는다. 파괴적 확정 버튼은 검정 채움(`AppButtonVariant.dark`).
8. **주 행동은 화면당 하나.** 주황 채움(`AppButton` primary)은 화면당 한 번. 나머지는 회색 채움(`secondary`)이나 글자(`ghost`).
9. **움직임은 시안 키프레임대로.** 공용 도구 `lib/widgets/app_motion.dart`(`AppEntrance`·`AppEntrance.slide`·`AppPulse`·`AppBlink`·`AppGrow`·`AppPop`·`AppShake`, 곡선 `AppMotion.sheet/fill/dialog/pop/knob`)와 움직이는 그림 `brand_marks.dart`를 쓴다. 시트 450ms·확인 창 300ms·토스트 450ms. 로딩은 점 세 개(`AppLoader`). 시안의 시연용 무한 반복(토스트 오르내림, 자동 밀기 등)은 실제 동작으로 대신한다. 기기의 '동작 줄이기'가 켜져 있으면 모두 끝 상태로 멈춘다.
10. **아이콘은 Phosphor 하나.** `AppIcons.*` (없으면 `PhosphorIconsRegular.*`). 기본은 Regular(선 1.5 — 시안 아이콘 선 1.8~2에 가장 가깝다), 켜진 상태만 Fill, 줄 끝·월 이동 화살표와 작은 체크는 Bold. Material `Icons.*`·이모지 금지.

## 토큰 (`lib/core/`)

| 용도 | 토큰 | 라이트 값 |
|---|---|---|
| 바탕 | `canvas` | #FFFFFF |
| 카드·시트·아이콘 상자·바로가기 면 | `canvasCard` | #F6F6F7 |
| 입력창·눌림 | `canvasSoft` | #F3F3F5 |
| 진행 막대 바탕·손잡이 | `canvasMid` | #D4D4D8 |
| 1px 테두리·목록 줄 구분선 | `hairline` | #F0F0F2 |
| 회색 카드 안 세로 구분선 | `line` | #EAEAEC |
| 외곽선 버튼 테두리 | `outline` | #D4D4D8 |
| 기본 글자·아이콘 | `ink` | #191919 |
| 보조 본문 (캔버스·카드 모두) | `body` | #4A4A4A |
| 캡션 (캔버스 위에서만) | `mute` | #6B6B70 |
| 비활성 탭 글자·아이콘 | `faint` | #9A9AA0 |
| 목록 줄 끝 화살표 | `chevron` | #B0B0B5 |
| 주 행동 채움 / 그 위 글자 | `primary` / `onPrimary` | #FF7A33 / #191919 |
| 파괴적 행동 글자 | `danger` | #D93036 |
| 안내 줄 면 / 글자 (두 테마 공통) | `noticeBg` / `noticeText` | #FFF1E8 / #A8400E |
| 새 소식 점 (두 테마 공통) | `newDot` | #FF5A1F |
| 완료 화면 빛줄기 (두 테마 공통) | `illustBurst` | #FFB020 |
| 차트 계열 구분 | `chartSeries` | — |

**두 테마 공통 면(`noticeBg` 등) 위의 글자는 테마 색(`ink`)을 쓰지 않는다** — 다크에서 흰 글자가 된다. 검정이 필요하면 `AppPalette.light.ink`.

글자: `displayLg`(40) · `displayMd`(28, 탭 제목) · `sheetTitle`(22/500, 시트 제목) · `title`(20, 앱바·확인 창) · `section`(17/500, 섹션·날짜 머리말, 월 이름) · `bodyLg`(17) · `listTitle`(16/500, 목록 줄 제목) · `input`(16, 입력 글자) · `bodyMd`(15) · `fieldLabel`(14 mute, 입력 라벨) · `note`(14/21 body) · `buttonLabel`(14) · `bodySm`(13 mute) · `badge`(11/500) · `eyebrow`(15 mute, 섹션 개수) · `counter`(13 mute). Main 계열 화면은 `.bold`.

간격: 2 · 4 · 8 · 12 · 16 · 20(화면 좌우 `screenH`) · 24 · 32 · 48 · 64. 크기: `AppSize.touchMin` 44, 목록 한 줄 `AppSize.listRow` 56, 목록 맨 아래 여백 `AppSize.navClearance`, 버튼 32/40/56, 아이콘 20, 탭 아이콘 26.

**이니셜 원(아바타)은 쓰지 않는다.** 사람은 이름 글자로만 보여준다.

`Color(0x…)` 직접 쓰기 금지 — 토큰을 쓴다. 토큰 값은 `AppPalette.dark` / `AppPalette.light`에 있다.

**토큰은 테마에 따라 바뀌므로 `const` 안에서 쓸 수 없다** (`const BoxDecoration(color: AppColors.ink)` ✕). 색 기본값이 필요한 매개변수는 `Color?`로 받고 쓰는 곳에서 `?? AppColors.ink`. 사진 위 덮개(`scrim`·`dim`·`select`·`backdrop`)와 `noticeBg`·`noticeText`·`newDot`·`flameCore`는 두 테마 공통 상수다.

## 컴포넌트 (`lib/widgets/`)

| 컴포넌트 | 쓰임 |
|---|---|
| `AppHero` | 탭 화면 상단: 오른쪽 아이콘 버튼 줄 + 28 제목. (시안은 제목과 아이콘이 한 줄 — 회원 홈은 `_HomeHeader`로 옮겼고, 다른 탭은 아직) |
| `AppScreenHeader` | 하위 화면 앱바: 뒤로 + 20 제목 + 오른쪽 행동. (시안은 가운데 17/700 제목 — 회원 식단·운동은 옮겼고, 다른 화면은 아직) |
| `AppMonthHeader` | 화면 폭 섹션 머리말: 라벨 + 개수. (시안은 17/700 ink 라벨 + 오른쪽 끝 15 mute 개수 — 회원 홈은 `_DayHeader`로 옮겼고, 다른 화면은 아직) |
| `AppSectionHeader` | 여백 있는 열 안의 섹션 머리말 (+ 오른쪽 글자 행동) |
| `AppActionRow` + `AppRowDivider` | 목록·메뉴 한 줄: 아이콘 상자 + 라벨 + 보조 줄 + 오른쪽(태그/화살표). 목록은 카드로 감싸지 말고 hairline으로 나눈다. `menu: true`는 마이 탭 메뉴 줄(60 · 16 Regular, 시안 Tr-My·Ad-My) |
| `AppViewTabs` · `AppMonthNav` · `AppNavArrow` · `AppCalendarGrid` · `AppWeekDay` (`app_calendar.dart`) | 회원·트레이너 공용: 보기 고르기 pill(40, `compact` 38 — 회원 상세 탭, 위아래 누름 자리로 터치 44), 월 이동, 월·주 이동 화살표(44), 한 달 달력(46 칸 · 32 원), 주간 날짜 칸(요일 12 · 32 원 · 아래 자리 바꿔 끼움 — 회원 홈 이번 주·트레이너 홈 이번 주·일정 주간 줄). 달력 아래 띠는 `AppSectionBand(top: 20)`, 고른 날 머리말은 `AppMonthHeader(strong: true)`. 날짜 글자는 `appDayLabel` |
| `AppIconBox` | 40 둥근 사각형(반경 12) + `canvasCard` 면, 아이콘 20. PT 운동처럼 강조할 줄만 `noticeBg` + `noticeText` |
| `AppTag` / `StatusBadge` | 상태 글자 (strong / 기본 / muted / danger) |
| `AppChip` / `AppScrollableChips` / `AppFilterTabs` | 필터·선택 pill |
| `AppCountBadge` | 사진 위 카운터 (`+2`) |
| `SetValueField` · `SetDoneButton` (`set_input.dart`) | 세트 값 상자·완료 원. `card`(회색 카드 안 흰 상자), `bold: false`(상세 시안 Tr-PtRecord 17/500), `outlineHighlighted`(진행 중 줄 안쪽 1.5 ink 테두리) |
| `AppButton` | primary(주황) / secondary(회색 채움) / ghost / dark(파괴적 확정, 기준 시안의 검정 버튼 — 회원 상세 '피드백 쓰기') / danger / dangerText, sm 32 · md 40 · lg 56. 하단 고정 바 `AppBottomActionBar`(`primaryVariant`·`bold`), 빈 상태 행동 버튼 `AppEmptyState(actionVariant:)` |
| `AppIconButton` | 44 터치 영역 아이콘 버튼 (`label` 필수, `showDot`, `iconSize` 기본 20 — 알림 종은 24) |
| `AppTextField` | 라벨(13 body) 위 + 입력창 |
| `AppCard` | canvasCard + hairline (그림자 없음). 목록 대신 한 덩어리 정보에만 |
| `AppKpiCard` / `AppStatStrip` / `AppStatGrid` | 숫자 칸 |
| `AppHighlightCard` | 주황 강조 카드 (PT 잔여 횟수 등). `bold`(기준 시안 계열 — 회원 마이 · 트레이너 홈 오늘 PT), `compact`(2칸 작은 카드 — 트레이너 회원 상세), `semanticLabel`. 막대는 `AppProgressBar` |
| `AppProfileRow` / `AppProfileCard` | 마이 탭 맨 위 프로필 줄 / 관리자 회원 상세 머리 |
| `showAppBottomSheet` + `AppBottomSheetHeader` + `AppSheetAction` | 하단 시트, 시트 안 행동 줄 |
| `AppEmptyState` | 그림 + 20 제목 + 설명 + (선택) 주 행동 — 화면 전체가 빈 경우 |
| `AppEmptyLine` | 목록 자리의 짧은 빈 상태 한 줄: 52 높이, 14 mute ("이 날의 기록이 없습니다") |
| `AppEmptyState(compact:)` | 작은 빈 상태 (시안 Ad-*-Empty): 아이콘 48 faint가 떠다니고(-5, 2.6s) 12 아래 17/500 제목, 위 여백 `top` |
| `AppListRow` · `AppDateCell` (`app_action_row.dart`) | 아이콘 상자 없는 두 줄 목록 줄 (관리자 회원·트레이너·탈퇴·이력): 68/64/60 · 제목 16/500 · 보조 13 mute · 셋째 줄 `note` · 오른쪽 상태 글자 또는 18 Bold 화살표, 아래 선은 좌우 20 안쪽(마지막 줄 포함). 왼쪽 날짜 칸 52(위 16/500 · 아래 12 mute) |
| `AuthHeading` · `AuthTextLink` (`auth_parts.dart`) | 로그인·가입 공용: 로고 없는 가운데 제목 28 + 설명 15 body, 아래 글자 링크 48('처음이에요 · 가입하기' — 15 body · 점 faint · 15/500 ink, 한 줄) |
| `AppAccentBar` | 강조 띠 64 (관리자 홈 '가입 요청 3건'): 주황 · 반경 18 · 아이콘 24 · 17/500 · '확인하기' 15/500 · 18 Bold 화살표. `muted`(회색, 할 일 없음) · `ring`(종 흔들림) · `bold` |
| `AppRing` · `AppRankBar` · `AppColumnChart` (`app_charts.dart`) | 대시보드 그래프: 완료율 고리 112(선 12 · 1.4s 차오름), 순위 가로 막대(6 · 바탕 navLine), 주별 세로 막대(반경 10 · 이번 주 주황) |
| `AppSwitch` · `AppSwitchRow` (`app_switch.dart`) | 시안 스위치 52×32(켜짐 primary), 스위치 줄 68(라벨 16 · 설명 13 mute, 줄 전체가 토글) — 공지 작성 |
| `AppFloat` · `AppRingShake` · `AppSpin` · `AppSway` (`app_motion.dart`) | 반복 움직임: 떠다님(빈 상태) · 종 흔들림 · 회전(다시 시도) · 좌우 기울임(공지 빈 상태 확성기) |
| `FeedbackSheet` · `FeedbackQuote` (`feedback_sheet.dart`) | 트레이너 피드백 작성 시트(같은 기록에 다른 — 이전 담당 — 트레이너 피드백이 있으면 위에 읽기 전용 '이전 피드백'), 피드백 상자(회색 · 반경 14 — 회원 식단 기록과 공용). 기록 하나에 피드백이 여러 개 남을 수 있다 |
| `AppKeyValueRow` | 52 키/값 줄 (라벨 15 body · 값 16/500 + 단위 mute) — 회원 상세 PT 정보, 인바디 상세 |
| `workout_parts.dart` | 회원·트레이너 운동 공용: `WorkoutPickerRow`(운동 고르기 줄) · `WorkoutExerciseMenuSheet` · `WorkoutSavedExerciseRow`(+ 유산소 요약 계산) · `WorkoutCollapsedRow` · `WorkoutSummaryStats`(요약 3칸) · 완료 화면 `DoneConfirmButton`·`DoneTextLink`. 차이는 매개변수(회원 모양이 기본) |
| `showAppConfirmDialog` | 확인 다이얼로그: 제목 + 설명 (+ 선택 `warning` 주황 콜아웃) + 2열 전체폭 버튼(취소 회색 · 확정 주황, 파괴적이면 검정). `showDialog`를 직접 쓰지 않는다 |
| `AppAsyncBody` / `AppLoadingView` / `AppLoader` | 로딩·오류·빈 상태. 로딩은 점 세 개(화면 6 / 줄 안 4) |
| `AppErrorCard`·`AppFeedback.show*`(`core/app_feedback.dart`) → `AppToast` | 오류 카드(시안 Ad-Home-Error — 회색 반경 18 · 경고 원 40 faint · 16/500 · 검정 44 '다시 시도' + 도는 새로고침, 모든 역할 공통), 토스트(검정 채움 + 주황 원 배지, **화면 위쪽**, 한 번에 하나). `SnackBar`·`ScaffoldMessenger`를 직접 쓰지 않는다 |
| `NoticeBanner` | 홈 공지 한 줄: 48 높이 `noticeBg`(반경 14) + 확성기 18 + '공지' + 제목 15 + 화살표 16 |
| `SplashFlameMark` / `PendingClockMark` | 스플래시 불꽃, 승인 대기 시계 (주황 원 브랜드 표시) |
| `AppNavBar` | 하단 탭: 위 10 + 아이콘 26 + 글자 11. 선택 = Fill + ink 700, 나머지 = Regular + `faint`. `dotIndexes`: 아이콘 오른쪽 위 새 소식 점 7 (트레이너 식단 — 피드백할 식단이 있을 때) |
| `MealFeedList` · `MealFeedCard` (`meal_feed.dart`) | 트레이너 식단 피드 (식단 탭 · 회원 상세 식단 탭 공용): 날짜 머리말(`AppMonthHeader` bold '오늘 · 3건') → 카드(회원 16/500 + 새 식단 점 6 · '끼니 · 시각' 13 mute · 오른쪽 '피드백 전' 13/500 noticeText / '보냄' mute → 정사각 사진 반경 20 넘겨 보기 + `AppCountBadge` '1/3' + 아래 점 → 칼로리 15/700 + 메모 15 → 피드백 상자(회색 반경 14, 이름 14/500 · 시각 12 + 내 것은 '읽음'/'안 읽음', 이전 담당은 테두리만) → 자주 쓰는 말 32 알약 → '피드백 남기기…' 44 알약 입력 + 보내기 원 44(글자 있으면 주황)), 카드 사이 hairline |
| `AppMenuGroup` · `AppActionRow(menu:, value:)` | 마이 탭 묶음 (세 역할 공통): 8 띠 → 머리말 15 mute(20 20 4) → 60 메뉴 줄(아이콘 상자 · 16 · 오른쪽 값 15 mute + 18 화살표), 줄 사이 안쪽 선, 차례로 들어옴. 공지 `NoticeMenuRow`(관리자는 `admin:`), 테마 `ThemeSettingRow`, 가운데 `DeleteAccountLink` |
| `RestTimer` / `RestTimerBar` / `showRestTimerSheet` | 앱 전체 휴식 타이머 하나. 세트 완료 시 그 운동의 휴식 시간으로 시작, 검정 64 막대(진행 고리 · '+30초' · '건너뛰기'). 운동 탭은 화면 안, 다른 탭은 탭 바 위에 뜬다 |
| `LiftingBarbellMark` | 빈 기록 카드의 들었다 내리는 바벨 (회원 운동·PT 기록, 트레이너 PT 기록) |
| `FlameIcon` · `MealBowlIllustration` | 홈 연속 운동 불꽃, 식단 안내 카드 그릇 그림 (`brand_marks.dart`) |

## 공용 부품 요약 (2026-10-08 시안 재대조 반영)

- 입력창 `AppTextField`: 52 · 16 글자 · 라벨 14 mute(간격 6) · 평소 테두리 없음 · 포커스 2px ink · 오류는 연한 주황 면 + 1.5 noticeText + '!' 문구(흔들림). `unit`·`labelHint`·`showCounter`·`strongValue`. 비밀번호 보기 단추(`showVisibilityToggle`)는 기본 없음 — 로그인·가입(비밀번호·관리자 설정 코드)에서만 켠다 (2026-10-10 결정).
- 시트 `showAppBottomSheet`: 손잡이 36×5, 위 10 · 머리까지 14, 뒤 덮개 40%, 올라옴 450ms. 머리 `AppBottomSheetHeader` 제목 22/500, 닫기 22 ink, 보조 줄 15 body 또는 `mutedSubtitle` 14 mute. 행동 줄 `AppSheetAction` 60 높이 · 아이콘 상자.
- 확인 창 `showAppConfirmDialog`: 흰 면 · 제목 20/500 · 버튼 `AppButtonSize.dialog`(52 · 반경 14 · 16) · 커지며 나타남.
- 토스트 `AppToast`: 좌우 16 · 최소 56 · #191919 · 15/500 흰 글자 · 주황 원 기호(`AppToastKind` success 체크 그리기 / error '!' / wait 시계).
- 머리 `AppScreenHeader.centered`(MemA·MemB 하위 화면, 가운데 17/500) · `AppScreenHeader.large`(가입·알림·공지 목록, 28/500 큰 제목). 기본(왼쪽 20)은 트레이너·관리자 화면.
- 목록: `AppActionRow`(68 · 아이콘 상자 40/12 · 16/500 · 화살표 18 chevron), `AppRowDivider.inset()`(좌우 20 안쪽), `AppSectionBand`(8 회색 띠), `AppMonthHeader`(개수 오른쪽 끝, `strong` 17/500, `bold` 17/700 + 개수 15/700), `AppEmptyState(card: true)`.
- 아이콘 상자 안 아이콘은 `AppIcons.bold()`(같은 모양 Bold, 20에서 선 약 1.9).

## 화면 패턴

- **트레이너 홈** (기준 시안 `TrainerHome` + 상세 `Tr-Home`): '홈' 제목·종 한 줄 → 오늘 · 캘린더 고르기 → [오늘] 오늘 PT 주황 카드('N건 완료 / M건' + 8 막대) → 이번 주 회색 카드(요일 · 32 원 · 'N건') → '오늘 PT' 64 줄(시각 44 · 이름 · 'PT · 50분', 오른쪽 완료 / 주황 '기록하기'(시작 시각 지남, 맥박) / 예정) → '혼자 운동한 회원' 요약 한 줄 / [캘린더] 회원 홈과 같은 달력 → 띠 → 날짜 머리말('PT n · 개인 m') → PT·개인운동 줄. 주 칸을 누르면 캘린더 보기에서 그날을 연다.
- **트레이너 일정** (`TrainerSchedule`): '일정' 제목 오른쪽 '‹ 10월 2주 ›' → 주간 7칸 → 시간 타임라인(완료 회색 · 진행 중 주황 채움 · 예정 주황 테두리, 현재 시각 주황 선) → 운동 기록 → 오른쪽 아래 검정 'PT 예약' 떠 있는 버튼.
- **PT 예약 시트** (`TrainerReserve`): 회색 묶음 카드(회원 · 날짜 · 시작/진행 2칸, 펼친 칸 흰 면 + 2 ink) → 휠 → 겹침 안내(흔들림) → 56 주황 '예약하기'.
- **트레이너 회원 상세** (`TrainerMember`): 뒤로 · 더보기 → 26 이름 + 요약 줄 → 2칸 카드(주황 PT 남은 횟수 · 회색 최근 체중) → 운동 · 식단 · 유산소 · 정보 pill → 68 기록 줄(날짜 칸 · 상태 '피드백 전'/'보냄') → 아래 고정 '인바디 입력' · '피드백 쓰기'.

- **탭 화면**: `SafeArea` → 머리(28 제목 + 오른쪽 아이콘) → 화면 폭 목록 → `AppNavBar`. 제목 위 머리말은 두지 않는다 — 앱 이름·날짜·개수를 제목 위에 반복하지 않는다.
- **회원 홈** (시안 `Main`): '홈' 제목·종 한 줄 → 오늘 · 캘린더 · 기록 고르기(40 pill) → 공지 줄 → [오늘] PT 잔여 주황 막대(64, '예약 | 일정') → 바로가기 8칸(회색 카드, 아이콘 30 + 13 글자) → 이번 주 카드(불꽃 + 'N일째 운동 중', 월~일 · 표시 점 하나) → '오늘' 일정 줄 / [캘린더] 월 이동 → 달력 → 범례 → 8 회색 띠 → 날짜 머리말 → 기록 줄 (시안 `MemA-Home`) / [기록] 그 달 기록이 있는 날을 최근부터.
- **회원 운동** (시안 `Workout`): 가운데 '오늘 운동' → 요약 3칸(종목 완료/전체 · 완료 세트 · 볼륨) → 펼친 종목 회색 카드(흰 값 상자 40 · 완료 원 36) / 접힌 종목 60 줄 → 점선 '종목 추가' → 메모 → 저장된 기록. 아래 휴식 막대 + 주황 '운동 마치기'(56). 새로 저장하면 운동 완료 화면(시안 `Done`).
- **개인 운동 시간** (2026-10-10, `core/workout_timing.dart`): 회원이 직접 하는 개인 운동만 잰다 (PT 기록은 재지 않는다). 빈 카드의 회색 '운동 시작'을 누르거나 첫 세트를 완료한 때부터 '운동 마치기'까지. 진행 중에는 목록 맨 위 '● 운동 중 · 32분'(점 6 주황 · 15 body, 종목이 없으면 '취소'). 시작·마지막 세트 시각은 기기 임시저장에 함께 둔다. 세트를 완료할 때마다 10분 뒤 '운동 마치셨나요?' 기기 안 알림을 다시 예약(`WorkoutReminder`, 누르면 운동 탭). 앱을 닫아 마치지 못하면 다음에 앱을 열 때 마지막 세트가 60분 넘게 지난 임시저장을 완료한 세트만으로 저장하고(시간 = 시작 → 마지막 세트), '지난 운동을 저장했어요 · 48분' 토스트. 고치던 기록은 자동 저장하지 않는다. 운동 완료 화면 요약 줄 끝에 시간 + '운동 시간 고치기'(분 조절 시트 `showWorkoutDurationSheet`), 기록 수정 화면에 '운동 시간' 줄. 회원 저장 카드·캘린더 줄, 트레이너 회원 상세·캘린더 줄에 '· 48분'(0이면 없음).
- **회원 식단** (시안 `Meal`): '‹ 10월 8일 (목) ›' 머리 → 먹은 양 카드 → 끼니 줄(아침·점심·간식·저녁, 비면 '기록하기') → 영양 가이드 안내 카드. 끼니 줄을 누르면 그 끼니의 사진·피드백·삭제 시트.
- **마이 (회원·트레이너·관리자 공통 짜임)**: 28 제목 → 프로필 줄(20 Bold · 14 mute, 회원만 화살표로 내 프로필) → (회원) PT 남은 횟수 주황 카드 → (회원) 내 몸 → 센터(공지사항) → 계정(비밀번호 재설정 메일 · 화면 테마 · 로그아웃) → 가운데 탈퇴 링크(관리자 없음). 모두 `AppMenuGroup` 메뉴 줄 — 시안 `My`(글자 줄)와 달리 `Tr-My`·`Ad-My`의 아이콘 줄로 통일했다 (2026-10-09 결정).
- **기록 줄**: 최소 68 높이, 40 아이콘 상자 + 14 + `listTitle` 제목 · `bodySm` 보조 줄, 누를 수 있으면 18 Bold 화살표(`chevron` 색). 오른쪽 상태 태그는 두지 않는다. 긴 글(피드백)은 위아래 14, 아이콘은 위로 붙이고 본문 `note` 최대 3줄.
- **마이 탭**: '나'에 대한 것만 둔다 — `AppProfileRow` → 내 몸(회원) → 계정(비밀번호 재설정 메일·화면 테마·로그아웃) → 탈퇴 링크. 다른 탭에 있는 기능이나 매일 쓰는 업무 기능은 두지 않는다. 로그아웃은 되돌릴 수 있으므로 빨강이 아닌 평범한 행이다.
- **하위 화면**: `AppScreenHeader(onBack:)` → 내용. 날짜는 제목 아래 보조 줄에 두지 않는다. 주 행동은 아래 고정 버튼 하나.
- **캘린더**: 월 이동은 가운데 `2026년 10월`(17/700, 폭 130) + 양옆 44 버튼 안 16 Bold 화살표(mute). 요일 머리 12 mute, 월요일 시작, 날짜 칸 46 높이 · 원 32 · 숫자 15. 선택일 = ink 채운 원 + canvas 700 숫자, 오늘 = ink 1px 외곽선 원, 미래 = `body` 색. 날짜 아래 표시는 `widgets/calendar_marks.dart`만 쓴다: PT 완료 ● 주황 / PT 예약 ○ 주황 / 개인운동 ● 검정 (5px, `buildCalendarMarks`가 회원·트레이너 공통 규칙으로 계산). 범례(`CalendarLegend`)는 표시 6 · 글자 12 mute · 항목 사이 14.
- **세트 입력**: 줄 높이 48, 값 상자 `canvasSoft`, 완료 = 주황 채운 원 + 체크, 미완료 = 외곽선 원, 진행 중 줄 = ink 테두리.
- **사진**: 3열 격자, 반경 14.
- **차트**: 선 1.5px `ink`(여러 계열은 `chartSeries`), 격자 `hairline`, 축 라벨 `counter`. 막대는 `canvasMid` 트랙 + `ink` 채움.
- **시트**: 제목 20, 메타 13, 행동 줄 52 높이, 파괴적 행은 맨 아래.

- **로그인** (2026-10-10 재디자인): 이메일·비밀번호만 받고, 센터·역할은 계정(사용자 문서)을 보고 `startRouteFor`가 정한다. 로고 없이 가운데 제목. 이 기기에서 로그인·가입한 적이 있으면(`SavedAccountStore`, 이메일·센터 이름·역할만 저장, 비밀번호 저장 안 함) '다시 오셨네요' + 계정 카드(회색 반경 20 · 흰 아이콘 상자 · 센터 16/500 · '역할 · 이메일' 13 body · 흰 알약 '바꾸기') + 비밀번호만. '바꾸기'·'다른 계정으로 로그인'은 이메일 화면으로, '지난번 계정으로 돌아가기'로 되돌린다. 로그인·가입 버튼은 아래 고정. 이메일로 처음 들어오면 '○○ 회원 계정으로 들어왔어요' 토스트. 탈퇴·거절 계정 삭제 시 저장한 계정도 지운다.
- **가입** (`RegisterFlowScreen`, 단계형): 머리(뒤로 44 + 단계 수만큼 4 높이 진행 칸 · 지난·지금 칸 주황 + '1/3' 13 mute) → 가운데 제목 → 내용 → `AppBottomActionBar`. 회원·트레이너: 역할(`AppActionRow` 세 줄 + 하는 일) → 센터(처음부터 목록, 고른 줄은 `CenterListRow(selected:)` 주황 체크, 고르기 전엔 '다음' 비활성) → 계정(비밀번호 아래 규칙 줄 '8자 이상 · 지금 5자' → 검정 체크) → 확인(회색 카드 56 줄, 누르면 그 단계로 + '○○ 관리자가 승인하면…' `AppInlineNotice`) → '가입 신청' → 승인 대기. 관리자: 역할 → 계정 → 센터 열기(설정 코드 · 센터 이름 · 주소) → 관리자 홈. 뒤로(단추·제스처)는 앞 단계로, 단계를 오가도 값은 남는다.
- **승인 대기**: '○○ 관리자가 가입 신청을 확인하고 있어요' — 어느 센터가 승인하는지 보여 준다.
- **트레이너 식단** (2026-10-10, 아래 탭 홈 · 일정 · 식단 · 마이): 28 '식단' + 종 → '전체 · 회원 이름' 버튼(36 알약, 고르면 ink 채움). 회원 버튼에 피드백할 식단 수(20 연한 주황 숫자, 고르면 주황)와 새 식단 점(8 newDot)을 따로 — 둘 중 하나라도 있는 회원이 앞으로. 새 식단 = 그 회원 식단을 마지막으로 본 뒤 올라왔고 내가 아직 피드백하지 않은 것(처음엔 하루 사이), 본 시각은 트레이너 기기에 저장(`MealFeedSeenStore`) — 회원 버튼을 누르거나 회원 상세 식단 탭을 열면 지운다. 피드는 담당 회원별로 식단·피드백을 읽어 합친다(`MealFeedService`, 지금 담당 회원만). 처음 최근 7일, 맨 아래 '이전 7일 더 보기'. 피드백은 보낼 때마다 하나씩 쌓이고(댓글처럼) 회원에게 지금처럼 알림, 회원은 답글 없음. 회원 상세 '식단' 탭도 같은 카드(회원 이름 대신 끼니, 최근 30일). 회원이 식단을 올리면 지금 담당 트레이너에게 '김민지님이 점심 식단을 올렸어요' 알림(서버 `onMealCreated`) → 식단 탭.
- **관리자 홈** (기준 시안 `AdminHome`): 센터 이름 제목 → 가입 요청 강조 띠(없으면 회색) → 숫자 2×2(18 · 14 · 26 Bold) → 띠 → '관리' 60 메뉴 줄(대시보드 '완료율 87%' · 가입 요청 'n건' · 공지사항 · 탈퇴 회원 PT 이력, 화살표 없음).
- **관리자 회원 상세** (`AdminMemberDetail`): 26 이름 · '가입 · 이메일' → 'PT' 회색 카드(총·남은 횟수 조절 68, 기간 56, 담당 트레이너 56 ›) → 13 안내('10회 추가 등록 · 남은 횟수도 함께 늘어나요') → '변경 기록' 52 줄 → 아래 고정 '저장'. 고친 값(담당 포함)은 '저장'으로만 반영된다.
- **관리자 대시보드** (`AdminDashboard`): 큰 제목 오른쪽 '‹ 10월 ›' → 고리 카드 → 주별 PT → 트레이너별 → (띠) 지금 기준 잔여 3회 이하 · 만료 14일 이내.

## 접근성

- 텍스트 대비 4.5:1 (`mute`는 캔버스 위에서만, 카드 위 보조 글자는 `body`). `faint`·`chevron`은 글자 본문에 쓰지 않는다 (비활성 탭·장식 화살표 전용).
- 터치 영역 44 이상. 아이콘만 있는 버튼은 `AppIconButton(label:)`으로 이름을 준다.
- 색만으로 상태를 구분하지 않는다 (모양·글자를 함께).

## 시안과 아직 다른 곳

- 트레이너 홈·일정의 '하체 · 50분'처럼 수업 이름: 예약에 이름이 없어 'PT · 50분' / 시각 범위로 보여 준다.
- 트레이너 회원 상세 회색 카드의 '스쿼트 추정 1RM': 계산 근거가 없어 '최근 체중'(InBody 추이 선)으로 대신한다.
- PT 예약 시트 회원 줄의 '· 6회 남음': 예약 시트가 회원별 남은 횟수를 불러오지 않아 넣지 않았다.
- 트레이너 일정 시간 줄: 첫 예약부터 마지막 예약까지 빈 시간도 이어서 보여 준다 (시안은 일부 시각만).
- `Tr-Inbody-Input`(입력창 48 · 라벨 13)·`Tr-Inbody-DeleteConfirm`(확인 창 18 · 버튼 48)은 공용 입력창(52 · 14)·확인 창(20 · 52) 값으로 통일했다.

- 아이콘 모양: 시안은 Lucide 계열 선 아이콘, 앱은 Phosphor. 굵기만 맞췄다(Regular).
- `AppHero` · `AppScreenHeader` · `AppMonthHeader` 구조 (위 컴포넌트 표 참고) — 회원 기준 화면 외.
- 회원 식단 시안의 목표 열량(2,100kcal)·탄수화물·단백질·지방 막대: 데이터가 없어 먹은 열량만 보여 준다.
- 회원 홈 '오늘' 일정의 'PT 하체' 같은 수업 이름: 예약에 이름이 없어 'PT'로만 보여 준다.
- 운동 완료 화면의 '트레이너에게 오늘 기록 보내기': 기능이 없어 넣지 않았다. 꽃가루·바벨 들기 애니메이션도 넣지 않았다.
- 기준 시안의 캡션 회색은 #767676, 앱 `mute`는 #6B6B70 (상세 시안 값).
- 스플래시·승인 대기 화면의 고리 퍼짐·불꽃 흔들림 애니메이션은 넣지 않았다 (정지 표시 + 로딩 점).
- 시안의 탭 바 위 선은 #EDEDEF, 앱은 `hairline`(#F0F0F2).
- 운동 시간 (2026-10-10 결정): 2026-10-07에 회원·PT 기록에서 모두 뺐던 운동 시간을 회원 개인 운동에만 되살렸다. PT 기록은 지금처럼 재지 않는다.
- 회원 기록(운동·식단·신체 정보)은 늘 담당 트레이너에게 공유된다 (2026-10-10 결정). 시안 `MemB-Share`(기록 공유 설정)·`Tr-Member-Blocked`·`Tr-Member-Profile-Blocked`(공유 꺼짐 안내)는 쓰지 않는다.
- 식단은 사진이 1장 이상 있어야 저장된다 (2026-10-10 결정). 시안 `MemB-MealInputEmpty`의 '사진 없이 메모만' 저장은 막고, 사진 칸 아래 안내 줄을 둔다.
- 홈 '이번 주' 칸은 캘린더 날짜 칸과 같은 표시 줄(PT 완료 · PT 예약 · 개인운동)을 그린다 (`CalendarWeekMarks`). 시안 Main의 '하루에 점 하나'·TrainerHome의 'N건'과 다르다.
- 홈 공지 줄은 모든 보기(오늘·캘린더·기록)에 둔다. 시안 Main·TrainerHome '오늘' 화면에는 공지 줄이 없다.
- 관리자 홈 메뉴: 기준 시안은 3줄이지만 공지사항 줄을 더 둔다 (관리자 마이에도 공지 진입이 없어 빼면 들어갈 길이 사라진다). '회원 관리'·'트레이너 관리' 줄은 탭과 겹쳐 뺐다.
- 관리자 대시보드: '노쇼'는 수업 상태에 없어 넣지 않았다. 완료율은 기존 정의(취소 제외: 완료 / (완료 + 남은 예약))를 지켜 시안의 '342회 / 393회'(취소 포함)와 분모가 다르다. 잔여 3회 이하·만료 14일 이내 목록은 업무용이라 기준 시안 아래에 남겼다.
- 관리자 회원 상세: 이미 있는 PT를 바꾸면 '변경 사유' 칸(필수)이 나타난다 (시안에 없음, 변경 기록 감사용). 기간은 줄을 눌러 시작일·종료일·갱신일 시트에서 고른다. 그래서 상세 시안 `Ad-PtInfoSheet-*`(시트로 수정)는 쓰지 않는다.
- 관리자 '가입 요청'(받는 쪽) · 회원·트레이너 '가입 신청'(보내는 쪽): 시안대로 쪽마다 다르게 둔다.
- 로그인·가입 (2026-10-10 결정): 시안 `Com-Login`(역할 세 칸 · 센터 고르기)과 `Com-Register-*`(한 화면 · 관리자 따로)는 쓰지 않는다. 위 화면 패턴의 '로그인'·'가입'을 따른다. 관리자 설정 코드는 지금도 서버가 마지막(센터 열기)에 확인한다 — 앞 단계에서 미리 확인하려면 서버 함수가 하나 더 필요하다.
- 공지 상세의 작성자 이름('김관리')과 '134명에게 보냄': 공지에 작성자 ID만 있고 받은 사람 수는 서버만 알아 '보냄 / 보내지 않음'으로 보여 준다. 작성 화면의 인원은 승인된 회원·트레이너 수(개수 조회)다.
- 공지 작성 스위치 켜짐은 시안(검정)과 달리 원칙 6대로 주황.
- 등록 직후 새 공지 줄 배경이 연한 주황에서 흰색으로 바뀌는 효과(`Nt-Admin-Posted`)는 넣지 않았다.
- 비밀번호 재설정·화면 테마 시트는 회원·관리자 시안끼리 수치가 달라 공용 모양(회원 시안)을 유지한다.

## 화면 확인 (화면 투어)

디자인을 바꾼 뒤에는 실제 화면을 iOS 시뮬레이터에서 찍어 확인한다. 로컬 에뮬레이터만 쓰며 실제 Firebase에는 접근하지 않는다.

```bash
# 1) 에뮬레이터 (앱과 같은 프로젝트 ID, 로컬 전용)
firebase emulators:start --project burnfit-v01 --only auth,firestore,storage,functions
# 2) 예시 데이터 (다른 터미널)
cd functions && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  GCLOUD_PROJECT=burnfit-v01 node integration/seed_screens.js
# 3) 화면 투어 → build/screen_tour/*.png
flutter drive -d <iOS 시뮬레이터> --driver=test_driver/integration_test.dart \
  --target=integration_test/screen_tour_test.dart --dart-define=USE_FIREBASE_EMULATOR=true
```

`--dart-define=USE_FIREBASE_EMULATOR=true`는 개발 빌드에서만 쓴다 (`lib/main.dart`).

### 글자 세로 정렬 견본

고정 높이 칸(입력창·세트 입력·버튼·태그) 안의 글자가 가운데 오는지는 견본 화면으로 확인한다. 웹과 iOS가 다르게 그릴 수 있으므로 둘 다 본다.

```bash
# iOS 시뮬레이터 → build/screen_tour/specimen.png
flutter drive -d <iOS 시뮬레이터> --driver=test_driver/integration_test.dart --target=integration_test/specimen/specimen_test.dart
# 웹 → build/specimen_web (아무 정적 서버로 열어 확인)
flutter build web -t tool/specimen_main.dart -o build/specimen_web
```

입력칸은 줄 높이를 1.0으로 누르지 말고, `AppTextField`처럼 한 줄 높이 + 위아래 같은 여백으로 칸을 채운다 (웹에서 글자가 아래로 내려간다).

