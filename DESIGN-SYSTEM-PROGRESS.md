# BurnFit Design System — Progress

> 최종 업데이트: 2026-09-06
> `flutter analyze`: No issues found

---

## 1. 아키텍처 개요

```
Brand Identity
  └─ Design Principles (Toss 참조: 명확성, 일관성, 계층적 정보 구조)
       └─ Foundations
            ├─ Color Tokens    → lib/core/app_colors.dart
            ├─ Spacing Tokens  → lib/core/app_spacing.dart
            ├─ Typography      → lib/core/app_text_styles.dart
            └─ Theme           → lib/core/app_theme.dart
                 └─ Components → lib/widgets/app_*.dart
                      └─ Pages → lib/screens/**/*.dart
```

---

## 2. Foundation Tokens

### 2-1. Color (`app_colors.dart`)

| 카테고리 | 토큰 | 값 | 용도 |
|---------|------|-----|------|
| **Brand** | `brand` | `#0A84FF` | 주요 액션, 선택 상태 |
| | `brandDark` | `#0066CC` | 버튼 pressed |
| | `brandLight` | `#EAF2FF` | 브랜드 배경 |
| **Accent** | `workout` | `#3E9C5C` | 운동 관련 |
| | `diet` | `#D98A3D` | 식단 관련 |
| | `trainer` | `#8C7FC4` | 트레이너 관련 |
| | `destructive` | `#E15361` | 삭제, 경고 |
| **Background** | `bg` | `#F2F2F7` | 페이지 배경 |
| | `bgElevated` | `#FFFFFF` | 모달 배경 |
| | `bgLogin` | `#EAF2FF` | 로그인 배경 |
| **Surface** | `card` | `#FFFFFF` | 카드, 컨테이너 |
| | `cardHover` | `#F8F8FA` | 호버/프레스 |
| **Text** | `textPrimary` | `#1C1C1E` | 주요 텍스트 |
| | `textSecondary` | `#3C3C43` 60% | 보조 텍스트 |
| | `textTertiary` | `#3C3C43` 40% | 힌트, 비활성 |
| | `textDisabled` | `#3C3C43` 30% | 비활성 |
| | `textOnAccent` | `#FFFFFF` | 액센트 위 텍스트 |
| **Border** | `border` | `#3C3C43` 12% | 기본 테두리 |
| | `borderFocus` | `#0A84FF` | 포커스 상태 |
| **Status** | `success` | `#30D158` | 성공 |
| | `warning` | `#FFD60A` | 경고 |
| | `error` | `#FF453A` | 에러 |
| **Nav** | `navBg` | `#FFFFFF` | 내비게이션 배경 |
| | `navBorder` | `#3C3C43` 12% | 내비게이션 테두리 |

> `member*` alias는 전체 사용처에서 제거 완료 후 정의도 삭제됨. `surface*`, `label*` 등은 다크 화면(splash/pending/login)에서만 사용.

### 2-2. Spacing (`app_spacing.dart`)

| 토큰 | 값 | 용도 |
|------|-----|------|
| `xxs` | 4 | 최소 간격 |
| `xs` | 8 | 요소 내부 |
| `sm` | 12 | 컴팩트 간격 |
| `md` / `base` | 16 | 기본 간격 |
| `lg` | 24 | 섹션 내부 |
| `xl` | 32 | 섹션 간 |
| `xl2` | 48 | 대형 간격 |
| `screenH` | 20 | 화면 수평 패딩 |
| `itemV` | 14 | 리스트 아이템 수직 패딩 |

| Radius | 값 | 용도 |
|--------|-----|------|
| `xs` | 6 | 칩, 뱃지 |
| `sm` | 10 | 버튼, 입력 |
| `md` | 14 | 중간 카드 |
| `lg` | 16 | 카드 |
| `xl` | 20 | 대형 카드 |
| `xxl` | 28 | 내비게이션 바 |
| `full` | 9999 | 원형 |

### 2-3. Typography (`app_text_styles.dart`)

| 스타일 | Size | Weight | 용도 |
|--------|------|--------|------|
| `display` | 36 | w800 | 대형 숫자/제목 |
| `h1` | 26 | w700 | 페이지 제목 |
| `h2` | 22 | w700 | 섹션 제목 |
| `h3` | 18 | w700 | 카드 제목 |
| `h4` | 16 | w600 | 소제목 |
| `headline` | 17 | w600 | 강조 본문 |
| `body` | 15 | w400 | 기본 본문 |
| `bodyLarge` | 17 | w400 | 큰 본문 |
| `bodySmall` | 14 | w400 | 작은 본문 |
| `caption` | 12 | w500 | 캡션 |
| `captionSmall` | 11 | w500 | 작은 캡션 |
| `label` | 13 | w600 | 라벨 |
| `button` | 16 | w600 | 버튼 텍스트 |
| `stat` | 48 | w700 | 통계 숫자 |
| `numberLarge` | 32 | w700 | 큰 숫자 |

> 폰트: Pretendard (400–900). 기본 letterSpacing: -0.1

---

## 3. Components

