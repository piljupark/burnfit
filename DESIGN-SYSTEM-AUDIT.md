# Design System Audit — BurnFit

> 작성일: 2026-09-07  
> 기준: lib/core/app_colors.dart, app_text_styles.dart, app_spacing.dart, lib/widgets/\*, 주요 홈 화면 3개

---

## 1. 현재 Foundation 상태

### Color Tokens

**현재 토큰 구조 (`lib/core/app_colors.dart`)**

| 카테고리 | 토큰 | 값 |
|---|---|---|
| Brand | `brand` | `#0A84FF` |
| Brand | `brandDark` | `#0066CC` |
| Brand | `brandLight` | `#EAF2FF` |
| Semantic Accent | `workout` | `#3E9C5C` |
| Semantic Accent | `diet` | `#D98A3D` |
| Semantic Accent | `trainer` | `#8C7FC4` |
| Semantic Accent | `destructive` | `#E15361` |
| Background | `bg` | `#F2F2F7` |
| Background | `bgElevated` | `#FFFFFF` |
| Surface | `card` | `#FFFFFF` |
| Text | `textPrimary` | `#1C1C1E` |
| Text | `textSecondary` | `#3C3C43` @ 60% opacity |
| Text | `textTertiary` | `#3C3C43` @ 40% opacity |
| Text | `textDisabled` | `#3C3C43` @ 30% opacity |
| Border | `border` | `#3C3C43` @ 12% opacity |
| Status | `success` | `#30D158` |
| Status | `error` | `#FF453A` |
| Status | `warning` | `#FFD60A` |

**Toss 기준 대비 문제점**

