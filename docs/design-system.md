# BurnFit 디자인 시스템

미니멀 · 한 가지 강조색(주황 #FF7A33) · 작은 움직임. 라이트(기본)·다크 두 테마.
기준: `BurnFit-디자인-시안/screens/*.html`. **목차 맨 위 '화면' 묶음(`Main`·`Workout`·`Done`·`Meal`·`My`, 트레이너 `Trainer*`, 관리자 `Admin*`)이 최우선 기준**이고(2026-10-08 결정), 그 묶음에 없는 화면은 역할별 상세 시안(`MemA-*`·`MemB-*`·`Tr-*`·`Ad-*`·`Com-*`·`Nt-*`)과 C0~C4 컴포넌트 스펙을 따른다. 값이 헷갈리면 시안 HTML의 숫자를 따른다.

## 원칙

1. **캔버스는 하나, 테마는 둘.** 모든 화면 바탕은 `AppColors.canvas`. 라이트(기본, #FFFFFF)와 다크(#0A0A0A)는 같은 구조에서 면·글자 색만 뒤집는다. 테마는 마이 → 계정 → '화면 테마'에서 시스템 설정 · 라이트 · 다크 중에 고르고 기기에 저장된다 (`ThemeController`).
2. **모서리는 토큰으로만.** 아이콘 상자 12 · 입력창·안내 줄·꽉 찬 중간 버튼 14 · 큰 버튼·토스트 18 · 카드 20 · 시트 28 · 칩·태그·작은 버튼 pill (`AppRadius`).
3. **굵기는 400·700 두 가지.** Wanted Sans 하나만 쓴다. 제목·값·목록 줄 제목은 700(Bold), 나머지는 400. 기준 시안(`Main` 계열)은 `font-weight:500` 자리에 Wanted Sans Bold 글꼴을 묶어 두어 실제로 굵게 그려진다.
4. **화면 글자는 한글.** 영어 라벨(`DONE`, `10.07 WED`, `KCAL` 등)을 쓰지 않는다. 남기는 것: 단위(`kg`, `kcal`, `g` — 소문자), `PT`, `BMI`, `InBody`, 앱 이름. 날짜는 `10월 7일 (수)`, 달은 `2026년 10월`. 큰 수는 천 단위 쉼표(`11,440kg`).
5. **그림자 대신 면과 선.** 층은 면 색(`canvas` → `canvasCard`)과 1px `hairline`으로 나눈다. `BoxShadow`, gradient, elevation 금지.
6. **강조색은 주황 하나.** 주 행동 채움(`primary`)과 눈에 띄어야 할 데이터 점(캘린더 PT 표시, 토글 on, 그래프 최신값)에 쓴다. "새 글"·"새 알림" 점은 `newDot`(#FF5A1F). 안내·경고·PT 강조 줄은 연한 주황 면 `noticeBg` + 진한 주황 글자 `noticeText`. 역할·성별 같은 **선택 pill**은 주황이 아니라 검정(`ink`) 채움.
7. **빨강(`danger`)은 되돌릴 수 없는 행동의 글자에만.** 빨간 채움 배경은 쓰지 않는다. 파괴적 확정 버튼은 검정 채움(`AppButtonVariant.dark`).
8. **주 행동은 화면당 하나.** 주황 채움(`AppButton` primary)은 화면당 한 번. 나머지는 회색 채움(`secondary`)이나 글자(`ghost`).
9. **움직임은 작게.** 로딩은 점 세 개(`AppLoader`/`AppLoadingView`). `CircularProgressIndicator`·스켈레톤은 쓰지 않는다. 기기의 '동작 줄이기'가 켜져 있으면 멈춘다.
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
| 차트 계열 구분 | `chartSeries` | — |

**두 테마 공통 면(`noticeBg` 등) 위의 글자는 테마 색(`ink`)을 쓰지 않는다** — 다크에서 흰 글자가 된다. 검정이 필요하면 `AppPalette.light.ink`.

글자: `displayLg`(40) · `displayMd`(28, 탭 제목) · `title`(20, 앱바·시트·다이얼로그) · `section`(17/700, 섹션·날짜 머리말, 월 이름) · `bodyLg`(17) · `listTitle`(16/700, 목록 줄 제목) · `bodyMd`(15) · `note`(14/21 body, 목록 안 긴 글·짧은 빈 상태) · `buttonLabel`(14) · `bodySm`(13 mute) · `badge`(11/700) · `eyebrow`(15 mute, 섹션 개수) · `counter`(13 mute).

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
| `AppActionRow` + `AppRowDivider` | 목록·메뉴 한 줄: 아이콘 상자 + 라벨 + 보조 줄 + 오른쪽(태그/화살표). 목록은 카드로 감싸지 말고 hairline으로 나눈다 |
| `AppIconBox` | 40 둥근 사각형(반경 12) + `canvasCard` 면, 아이콘 20. PT 운동처럼 강조할 줄만 `noticeBg` + `noticeText` |
| `AppTag` / `StatusBadge` | 상태 글자 (strong / 기본 / muted / danger) |
| `AppChip` / `AppScrollableChips` / `AppFilterTabs` | 필터·선택 pill |
| `AppCountBadge` | 사진 위 카운터 (`+2`) |
| `AppButton` | primary(주황) / secondary(회색 채움) / ghost / dark(파괴적 확정) / danger / dangerText, sm 32 · md 40 · lg 56 |
| `AppIconButton` | 44 터치 영역 아이콘 버튼 (`label` 필수, `showDot`, `iconSize` 기본 20 — 알림 종은 24) |
| `AppTextField` | 라벨(13 body) 위 + 입력창 |
| `AppCard` | canvasCard + hairline (그림자 없음). 목록 대신 한 덩어리 정보에만 |
| `AppKpiCard` / `AppStatStrip` / `AppStatGrid` | 숫자 칸 |
| `AppHighlightCard` | 주황 강조 카드 (PT 잔여 횟수 등) |
| `AppProfileRow` / `AppProfileCard` | 마이 탭 맨 위 프로필 줄 / 관리자 회원 상세 머리 |
| `showAppBottomSheet` + `AppBottomSheetHeader` + `AppSheetAction` | 하단 시트, 시트 안 행동 줄 |
| `AppEmptyState` | 그림 + 20 제목 + 설명 + (선택) 주 행동 — 화면 전체가 빈 경우 |
| `AppEmptyLine` | 목록 자리의 짧은 빈 상태 한 줄: 52 높이, 14 mute ("이 날의 기록이 없습니다") |
| `showAppConfirmDialog` | 확인 다이얼로그: 제목 + 설명 (+ 선택 `warning` 주황 콜아웃) + 2열 전체폭 버튼(취소 회색 · 확정 주황, 파괴적이면 검정). `showDialog`를 직접 쓰지 않는다 |
| `AppAsyncBody` / `AppLoadingView` / `AppLoader` | 로딩·오류·빈 상태. 로딩은 점 세 개(화면 6 / 줄 안 4) |
| `AppErrorCard`·`AppFeedback.show*`(`core/app_feedback.dart`) → `AppToast` | 오류 카드, 토스트(검정 채움 + 주황 원 배지, **화면 위쪽**, 한 번에 하나). `SnackBar`·`ScaffoldMessenger`를 직접 쓰지 않는다 |
| `NoticeBanner` | 홈 공지 한 줄: 48 높이 `noticeBg`(반경 14) + 확성기 18 + '공지' + 제목 15 + 화살표 16 |
| `SplashFlameMark` / `PendingClockMark` | 스플래시 불꽃, 승인 대기 시계 (주황 원 브랜드 표시) |
| `AppNavBar` | 하단 탭: 위 10 + 아이콘 26 + 글자 11. 선택 = Fill + ink 700, 나머지 = Regular + `faint` |
| `AppPlainRow` | 글자만 있는 목록 줄 (56, 16 라벨 · 15 mute 값, 아이콘·화살표 없음). 회원 마이 (`ThemeSettingRow(plain:)`·`NoticeMenuRow(plain:)`도 같은 모양) |
| `RestTimer` / `RestTimerBar` / `showRestTimerSheet` | 앱 전체 휴식 타이머 하나. 세트 완료 시 그 운동의 휴식 시간으로 시작, 검정 64 막대(진행 고리 · '+30초' · '건너뛰기'). 운동 탭은 화면 안, 다른 탭은 탭 바 위에 뜬다 |
| `FlameIcon` · `MealBowlIllustration` | 홈 연속 운동 불꽃, 식단 안내 카드 그릇 그림 (`brand_marks.dart`) |

## 화면 패턴

- **탭 화면**: `SafeArea` → 머리(28 제목 + 오른쪽 아이콘) → 화면 폭 목록 → `AppNavBar`. 제목 위 머리말은 두지 않는다 — 앱 이름·날짜·개수를 제목 위에 반복하지 않는다.
- **회원 홈** (시안 `Main`): '홈' 제목·종 한 줄 → 오늘 · 캘린더 · 기록 고르기(40 pill) → 공지 줄 → [오늘] PT 잔여 주황 막대(64, '예약 | 일정') → 바로가기 8칸(회색 카드, 아이콘 30 + 13 글자) → 이번 주 카드(불꽃 + 'N일째 운동 중', 월~일 · 표시 점 하나) → '오늘' 일정 줄 / [캘린더] 월 이동 → 달력 → 범례 → 8 회색 띠 → 날짜 머리말 → 기록 줄 (시안 `MemA-Home`) / [기록] 그 달 기록이 있는 날을 최근부터.
- **회원 운동** (시안 `Workout`): 가운데 '오늘 운동' → 요약 3칸(종목 완료/전체 · 완료 세트 · 볼륨) → 펼친 종목 회색 카드(흰 값 상자 40 · 완료 원 36) / 접힌 종목 60 줄 → 점선 '종목 추가' → 메모 → 저장된 기록. 아래 휴식 막대 + 주황 '운동 마치기'(56). 새로 저장하면 운동 완료 화면(시안 `Done`).
- **회원 식단** (시안 `Meal`): '‹ 10월 8일 (목) ›' 머리 → 먹은 양 카드 → 끼니 줄(아침·점심·간식·저녁, 비면 '기록하기') → 영양 가이드 안내 카드. 끼니 줄을 누르면 그 끼니의 사진·피드백·삭제 시트.
- **회원 마이** (시안 `My`): 28 제목 → 프로필 줄 → PT 남은 횟수 주황 카드 → 내 몸 · 계정 글자 줄 → 왼쪽 탈퇴 링크.
- **기록 줄**: 최소 68 높이, 40 아이콘 상자 + 14 + `listTitle` 제목 · `bodySm` 보조 줄, 누를 수 있으면 18 Bold 화살표(`chevron` 색). 오른쪽 상태 태그는 두지 않는다. 긴 글(피드백)은 위아래 14, 아이콘은 위로 붙이고 본문 `note` 최대 3줄.
- **마이 탭**: '나'에 대한 것만 둔다 — `AppProfileRow` → 내 몸(회원) → 계정(비밀번호 재설정 메일·기록 공유·로그아웃) → 탈퇴 링크. 다른 탭에 있는 기능이나 매일 쓰는 업무 기능은 두지 않는다. 로그아웃은 되돌릴 수 있으므로 빨강이 아닌 평범한 행이다.
- **하위 화면**: `AppScreenHeader(onBack:)` → 내용. 날짜는 제목 아래 보조 줄에 두지 않는다. 주 행동은 아래 고정 버튼 하나.
- **캘린더**: 월 이동은 가운데 `2026년 10월`(17/700, 폭 130) + 양옆 44 버튼 안 16 Bold 화살표(mute). 요일 머리 12 mute, 월요일 시작, 날짜 칸 46 높이 · 원 32 · 숫자 15. 선택일 = ink 채운 원 + canvas 700 숫자, 오늘 = ink 1px 외곽선 원, 미래 = `body` 색. 날짜 아래 표시는 `widgets/calendar_marks.dart`만 쓴다: PT 완료 ● 주황 / PT 예약 ○ 주황 / 개인운동 ● 검정 (5px, `buildCalendarMarks`가 회원·트레이너 공통 규칙으로 계산). 범례(`CalendarLegend`)는 표시 6 · 글자 12 mute · 항목 사이 14.
- **세트 입력**: 줄 높이 48, 값 상자 `canvasSoft`, 완료 = 주황 채운 원 + 체크, 미완료 = 외곽선 원, 진행 중 줄 = ink 테두리.
- **사진**: 3열 격자, 반경 14.
- **차트**: 선 1.5px `ink`(여러 계열은 `chartSeries`), 격자 `hairline`, 축 라벨 `counter`. 막대는 `canvasMid` 트랙 + `ink` 채움.
- **시트**: 제목 20, 메타 13, 행동 줄 52 높이, 파괴적 행은 맨 아래.

## 접근성

- 텍스트 대비 4.5:1 (`mute`는 캔버스 위에서만, 카드 위 보조 글자는 `body`). `faint`·`chevron`은 글자 본문에 쓰지 않는다 (비활성 탭·장식 화살표 전용).
- 터치 영역 44 이상. 아이콘만 있는 버튼은 `AppIconButton(label:)`으로 이름을 준다.
- 색만으로 상태를 구분하지 않는다 (모양·글자를 함께).

## 시안과 아직 다른 곳

- 아이콘 모양: 시안은 Lucide 계열 선 아이콘, 앱은 Phosphor. 굵기만 맞췄다(Regular).
- `AppHero` · `AppScreenHeader` · `AppMonthHeader` 구조 (위 컴포넌트 표 참고) — 회원 기준 화면 외.
- 회원 식단 시안의 목표 열량(2,100kcal)·탄수화물·단백질·지방 막대: 데이터가 없어 먹은 열량만 보여 준다.
- 회원 홈 '오늘' 일정의 'PT 하체' 같은 수업 이름: 예약에 이름이 없어 'PT'로만 보여 준다.
- 운동 완료 화면의 '트레이너에게 오늘 기록 보내기': 기능이 없어 넣지 않았다. 꽃가루·바벨 들기 애니메이션도 넣지 않았다.
- 기준 시안의 캡션 회색은 #767676, 앱 `mute`는 #6B6B70 (상세 시안 값).
- 스플래시·승인 대기 화면의 고리 퍼짐·불꽃 흔들림 애니메이션은 넣지 않았다 (정지 표시 + 로딩 점).
- 시안의 탭 바 위 선은 #EDEDEF, 앱은 `hairline`(#F0F0F2).

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