| 파일 | 위젯 | 설명 |
|------|------|------|
| `app_card.dart` | `AppCard` | 통합 카드. `color`, `hasBorder`, `hasShadow`, `onTap` |
| `app_section.dart` | `AppSectionHeader`, `AppEmptyState` | 섹션 헤더 + 빈 상태 |
| `app_action_row.dart` | `AppActionRow`, `AppRowDivider` | 설정/메뉴 행. 아이콘+라벨+뱃지+chevron |
| `app_kpi_card.dart` | `AppKpiCard` | KPI 카드. label, value, unit, icon, isHighlight |
| `app_profile_card.dart` | `AppProfileCard` | 프로필 카드. 이니셜 아바타+이름+역할 |
| `app_icon_box.dart` | `AppIconBox` | 색상 아이콘 박스 |
| `app_nav_bar.dart` | `AppNavBar`, `AppNavItem` | 플로팅 하단 내비게이션 |
| `app_button.dart` | `AppButton` | 통합 버튼 |
| `app_text_field.dart` | `AppTextField` | 통합 텍스트 필드 |
| `app_bottom_sheet.dart` | `AppBottomSheet` | 바텀 시트 |
| `app_filter_tabs.dart` | `AppFilterTabs` | 필터 탭 바 |

---

## 4. 적용 현황

### Theme
| 항목 | 상태 |
|------|------|
| `Brightness.light` 전환 | ✅ |
| ColorScheme.light() | ✅ |
| AppBar, Input, Button, Card, SnackBar 테마 | ✅ |
| `AppTheme.dark` → `light` 포워딩 | ✅ |

### Screens — Token 통합 (`member*` → 통합 토큰)

| 역할 | 파일 | 상태 |
|------|------|------|
| **Admin** | `admin_home_screen.dart` | ✅ 완료 + 컴포넌트 적용 |
| | `admin_dashboard_screen.dart` | ✅ 토큰 교체 |
| | `admin_member_list_screen.dart` | ✅ 토큰 교체 |
| | `admin_trainer_list_screen.dart` | ✅ 토큰 교체 |
| | `admin_member_detail_screen.dart` | ✅ 토큰 교체 |
| | `admin_requests_screen.dart` | ✅ 토큰 교체 |
| | `admin_register_screen.dart` | ✅ 토큰 교체 |
| **Trainer** | `trainer_home_screen.dart` | ✅ 완료 + 컴포넌트 적용 |
| | `trainer_schedule_screen.dart` | ✅ 토큰 교체 |
| | `trainer_member_detail_screen.dart` | ✅ 토큰 교체 |
| | `trainer_pt_workout_screen.dart` | ✅ 토큰 교체 |
| | `trainer_register_screen.dart` | ✅ 토큰 교체 |
| **Member** | `member_home_screen.dart` | ✅ 토큰 교체 |
| | `member_calendar_screen.dart` | ✅ 토큰 교체 |
| | `member_feedback_screen.dart` | ✅ 토큰 교체 |
| | `member_meal_log_screen.dart` | ✅ 토큰 교체 |
| | `member_profile_screen.dart` | ✅ 토큰 교체 |
| | `member_pt_schedule_screen.dart` | ✅ 토큰 교체 |
| | `member_pt_workout_screen.dart` | ✅ 토큰 교체 |
| | `member_register_screen.dart` | ✅ 토큰 교체 |
| | `member_share_settings_screen.dart` | ✅ 토큰 교체 |
| | `member_workout_screen.dart` | ✅ 토큰 교체 |
| | `member_workout_stats_screen.dart` | ✅ 토큰 교체 |
| | `onboarding_screens.dart` | ✅ 토큰 교체 |
| **공통** | `login_screen.dart` | ✅ 토큰 교체 |
| | `splash_screen.dart` | ✅ (dark 레거시 유지) |
| | `pending_approval_screen.dart` | ✅ (dark 레거시 유지) |

### Widgets — Token 통합

| 파일 | 상태 |
|------|------|
| `app_nav_bar.dart` | ✅ |
| `app_button.dart` | ✅ |
| `app_text_field.dart` | ✅ |
| `app_bottom_sheet.dart` | ✅ |
| `app_filter_tabs.dart` | ✅ |
| `feedback_sheet.dart` | ✅ |
| `status_badge.dart` | ✅ |

---

## 5. 위젯 중복 제거

| 제거된 중복 코드 | 대체 컴포넌트 | 출처 |
|-----------------|-------------|------|
| `_KpiCard` (admin_home, admin_dashboard) | `AppKpiCard` | 신규 |
| `_ActionRow`, `_RowDivider` (admin_home) | `AppActionRow`, `AppRowDivider` | 신규 |
| `_ProfileAction` (admin_home, trainer_home) | `AppActionRow` | 신규 |
| `_EmptyMembers` (trainer_home) | `AppEmptyState` | 신규 |
| Profile card 패턴 (admin, trainer) | `AppProfileCard` | 신규 |

---

## 6. 후속 작업 (미완료)

| 항목 | 우선순위 | 설명 |
|------|---------|------|
| 컴포넌트 적용 확대 | 중 | `AppCard`, `AppKpiCard` 등을 member/trainer 스크린 내부 카드에도 적용 |
| Dark Mode 정식 지원 | 낮 | 현재 light only. dark는 splash/pending만 레거시로 유지 |
| Legacy alias 제거 | 낮 | `surface*`, `label*` 등 다크 전용 레거시 alias — 다크 모드 정식 지원 시 정리 |
| Motion/Animation 토큰 | 낮 | Duration, Curve 표준화 |
| Accessibility 검증 | 중 | 색상 대비, 터치 타겟 크기 등 |

---

## 7. 세션 이어받기 가이드

1. `flutter analyze` → 에러 0 확인
2. 이 문서의 Section 4 "적용 현황" 확인
3. Section 6 "후속 작업" 중 원하는 항목 선택
4. Foundation 토큰은 `lib/core/app_*.dart` 4개 파일에 집중
5. 컴포넌트는 `lib/widgets/app_*.dart`에서 관리
6. 신규 코드에서는 반드시 통합 토큰 사용 (`AppColors.brand`, `AppColors.bg` 등)
7. `member*` 레거시 alias는 이미 삭제됨 — 사용 불가