1. **Legacy dark 토큰이 여전히 정의에 존재**: `surface0`(#0D0D0D), `surface1`(#161616), `surface2`(#1F1F1F), `surface3`(#2A2A2A), `canvas`(#000000), `separator`, `separatorStrong`, `labelSecondary`, `labelTertiary`, `labelQuaternary`, `brandOrange`, `brandDim`, `navGlass`, `navGlassBorder` 등 14개의 dark-theme 전용 토큰이 app_colors.dart에 잔존. `app_bottom_sheet.dart`에서 `AppColors.surface1`이 실제 사용 중 (line 45).

2. **추가 alias 남발**: `primary`, `primaryActive`, `primaryDisabled`, `background`, `surface`, `surfaceCard`, `surfaceElevated`, `surfaceVariant`, `surfaceSoft`, `hairline`, `hairlineStrong`, `onDark`, `onPrimary`, `body`, `bodyStrong`, `muted`, `mutedSoft`, `accent`, `accentMuted`, `brandActive` 등 20개의 alias가 기존 토큰을 단순 re-export. Toss 원칙: 의미(semantic)가 동일한 토큰은 하나만 존재해야 한다.

3. **meal/workout category 색상이 semantic 토큰과 중복**: `categoryUpper` = `brand`, `categoryCardio` = `error`와 값이 동일. 별도 토큰으로 유지할 이유 없음.

4. **`bgLogin`(#EAF2FF)이 brandLight와 동일**: 토큰 낭비.

5. **shadow 색상 비토큰화**: `BoxShadow`에 `Color(0x0A000000)`, `Color(0x08000000)`, `Color(0x0C000000)` 등 인라인 hex 값이 screens 전체에 20개 이상 산재. Toss는 shadow도 semantic 토큰(예: `shadowSmall`, `shadowMedium`)으로 관리.

---

### Typography Scale

**현재 scale (`lib/core/app_text_styles.dart`)**

| 이름 | 크기 | Weight | line-height | 용도 |
|---|---|---|---|---|
| `display` | 34 | w800 | 1.15 | 최상위 제목 |
| `h1` | 28 | w800 | 1.20 | 페이지 제목 |
| `h2` | 22 | w700 | 1.30 | 섹션 제목 |
| `h3` | 17 | w600 | 1.40 | 서브 제목 |
| `h4` | 16 | w600 | 1.40 | 소항목 |
| `headline` | 17 | w600 | 1.45 | 강조 텍스트 |
| `body` | 16 | w400 | 1.60 | 본문 |
| `bodyLarge` | 17 | w400 | 1.55 | 큰 본문 (textSecondary 기본) |
| `callout` | 16 | w400 | 1.45 | 부가 설명 (textSecondary 기본) |
| `bodySmall` | 14 | w400 | 1.50 | 작은 본문 (textSecondary 기본) |
| `caption` | 13 | w400 | 1.40 | 캡션 |
| `captionSmall` | 11 | w500 | 1.40 | 소 캡션 |
| `label` | 14 | w600 | 1.30 | 레이블 |
| `labelSmall` | 11 | w500 | 1.30 | 소 레이블 |
| `overline` | 11 | w600 | 1.30 | **letter-spacing: 1.0** — 강조 overline |
| `button` | 16 | w600 | 1.00 | 버튼 |
| `stat` | 48 | w700 | 1.00 | 대형 숫자 |
| `numberLarge` | 32 | w700 | 1.00 | 중형 숫자 |

**일관성 문제**

1. **`h3`(17)와 `headline`(17)이 크기 동일**: h3(w600, lh1.40)과 headline(w600, lh1.45)은 lh 0.05 차이만 있어 실질적으로 동일한 역할. 하나로 통합 필요.

2. **`h4`(16)와 `body`(16) 크기 동일**: weight만 다름(w600 vs w400). 위계가 모호해짐.

3. **`bodyLarge`(17)와 `headline`(17) 크기 동일**: bodyLarge는 기본 색이 textSecondary인 반면 headline은 textPrimary. 명칭이 직관적이지 않음.

4. **`overline`의 letter-spacing: 1.0**: Toss 원칙에서 letter-spacing 양수(트래킹 확장)는 금지. Toss 텍스트는 -0.1 ~ -2.0 범위의 음수만 사용. `overline` 토큰 자체가 Toss 방향에 반함. 현재 코드에서 `AppTextStyles.overline` 직접 사용은 발견되지 않으나 토큰이 정의 중이므로 사용 가능 상태.

5. **스크린에서 임의 fontSize 72개**: `login_screen.dart`(fontSize: 30), `member_home_screen.dart`(fontSize: 22, 15, 28), `member_workout_screen.dart`(fontSize: 24, 22, 17, 16, 12), `workout_exercise_input.dart`(fontSize: 20, 25) 등. 스케일 토큰을 우회하는 `.copyWith(fontSize: N)` 패턴이 screens 전반에 72곳.

6. **`AppSectionHeader`가 label 토큰을 `.copyWith(fontSize: 15)`로 덮어씀** (app_section.dart line 35): label 토큰(14px)보다 1px 크게 강제. 이 패턴이 여러 위젯에서 반복됨.

---

### Spacing Scale

**현재 scale (`lib/core/app_spacing.dart`)**

```
xxs=2, xs=4, sm=8, md=12, base=16, lg=20, xl=24, xl2=32, xl3=48, xl4=64
section=40, screenH=24, itemV=14
```

**AppRadius**

```
xs=8, sm=12, md=16, lg=20, xl=24, xxl=32, full=9999
```

**문제점**

1. **`section`(40)이 별도 명명**: xl(24)과 xl2(32) 사이에 section(40)이 끼어들어 단계가 불균일. xl2(32) → section(40) → xl3(48)로 8씩 증가하는 것은 4-base grid와 일치하지 않음(xl=24→xl2=32는 8 증가, xl2=32→section=40도 8, section=40→xl3=48도 8. 그러나 section은 네이밍이 semantic이어서 숫자 scale과 혼용 시 혼란).

2. **`itemV`(14)가 유일한 홀수 값**: 4-base grid에서 14는 불규칙. Toss의 기준 grid는 4의 배수(4, 8, 12, 16, 20, 24, 32, 40, 48). itemV=14는 일반적인 grid에 맞지 않음.

3. **`screenH`(24)가 실제로는 AppSpacing.xl과 동일한 값**: 별도 semantic 명칭을 두는 것은 의도가 있으나, 값이 일치하면 혼용 가능성이 생김.

4. **Radius token 사용 일관성 없음**: `lib/screens/member/workout_saved_card.dart`에서 `BorderRadius.circular(12)`, `BorderRadius.circular(999)` 등 AppRadius 미사용 하드코딩이 다수 존재. `workout_exercise_input.dart`에서 `BorderRadius.circular(8)`, `BorderRadius.circular(999)` 사용.

---

## 2. Component Inventory

### app_button.dart

**상태**: 양호. 4 variant(primary, secondary, ghost, danger) × 3 size. 프레스 애니메이션 구현.

**문제점**:
- `secondary` variant의 bg가 `AppColors.bg`(회색 배경)인데, Toss의 secondary 버튼은 보통 흰 배경에 border가 있음. 현재 `hasBorder` 파라미터 없어 outlined 스타일 불가.
- `primary` 버튼의 shadow: `blurRadius: 12, offset: (0, 4), color: brand @ 0.30` — 컬러드 shadow는 Toss 원칙(무채색 shadow)에 반함. `danger` variant도 동일 문제(destructive @ 0.28 shadow).
- `disabled` 상태에서 `textDisabled` 색을 사용하나, primary disabled bg가 `brand.withValues(alpha: 0.35)`로 실제 disabled처럼 보이지 않을 수 있음.

### app_card.dart

**상태**: 양호. 3 variant(standard, tinted, outlined). shadow/border 조합 처리.

**문제점**:
- `hasShadow: true`가 기본값인데, `blurRadius: 16`과 `blurRadius: 4` 두 레이어 shadow 사용. blurRadius 16은 과도함(Toss 기준 카드 shadow는 blurRadius 8 이하).
- InkWell의 `splashColor: AppColors.brand @ 0.04`가 너무 옅어 실질적으로 보이지 않음.
- `padding: EdgeInsets.all(AppSpacing.lg)` 기본값 — lg=20px이 모든 카드에 동일 적용되어 밀도 조절 어려움.

### app_filter_tabs.dart

**상태**: 2개 컴포넌트(AppFilterTabs, AppScrollableChips) 포함.

**문제점**:
- `AppFilterTabs`의 선택된 탭 shadow `blurRadius: 8`은 작은 컴포넌트에 과도함.
- `AppScrollableChips`의 비선택 칩도 shadow 적용: Toss는 chip에 shadow 없음.
- 선택된 tab의 `fontWeight: FontWeight.w700`, 비선택 `FontWeight.w500` — 레이아웃 쉬프트 발생 가능(weight 변화로 글자 너비 변동).
- padding `vertical: 10`이 hardcode — AppSpacing 미사용.
- inner border radius `AppRadius.sm - 2`(= 10)가 계산식 — token 단계에서 처리되어야 함.

### app_icon_box.dart

**상태**: 간단하고 깨끗함.

**문제점**:
- `size: 44` 기본값이 AppSpacing에 없는 값(44는 4-base grid에서 벗어남 — 가장 가까운 값은 xl3=48 또는 xl2=32). Toss 아이콘 박스는 40 또는 48 권장.
- `size * 0.48` 비율 계산으로 아이콘 크기 결정 — 정수 계산 보장 안 됨.

### app_kpi_card.dart

**상태**: top accent bar 제거 완료(주석: "accentColor kept for API compat"). 현재는 icon color에만 accentColor 사용.

**문제점**:
- `blurRadius: 8` shadow — AppCard와 일관성 있으나 직접 Container에 정의. AppCard를 내부적으로 사용하는 것이 더 일관적.
- `numberLarge.copyWith(letterSpacing: -1.5)` — AppTextStyles.numberLarge의 기본 letterSpacing(-1.0)을 override하여 숫자 스타일이 두 개 존재.
- trend 표시에서 `trendUp == true`이면 `AppColors.destructive`(체중 증가 = 위험), `trendUp == false`이면 `AppColors.workout`(감소 = 운동) — 맥락에 따라 색 의미가 달라질 수 있음. 하드코딩된 방향성 판단.

### app_nav_bar.dart

**상태**: floating pill 스타일. AppFloatingPlusButton이 빈 SizedBox.shrink()로 비활성화.

**문제점**:
- `blurRadius: 40, offset: (0, 12)` — 과도한 그림자. Toss nav bar는 상단 border 1px만 사용하거나 매우 옅은 shadow.
- `padding: EdgeInsets.fromLTRB(40, 0, 40, bottom + 20)` — 좌우 margin 40px이 하드코딩. AppSpacing 미사용.
- 탭 레이블 `fontSize: 11, fontWeight: active ? w700 : w500` — AppTextStyles 미사용. `captionSmall` 토큰(11px, w500)을 사용해야 하나 직접 TextStyle 생성.
- `withValues(alpha: 0.97)` background — 완전 불투명이면 그냥 `AppColors.navBg` 사용 가능.

### app_profile_card.dart

**상태**: gradient 파라미터가 제거되고 단색 avatarColor로 전환됨. 양호.

**문제점**:
- `blurRadius: 8, offset: (0, 2)` shadow — 적절함. 문제없음.
- 역할 badge padding `horizontal: 10, vertical: 5` — AppSpacing 미사용(sm=8, md=12 사이).
- 아바타 `size: 56` — AppSpacing에 없는 값.

### app_screen_header.dart

**상태**: 뒤로가기 버튼 포함 가능한 헤더.

**문제점**:
- 뒤로가기 버튼 container에 `blurRadius: 10, offset: (0, 3)` shadow — 작은 버튼에 불필요한 shadow. Toss는 아이콘 버튼에 shadow 없음.
- `bottom: AppSpacing.xl`(24px) padding 기본 — 화면마다 다른 간격 필요 시 조절 불가.
- back button icon `size: 17` — AppSpacing 스케일에 없는 값. 보통 아이콘은 20 또는 24.

### app_section.dart

**상태**: AppSectionHeader + AppEmptyState 포함.

**문제점**:
- `AppSectionHeader`에서 `label.copyWith(fontSize: 15)` — label 토큰(14px)을 우회하는 하드코딩. token 계층 위반.
- `accentColor` 파라미터가 API 호환 목적으로 남아있으나 시각적으로 미사용 — 혼란을 주는 dead parameter. 제거 또는 deprecation 표시 필요.
- `AppEmptyState` icon container `size: 64` — AppSpacing 없는 값(xl3=48, xl4=64). xl4=64와 동일이므로 AppSpacing.xl4 사용 가능.

### app_text_field.dart

**상태**: focus 상태 전환, validator, obscure toggle 구현. 양호.

**문제점**:
- `fillColor: _focused ? AppColors.card : AppColors.bg` — focus 시 흰 배경으로 전환. Toss의 input field는 항상 동일 배경, focus 표시는 border만 사용.
- `labelStyle: AppTextStyles.bodySmall.copyWith(color: ...)` — 라벨이 14px bodySmall. Toss input은 label 대신 placeholder 패턴 권장.
- `prefix` padding `EdgeInsets.only(left: 16, right: 12)` — 하드코딩. AppSpacing.base, AppSpacing.md 사용 가능.

### app_action_row.dart

**상태**: 리스트 행 컴포넌트 + AppRowDivider. 구조 양호.

**문제점**:
- `padding: EdgeInsets.symmetric(vertical: AppSpacing.md + 2)` — `md + 2 = 14`가 AppSpacing.itemV(14)와 동일한 값인데 계산식으로 표현. itemV 사용 가능.
- `badgeColor` default가 AppColors.brand — 뱃지 색이 항상 파란색으로 통일되어 버림.
- icon container `size: 40` — AppSpacing.xl2(32)과 불일치. 일관된 icon box 사이즈 필요.

---

## 3. Page Inventory

### Auth Flow
- `LoginScreen` — `lib/screens/login_screen.dart`
- `SplashScreen` — `lib/screens/splash_screen.dart`
- `PendingApprovalScreen` — `lib/screens/pending_approval_screen.dart`

### Member Flow
- `OnboardingBasicScreen`, `OnboardingBodyScreen` — `lib/screens/member/onboarding_screens.dart`
- `MemberHomeScreen` (홈, 캘린더, PT, 마이 탭) — `lib/screens/member/member_home_screen.dart`
- `MemberMealLogScreen` — `lib/screens/member/member_meal_log_screen.dart`
- `MemberWorkoutScreen` — `lib/screens/member/member_workout_screen.dart`
- `MemberWorkoutStatsScreen` — `lib/screens/member/member_workout_stats_screen.dart`
- `MemberFeedbackScreen` — `lib/screens/member/member_feedback_screen.dart`
- `MemberPtScheduleScreen` — `lib/screens/member/member_pt_schedule_screen.dart`
- `MemberProfileScreen` — `lib/screens/member/member_profile_screen.dart`
- `MemberCalendarScreen` — `lib/screens/member/member_calendar_screen.dart`
- `MemberPtWorkoutScreen` — `lib/screens/member/member_pt_workout_screen.dart`
- `MemberRegisterScreen` — `lib/screens/member/member_register_screen.dart`
- `MemberShareSettingsScreen` — `lib/screens/member/member_share_settings_screen.dart`

### Trainer Flow
- `TrainerHomeScreen` (홈, 일정, 마이 탭) — `lib/screens/trainer/trainer_home_screen.dart`
- `TrainerScheduleScreen` — `lib/screens/trainer/trainer_schedule_screen.dart`
- `TrainerMemberDetailScreen` — `lib/screens/trainer/trainer_member_detail_screen.dart`
- `TrainerPtWorkoutScreen` — `lib/screens/trainer/trainer_pt_workout_screen.dart`
- `TrainerRegisterScreen` — `lib/screens/trainer/trainer_register_screen.dart`

### Admin Flow
- `AdminHomeScreen` (홈, 회원, 트레이너, 마이 탭) — `lib/screens/admin/admin_home_screen.dart`
- `AdminDashboardScreen` — `lib/screens/admin/admin_dashboard_screen.dart`
- `AdminMemberListScreen` — `lib/screens/admin/admin_member_list_screen.dart`
- `AdminMemberDetailScreen` — `lib/screens/admin/admin_member_detail_screen.dart`
- `AdminRequestsScreen` — `lib/screens/admin/admin_requests_screen.dart`
- `AdminTrainerListScreen` — `lib/screens/admin/admin_trainer_list_screen.dart`
- `AdminRegisterScreen` — `lib/screens/admin/admin_register_screen.dart`

---

## 4. 발견된 Visual 불일치 문제

### Gradient 남용 (Toss 원칙 위반)

Toss는 UI 요소에 gradient를 사용하지 않음. 단색 + 투명도 조합을 원칙으로 함.

현재 `LinearGradient` 사용 위치 **13곳**:

| 파일 | 위치 | 내용 |
|---|---|---|
| `member_home_screen.dart:371` | `_GreetingHeader` 아바타 | `brand → #0055C8` |
| `member_home_screen.dart:408` | `_TodayWorkoutHero` 배경 | `brand → #0044B8` |
| `trainer_home_screen.dart:719` | 트레이너 PT 카드 | gradient 배경 |
| `admin_home_screen.dart:197` | 관리자 헤더 아이콘 | `#2C2C2E → #48484A` |
| `login_screen.dart:280` | 로그인 hero 배경 | `brand → #0044B8` |
| `pending_approval_screen.dart:31` | 아이콘 배경 | gradient |
| `member_feedback_screen.dart:225` | 피드백 카드 | gradient |
| `member_pt_schedule_screen.dart:312` | PT 일정 카드 | gradient |
| `member_profile_screen.dart:245` | 프로필 카드 | gradient |
| `admin_requests_screen.dart:266` | 요청 카드 | gradient |
| `admin_trainer_list_screen.dart:267` | 트레이너 아바타 | gradient |
| `admin_member_detail_screen.dart:155` | 회원 상세 헤더 | gradient |
| `admin_member_list_screen.dart:327` | 회원 목록 아바타 | gradient |

**가장 심각한 위반**: `_TodayWorkoutHero`(member_home_screen.dart:406-425) — 화면 전면 gradient 배경 + `blurRadius: 24` colored shadow(brand @ 0.35). Toss 홈 카드는 단색 brand 배경에 shadow 없거나 무채색 shadow.

---

### Accent Bar 장식 제거 진행 중 (부분 완료)

- `AppSectionHeader.accentColor` — 시각적으로 미사용 처리됨(주석: "시각적으로 사용하지 않음"). Dead parameter만 남음.
- `AppKpiCard.accentColor` — top bar 제거 완료(주석: "accentColor kept for API compat — used only for the icon color, not bar").
- **여전히 문제**: `AppSectionHeader` 호출부에서 `accentColor: AppColors.brand`, `accentColor: AppColors.workout` 등이 계속 전달되고 있음 (trainer_home_screen.dart lines 219, 239; admin_home_screen.dart lines 349). Dead code이나 confusion 유발.

---

### Shadow 과도함

`blurRadius >= 16` 사용 위치 **15곳**:

| 파일 | blurRadius | 위치 |
|---|---|---|
| `app_card.dart:39` | 16 | AppCard standard variant |
| `app_nav_bar.dart:43` | 40 | AppNavBar container |
| `pending_approval_screen.dart:40` | 20 | 아이콘 container |
| `login_screen.dart:289` | 20 | hero 카드 |
| `onboarding_screens.dart:453` | 16 | 온보딩 카드 |
| `admin_member_detail_screen.dart:354,399,558,784` | 16 | 상세 섹션들 |
| `member_profile_screen.dart:254` | 20 | 프로필 헤더 |
| `member_meal_log_screen.dart:587` | 16 | 식단 카드 |
| `admin_requests_screen.dart:250` | 16 | 신청 카드 |
| `admin_home_screen.dart:366` | 16 | 관리 메뉴 container |
| `trainer_home_screen.dart:538` | 16 | 일정 리스트 container |
| `trainer_schedule_screen.dart:687` | 16 | 일정 카드 |

Toss 기준: **blurRadius 최대 8**, offset (0, 2) ~ (0, 4), 무채색(black @ 5~8%). 유색 shadow(`brand.withValues(alpha: 0.35)`, blurRadius: 24)는 완전 금지.

---

### Typography 불일치

**`overline` 토큰**: letter-spacing 1.0으로 정의됨 — Toss 원칙(음수 letterSpacing)에 직접 위반. 현재 `AppTextStyles.overline`을 직접 호출하는 코드는 발견되지 않으나, 정의 자체가 Toss 반대 방향.

**임의 fontSize 사용** (72곳, 주요 사례):

| 파일 | 임의 값 | 원래 토큰 기준 |
|---|---|---|
| `member_home_screen.dart:356` | fontSize: 22 | h2=22이므로 h2 직접 사용 가능 |
| `member_home_screen.dart:757` | fontSize: 28 | h1=28이므로 h1 직접 사용 가능 |
| `trainer_home_screen.dart:411` | fontSize: 40 | numberLarge=32에서 벗어남 |
| `login_screen.dart:305` | fontSize: 30 | h1=28과 다른 커스텀 값 |
| `workout_exercise_input.dart:218,337,343` | fontSize: 25 | scale에 없는 중간값 |
| `member_profile_screen.dart:813` | fontSize: 20 | scale에 없는 중간값 |
| `member_workout_screen.dart:1277` | fontSize: primary ? 17 : 16 | 조건부 크기 — 토큰 2개 사용으로 대체 가능 |

**`AppSectionHeader` 내부**: `label.copyWith(fontSize: 15)` — label 토큰이 14px인데 내부에서 15px으로 override (app_section.dart:35). 섹션 헤더 전체에 이 불일치가 전파됨.

---

### Component 패턴 불일치

**카드 스타일 혼재**:

1. `AppCard` 사용: `hasShadow: true, blurRadius: [16, 4]` — 두 레이어 shadow.
2. `AppKpiCard` 직접 Container: `blurRadius: 8, offset: (0, 2)` — 단일 레이어.
3. `_StatCard`(member_home_screen.dart:750): `blurRadius: 12, offset: (0, 4)` — 직접 Container.
4. `_TodayStatsBanner`(trainer_home_screen.dart:378): `blurRadius: 8, offset: (0, 2)` — 직접 Container.
5. `_TodayScheduleList` 비어있을 때/있을 때(trainer_home_screen.dart:505, 533): `blurRadius: 12/16` — 같은 컴포넌트인데 상태에 따라 shadow 다름.

같은 역할의 카드가 최소 5가지 다른 shadow 강도를 사용.

**헤더 패턴 혼재**:

1. `_GreetingHeader`(member_home_screen.dart): gradient 아바타 + RichText h1. 아바타 48×48.
2. `_TrainerGreetingHeader`(trainer_home_screen.dart): 단색 아바타 + RichText h1. 아바타 44×44.
3. `_AdminDashboardTab` 인라인 헤더(admin_home_screen.dart): gradient 아이콘 + h1. 아이콘 48×48.

세 역할의 홈 헤더가 모두 다른 스타일(아바타 크기, gradient 유무, 레이아웃).

---

## 5. Toss 기준 디자인 원칙 (이 앱에 적용할 것)

### Typography

**Toss 원칙**:
- 계층은 최대 5단계 이내(display/title/body/label/caption).
- `letterSpacing`은 항상 음수(한글 가독성을 위한 자간 좁힘).
- `overline`처럼 letter-spacing 양수인 스타일 없음.
- weight 변화로 시각적 강조. scale 우회하는 fontSize 하드코딩 없음.

**이 앱 적용 방안**:
- `h3`와 `headline`을 `title`로 통합(17px, w600).
- `h4`를 `bodyEmphasis`로 개명하거나 제거.
- `overline` 정의 제거.
- `display` 토큰 실 사용처 확인 후 미사용이면 제거.
- screens 전반의 72개 임의 fontSize를 가장 가까운 토큰으로 교체.

### Color

**Toss 원칙**:
- 배경, 서피스, 텍스트, 브랜드, 시맨틱(성공/경고/에러) 5개 카테고리.
- gradient 사용 안 함.
- shadow는 무채색(`rgba(0,0,0,0.04~0.08)`).
- 하나의 의미에 하나의 토큰. alias 남발 금지.

**이 앱 적용 방안**:
- dark legacy 토큰(surface0~3, canvas, separator 계열) 제거(app_bottom_sheet.dart에서 surface1 사용 중 — 같이 수정 필요).
- 20개 alias 정리(primary→brand, background→bg 등으로 사용처 직접 교체 후 alias 제거).
- 모든 `LinearGradient` → 단색 배경으로 교체.
- shadow color를 `Color(0x0A000000)` 등 인라인 hex에서 AppColors.shadow* 토큰으로 추출.
- `bgLogin` = `brandLight`이므로 bgLogin 제거, brandLight 직접 사용.

### Spacing

**Toss 원칙**:
- 4px base grid. 모든 spacing 값이 4의 배수.
- radius도 4의 배수.

**이 앱 적용 방안**:
- `itemV`(14) → 12(AppSpacing.md) 또는 16(AppSpacing.base)으로 교체.
- screens의 hardcoded radius(8, 10, 12, 999) 모두 AppRadius 토큰으로 교체.
- `AppRadius.sm - 2` 계산식 제거, 대신 명시적 토큰(AppRadius.xs=8) 사용.

### Component

**Toss 원칙**:
- 동일 레벨의 컴포넌트는 동일 shadow depth.
- 카드는 border(0.5~1px, border 색) + 최소 shadow 또는 shadow 없음.
- 버튼 shadow에 브랜드 컬러 사용 안 함.
- Nav bar는 상단 border 1px 또는 shadow 최소화.

**이 앱 적용 방안**:
- 모든 카드 shadow를 AppCard의 shadow 또는 새 shadow token으로 통일.
- `AppButton.primary`의 colored shadow 제거.
- `AppNavBar`의 blurRadius:40 shadow를 blurRadius:8 이하로 축소.
- `_GreetingHeader` 아바타 gradient를 단색(`brand.withValues(alpha: 0.12)` 배경 + `brand` 텍스트)으로 교체 — AppProfileCard 아바타 패턴과 통일.

---

## 6. 수정 우선순위

### P0 — 즉시 수정 (Toss 반대 방향)

1. **`_TodayWorkoutHero` gradient 제거** (`member_home_screen.dart:406`) — 앱에서 가장 눈에 띄는 gradient. 단색 brand 배경으로 교체.
2. **hero 카드의 colored shadow 제거** (`member_home_screen.dart:419` — `blurRadius: 24, brand @ 0.35`) — 모든 colored box shadow 제거.
3. **`_GreetingHeader` 아바타 gradient 제거** (`member_home_screen.dart:371`) — `brand → #0055C8`. AppProfileCard 아바타 패턴(단색 + 투명도) 적용.
4. **관리자 헤더 아이콘 gradient 제거** (`admin_home_screen.dart:197` — `#2C2C2E → #48484A`) — 단색으로.
5. **`overline` 토큰 제거 또는 letter-spacing 수정** (`app_text_styles.dart:133`) — letterSpacing: 1.0이 Toss 원칙에 직접 위반.
6. **AppNavBar shadow 축소** (`app_nav_bar.dart:43` — blurRadius: 40) — blurRadius: 8 이하로.
7. **AppButton primary/danger colored shadow 제거** (`app_button.dart:117-131`).

### P1 — 핵심 수정 (불일치)

8. **나머지 12개 gradient 위치 단색 교체** (trainer_home_screen.dart, admin/member 각 screens).
9. **AppCard shadow 축소** (`app_card.dart:37-47` — blurRadius: 16 → 8 이하).
10. **카드 shadow 통일** — `_StatCard`, `_QuickTile`, `_TodayStatsBanner`, `_TodayScheduleList` 등 직접 Container에 정의된 shadow를 AppCard 또는 공통 shadow constant로 통일.
10. **임의 fontSize 72개를 토큰으로 교체** — 우선 스크린별: `member_home_screen.dart`, `trainer_home_screen.dart`, `admin_home_screen.dart`.
11. **AppSectionHeader `fontSize: 15` hardcode 제거** (`app_section.dart:35`) — label(14) 또는 새 토큰으로.
12. **AppActionRow `md + 2` 계산 제거** (`app_action_row.dart:44`) — `AppSpacing.itemV`로 교체.
13. **`accentColor` dead parameter 정리** — AppSectionHeader에서 완전 제거 또는 `@Deprecated` 처리. 호출부(trainer/admin home)도 같이 제거.
14. **screens의 hardcoded borderRadius 교체** — `BorderRadius.circular(12)` → `AppRadius.sm`, `BorderRadius.circular(999)` → `AppRadius.full`, `BorderRadius.circular(8)` → `AppRadius.xs`.

### P2 — 개선 (강화)

15. **shadow color를 AppColors 토큰으로 추출** — `Color(0x0A000000)` 등을 `AppColors.shadowCard`, `AppColors.shadowLight` 등으로 토큰화.
16. **dark legacy 토큰 정리** (`app_colors.dart:70-110`) — surface0~3, canvas, separator 계열 14개 토큰 제거. app_bottom_sheet.dart의 `AppColors.surface1` 사용처 `AppColors.surface2` 또는 직접 Color값으로 임시 대체 후 제거.
17. **alias 20개 정리** (`app_colors.dart:85-106`) — 사용처를 canonical 토큰으로 직접 교체 후 alias 제거.
18. **AppTextField focus UX** — fillColor 전환 제거, border만으로 focus 표시.
19. **`itemV`(14) → 12 또는 16으로 교체** — AppTextField contentPadding 포함.
20. **h3/headline 통합** — 17px w600 중복 제거.
21. **`AppScrollableChips` 비선택 shadow 제거** (`app_filter_tabs.dart:120`).
22. **`AppFloatingPlusButton` 완전 제거** (`app_nav_bar.dart:118`) — `SizedBox.shrink()` 반환으로 dead code.

---

## 7. Changed Files (전체)

수정된 파일 목록 (git status 기준):

```
M lib/core/app_spacing.dart
M lib/core/app_text_styles.dart
M lib/screens/member/member_home_screen.dart
M lib/widgets/app_action_row.dart
M lib/widgets/app_button.dart
M lib/widgets/app_card.dart
M lib/widgets/app_filter_tabs.dart
M lib/widgets/app_icon_box.dart
M lib/widgets/app_kpi_card.dart
M lib/widgets/app_nav_bar.dart
M lib/widgets/app_profile_card.dart
M lib/widgets/app_screen_header.dart
M lib/widgets/app_section.dart
M lib/widgets/app_text_field.dart
```

---

## 8. Next Actions

1. **P0 즉시**: `_TodayWorkoutHero` gradient + colored shadow 단색 전환 (`member_home_screen.dart`). 이것이 가장 눈에 띄는 Toss 위반이므로 우선 처리.

2. **P0 즉시**: `AppButton` colored shadow 제거 (`app_button.dart:117-131`). 모든 버튼에 영향.

3. **P0 즉시**: `AppNavBar` blurRadius:40 → blurRadius:8 (`app_nav_bar.dart:43`).

4. **P1 일괄**: screens 3개 파일(`member_home_screen.dart`, `trainer_home_screen.dart`, `admin_home_screen.dart`)의 나머지 gradient 제거 + 임의 fontSize 교체.

5. **P1**: `AppSectionHeader` `fontSize:15` 하드코딩 제거, `accentColor` dead parameter 제거. 호출부 일괄 정리.

6. **P1**: `AppCard` shadow를 `blurRadius:8` 단일 레이어로 축소. `_StatCard`, `_QuickTile` 등 인라인 shadow를 AppCard로 리팩토링.

7. **P2**: `app_colors.dart` legacy alias 정리(dark 토큰 14개 + alias 20개). 이 작업 전 `app_bottom_sheet.dart:45`의 `surface1` 사용처 교체 필요.

8. **P2**: shadow color AppColors 토큰화 (`shadowLight`, `shadowCard` 등 2개 토큰으로 모든 인라인 shadow color 통일).

9. **Flutter analyze** 실행으로 변경 후 regression 확인. 현재 분석 상태는 별도 추적 중.
