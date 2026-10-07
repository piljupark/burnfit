# BurnFit 디자인 시스템 (Galloway 기반)

다크 캔버스 하나, 흰 외곽선 pill, 400 굵기, 모노 머리말, 그림자 없음.
원본: Galloway 디자인 시스템 + "BurnFit × Galloway 화면" 캔버스(16개 화면 시안).

## 원칙

1. **캔버스는 하나.** 모든 화면 바탕은 `AppColors.canvas`(#0A0A0A). 라이트 모드는 없다. UI는 흰색과 회색만 쓴다.
2. **누르는 것은 전부 pill.** 버튼·칩·태그·토스트는 pill, 카드·입력창·시트·다이얼로그는 반경 8, 사진은 0. 이 세 가지 외의 모서리는 없다.
3. **굵기 대신 크기.** Wanted Sans 400이 기본. `FontWeight.w600` 이상을 쓰지 않는다 (예외: `AppTextStyles.badge` 500).
4. **모노는 영문·숫자에만.** Geist Mono(`eyebrow`, `counter`)는 `2026.10`, `D-12`, `PT 12 / 30`, `DONE` 같은 대문자 영문·숫자에만. 한글을 모노로 쓰지 않는다.
5. **그림자 대신 hairline.** 층은 1px `hairline` 테두리와 면 색(`canvas` → `canvasCard` → `canvasSoft`)으로만 나눈다. `BoxShadow`, gradient, elevation 금지.
6. **상태는 색이 아니라 모양.** 완료/선택 = 흰 채움(`AppTag(strong: true)`, 채운 원), 진행/대기 = 외곽선, 취소 = 흐린 글자(`muted`). 운동·식단·트레이너 같은 도메인 색 구분은 없다.
7. **빨강(`danger`)은 되돌릴 수 없는 행동의 글자에만.** 빨간 채움 배경은 쓰지 않는다.
8. **주 행동은 화면당 하나.** 흰 채움(`AppButton` primary)은 화면당 한 번. 나머지는 외곽선(`secondary`)이나 글자(`ghost`).
9. **움직임은 Orb 하나.** 로딩은 `OrbLoader`/`AppLoadingView`. `CircularProgressIndicator`, 스켈레톤, 장식 애니메이션 금지.
10. **아이콘은 Phosphor 하나.** `AppIcons.*` (없으면 `PhosphorIconsLight.*`). 켜진 상태만 Fill. Material `Icons.*`·`Iconsax`·이모지 금지.

## 토큰 (`lib/core/`)

| 용도 | 토큰 |
|---|---|
| 바탕 | `AppColors.canvas` |
| 카드·시트·다이얼로그·토스트 | `canvasCard` + `hairline` 테두리 |
| 입력창·눌림·중첩 면 | `canvasSoft` |
| 진행 막대 바탕·손잡이 | `canvasMid` |
| 기본 글자·아이콘 | `ink` |
| 보조 글자 (캔버스·카드 모두) | `body` |
| 캡션 (캔버스 위에서만) | `mute` |
| 외곽선 버튼 테두리 | `outline` |
| 주 행동 채움 / 그 위 글자 | `primary` / `onPrimary` |
| 파괴적 행동 글자 | `danger` |
| 아바타·빈 상태 그림·차트 계열 | `accent*`, `chartSeries` (UI 컨트롤에는 쓰지 않음) |

글자: `displayLg`(40) · `displayMd`(28, 탭 제목) · `title`(20, 앱바·시트·다이얼로그) · `bodyLg`(17, 목록 주 텍스트) · `bodyMd`(15) · `bodySm`(13, mute) · `buttonLabel`(14) · `badge`(11/500) · `eyebrow`(모노 12) · `counter`(모노 11).

간격: 2 · 4 · 8 · 12 · 16(화면 좌우) · 24(시트 안쪽·섹션 사이) · 32 · 48. 크기: `AppSize.touchMin` 44, 버튼 32/40/52, 아이콘 20, 탭 아이콘 24.

`Color(0x…)` 직접 쓰기 금지 — 토큰을 쓴다.

## 컴포넌트 (`lib/widgets/`)

| 컴포넌트 | 쓰임 |
|---|---|
| `AppHero` | 탭 화면 상단: 오른쪽 아이콘 버튼 줄 + 모노 머리말 + 28 제목 + 아래 hairline |
| `AppScreenHeader` | 하위 화면 앱바: 뒤로 + 20 제목 + 오른쪽 행동 (`divider: true`로 아래 hairline) |
| `AppMonthHeader` | 화면 폭 섹션 머리말: `10.07 WED` + 카운터 + 남은 폭 hairline |
| `AppSectionHeader` | 여백 있는 열 안의 섹션 머리말 (+ 오른쪽 글자 행동) |
| `AppActionRow` + `AppRowDivider` | 목록·메뉴 한 줄: 아이콘 상자 + 17 라벨 + 보조 줄 + 오른쪽(태그/화살표). 목록은 카드로 감싸지 말고 hairline으로 나눈다 |
| `AppAvatar` | 이니셜 원 (accent 색은 seed로 고정) |
| `AppTag` / `StatusBadge` | 상태·역할 태그 (strong / 외곽선 / muted / danger) |
| `AppChip` / `AppScrollableChips` / `AppFilterTabs` | 필터·선택 pill |
| `AppCountBadge` | 사진 위 카운터 (`+2`) |
| `AppButton` | primary / secondary / ghost / danger / dangerText, sm 32 · md 40 · lg 52 |
| `AppIconButton` | 44px 원형 아이콘 버튼 (`label` 필수, `outlined`, `showDot`) |
| `AppTextField` | 라벨 위 + 48 입력창. 영문 라벨은 모노 대문자로 자동 |
| `AppCard` | canvasCard + hairline (그림자 없음). 목록 대신 한 덩어리 정보에만 |
| `AppKpiCard` / `AppStatStrip` / `AppStatGrid` | 숫자 칸. 화면 폭 숫자 줄은 `AppStatStrip`(`framed: false` 칸) |
| `AppProfileCard` | 56 아바타 + 28 이름 + 역할 태그 |
| `showAppBottomSheet` + `AppBottomSheetHeader` + `AppSheetAction` | 하단 시트, 시트 안 행동 줄 |
| `AppEmptyState` | 도형 그림 + 20 제목 + 설명 + (선택) 주 행동 |
| `AppAsyncBody` / `AppLoadingView` / `OrbLoader` | 로딩·오류·빈 상태 |
| `AppErrorCard`, `AppFeedback.show*SnackBar` | 오류 카드, 토스트 |
| `AppNavBar` | 하단 탭 (활성 = Fill 아이콘 + ink 글자) |

## 화면 패턴

- **탭 화면**: `SafeArea` → `AppHero` → 화면 폭 목록(`AppActionRow`/행 + `AppRowDivider`) → `AppNavBar`. 머리말은 앱 이름·숫자 요약만 (`BURNFIT · PT 12 / 30`).
- **하위 화면**: `AppScreenHeader(onBack:, divider: true)` → 내용. 주 행동은 아래 고정 pill 하나.
- **캘린더**: 요일 머리 `bodySm mute`, 월요일 시작, 날짜 셀 44px. 선택일 = 흰 원 + `onPrimary` 숫자, 오늘 = 외곽선 원, 미래 = `body` 색. 날짜 아래 표시는 `widgets/calendar_marks.dart`만 쓴다: PT 완료 ● / PT 예약 ○ / 개인운동 ▬ (`buildCalendarMarks`가 회원·트레이너 공통 규칙으로 계산). 범례(`CalendarLegend`)를 함께 둔다.
- **세트 입력**: 줄 높이 48, 세트 번호 모노, 값 상자 `canvasSoft` 36 높이, 완료 = 흰 채운 원 + 굵은 체크(`AppIcons.checkBold`), 미완료 = 외곽선 원, 진행 중 줄 = 흰 테두리.
- **사진**: 3열 격자, 간격 2, 반경 0. 사진 위 배지는 `scrim` pill.
- **차트**: 선 1.5px `ink`(여러 계열은 `chartSeries`), 격자 `hairline`, 축 라벨 `counter`. 막대는 4px pill 트랙(`canvasMid`) + `ink` 채움.
- **다이얼로그**: 제목 + 한 문단 설명(무엇이 몇 개 사라지는지) + 오른쪽 정렬 버튼 (취소 ghost → 확정; 파괴적이면 danger).
- **시트**: 제목 20, 모노 메타, 행동 줄 52 높이, 파괴적 행은 맨 아래.

## 접근성

- 텍스트 대비 4.5:1 (`mute`는 캔버스 위에서만, 카드 위 보조 글자는 `body`).
- 터치 영역 44 이상. 아이콘만 있는 버튼은 `AppIconButton(label:)`으로 이름을 준다.
- 색만으로 상태를 구분하지 않는다 (모양·글자를 함께).

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
