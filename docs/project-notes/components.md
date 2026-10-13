# 공용 컴포넌트 목록

2026-10-11 기준. `lib/widgets/`에 있는 공용 부품을 파일별로 모았다. 치수·색·글자 같은 자세한 값과 쓰는 규칙은 [디자인 시스템](../design-system.md)에 있고, 여기는 **무엇이 어디에 있고 어디서 쓰는지** 찾는 용도다.

"쓰는 화면 수"는 `lib/screens/` 안에서 이름이 나오는 파일 수다 (부품끼리 쓰는 것은 따로 적었다).

## 토큰 (`lib/core/`)

| 파일 | 내용 |
|---|---|
| `app_colors.dart` | `AppColors`(테마 따라 바뀜) · `AppPalette.light/dark`. 바탕 `canvas`, 카드 `canvasCard`, 입력 `canvasSoft`, 글자 `ink`·`body`·`mute`·`faint`, 강조 `primary` #FF7A33, 안내 `noticeBg`/`noticeText`, 새 소식 점 `newDot` |
| `app_spacing.dart` | 간격 2~64, 화면 좌우 `screenH` 20, `AppRadius`(상자 12 · 입력 14 · 버튼 18 · 카드 20 · 시트 28 · pill), `AppSize`(터치 44 · 목록 줄 56 · 버튼 32/40/56) |
| `app_text_styles.dart` | 글자 크기 이름(`displayMd` 28 탭 제목 · `title` 20 · `section` 17 · `listTitle` 16 · `bodyMd` 15 · `note` 14 · `bodySm` 13 · `badge` 11), `.bold` |
| `app_icons.dart` | Phosphor 아이콘 이름 모음 (`AppIcons.*`, `AppIcons.bold()`) |
| `app_theme.dart` | 라이트·다크 `ThemeData`, `ThemeController` |
| `app_feedback.dart` | `AppFeedback.show*` 토스트 띄우기(경고는 묵직한 진동, 완료는 가벼운 진동), `AppErrorCard` |
| `app_haptics.dart` | `AppHaptics` 진동 한곳 관리 — `selection`(탭) · `light`(세트 추가) · `success`(세트 완료·저장) · `warning`(경고·삭제 확인) · `restWarning`/`restDone`(휴식 알림, 설정과 무관). 마이 '진동'으로 끔 (기기에 저장) |
| `app_routing.dart` | `startRouteFor(user)` — 로그인 뒤 역할·승인 상태로 첫 화면 결정 |
| `workout_timing.dart` | 개인 운동 시간: 알림 10분 · 자동 저장 60분 · 시간 글자 만들기 |
| `exercise_guide_data.dart` | 기본 운동 248개 설명 (근육 · 도구 · 난이도 · 운동 방법). free-exercise-db(Unlicense)를 우리말로 옮김, 없는 것 51개는 직접 씀. 트레이너 검수 전. 모양은 `models/exercise_guide.dart` |
| `exercise_data.dart` · `food_guide_data.dart` | 종목 목록(7부위 248개, 한 이름은 한 부위에만) · 맨몸 운동 목록 `bodyweight`(무게 칸 숨김) · 버티는 운동 `timed`('초') · 영양 가이드 내용 (앱 안 자료) |
| `validators.dart` · `birth_date.dart` · `firestore_date.dart` · `relative_time.dart` | 입력 검사 · 생년월일 · 날짜 변환 · '3분 전' |

## 화면 뼈대

| 부품 | 파일 | 하는 일 | 쓰는 화면 수 |
|---|---|---|---|
| `AppHero` | `app_hero.dart` | 탭 화면 맨 위: 28 제목 + 오른쪽 아이콘 버튼 | 11 |
| `AppMonthHeader` | `app_hero.dart` | 화면 폭 섹션 머리말: 라벨 + 오른쪽 개수 (`strong`·`bold`) | 18 |
| `AppScreenHeader` | `app_screen_header.dart` | 하위 화면 앱바: 뒤로 + 제목 + 오른쪽 행동. `.centered`(회원) · `.large`(가입·알림·공지) | 21 |
| `AppNavBar` · `AppNavItem` | `app_nav_bar.dart` | 하단 탭. `dotIndexes`로 새 소식 점 | 6 |
| `AppBottomActionBar` | `app_inputs.dart` | 아래 고정 주 행동 버튼 띠 | 7 |
| `AppAsyncBody` | `app_async_body.dart` | 불러오는 중 · 오류 · 빈 상태 · 내용을 한 번에 처리 | 7 |
| `AppLoader` · `AppLoadingView` | `app_loader.dart` | 점 세 개 로딩 (화면 / 줄 안) | 11 · 13 |
| `AccountStatusListener` | `account_status_listener.dart` | 계정이 거절·탈퇴되면 바로 내보내기 | `main.dart` |

## 목록 · 메뉴

| 부품 | 파일 | 하는 일 | 쓰는 화면 수 |
|---|---|---|---|
| `AppActionRow` · `AppRowDivider` | `app_action_row.dart` | 아이콘 상자 + 제목 + 보조 줄 + 오른쪽(값·화살표). `menu:`는 마이 메뉴 줄 | 8 |
| `AppMenuGroup` | `app_action_row.dart` | 마이 탭 묶음 (띠 + 머리말 + 메뉴 줄들) | 3 |
| `AppSectionBand` | `app_action_row.dart` | 8 높이 회색 띠 (구역 나누기) | 여러 곳 |
| `AppListRow` · `AppDateCell` | `app_action_row.dart` | 아이콘 없는 두 줄 목록 (관리자 목록) · 왼쪽 날짜 칸 | 5 · 2 |
| `AppKeyValueRow` | `app_key_value_row.dart` | 52 키/값 줄 | 2 |
| `CenterListRow` | `center_list_row.dart` | 가입 때 센터 고르기 줄 (`selected` 주황 체크) | 1 |
| `AppEmptyState` · `AppEmptyLine` | `app_section.dart` | 화면 전체 빈 상태 · 목록 자리 빈 줄 | 16 · 8 |

## 카드 · 숫자

| 부품 | 파일 | 하는 일 | 쓰는 화면 수 |
|---|---|---|---|
| `AppHighlightCard` | `app_highlight.dart` | 주황 강조 카드 (PT 남은 횟수, 오늘 PT). `bold`·`compact` | 3 |
| `AppAccentBar` | `app_highlight.dart` | 64 강조 띠 (관리자 '가입 요청 3건') | 1 |
| `AppInlineNotice` | `app_highlight.dart` | 연한 주황 안내 줄 | 4 |
| `AppFloatingAction` | `app_highlight.dart` | 떠 있는 검정 버튼 ('PT 예약') | 2 |
| `AppCard` | `app_card.dart` | 회색 면 + 테두리 한 덩어리 | 1 |
| `AppKpiCard` · `AppStatStrip` · `AppStatGrid` | `app_kpi_card.dart` | 숫자 칸 | 4 · 3 · 2 |
| `AppProgressBar` | `app_progress_bar.dart` | 진행 막대 | 2 |
| `AppRing` · `AppRankBar` · `AppColumnChart` | `app_charts.dart` | 관리자 대시보드 그래프 | 1 |
| `AppProfileRow` · `AppProfileCard` | `app_profile_card.dart` | 마이 맨 위 프로필 줄 · 관리자 회원 상세 머리 | 3 · 2 |
| `AppIconBox` | `app_icon_box.dart` | 40 아이콘 상자 | 4 |

## 버튼 · 입력

| 부품 | 파일 | 하는 일 | 쓰는 화면 수 |
|---|---|---|---|
| `AppButton` | `app_button.dart` | primary · secondary · ghost · danger · dangerText · dark / sm · md · row · lg · dialog | 16 |
| `AppIconButton` | `app_icon_button.dart` | 44 아이콘 버튼 (`label` 필수, `showDot`) | 11 |
| `NotificationBellButton` | `notification_bell_button.dart` | 알림 종 + 안 읽은 점 | 3 |
| `AppTextField` · `AppFieldError` | `app_text_field.dart` | 입력창 (`unit`·`showCounter`·`showVisibilityToggle`) · 오류 문구 | 16 |
| `AppStepper` | `app_inputs.dart` | − 값 + 조절 | 1 |
| `showAppDatePicker` | `app_inputs.dart` | 날짜 고르기 시트 | 3 |
| `AppChip` · `AppScrollableChips` | `app_tag.dart` · `app_filter_tabs.dart` | 선택 pill · 가로로 넘기는 pill 줄 | 5 · 2 |
| `AppSwitch` · `AppSwitchRow` | `app_switch.dart` | 스위치 · 스위치 줄 (공지 작성) | 1 |
| `GenderSelector` | `gender_selector.dart` | 성별 고르기 | 2 |
| `SetValueField` · `SetDoneButton` | `set_input.dart` | 세트 값 상자 · 완료 원. 값 상자 밖을 누르면 키패드를 내린다 (세트 칸끼리는 같은 묶음이라 옮겨 감) | 2 |

## 시트 · 확인 창 · 알림

| 부품 | 파일 | 하는 일 | 쓰는 화면 수 |
|---|---|---|---|
| `showAppBottomSheet` · `AppBottomSheetHeader` · `AppSheetAction` | `app_bottom_sheet.dart` | 하단 시트와 그 머리 · 행동 줄 | 12 |
| `showAppConfirmDialog` · `AppWarningCallout` | `app_confirm_dialog.dart` | 확인 창 (2열 버튼) · 주황 경고 상자 | 9 |
| `AppToast` | `app_toast.dart` | 화면 위쪽 검정 토스트 (보통은 `AppFeedback`으로 띄운다) | 3 |
| `FeedbackSheet` · `FeedbackQuote` | `feedback_sheet.dart` | 트레이너 피드백 작성 시트 · 피드백 상자 | 2 · 1 |
| `SentFeedbackRow` | `screens/trainer/trainer_sent_feedback_screen.dart` | 보낸 피드백 한 줄 (종류 · 대상 날짜 · 수정됨 · 읽음 · ⋯) | 1 |
| `showPasswordResetSheet` · `ForgotPasswordLink` | `password_reset_sheet.dart` | 비밀번호 재설정 메일 | 4 · 1 |
| `DeleteAccountLink` (+ 탈퇴 시트) | `delete_account_sheet.dart` | 마이 맨 아래 탈퇴 | 2 |
| `showWorkoutDurationSheet` | `workout_duration_sheet.dart` | 운동 시간 분 조절 | 2 |
| `NoticeBanner` · `NoticeArticle` · `showImportantNoticeSheet` | `notice_widgets.dart` | 홈 공지 한 줄 · 공지 본문 · 중요 공지 시트 | 1 · 2 · 1 |
| `ThemeSettingRow` · `HapticsSettingRow` | `theme_setting_row.dart` | 마이 '화면 테마' 줄 · '진동' 스위치 줄 | 3 |

## 달력

| 부품 | 파일 | 하는 일 | 쓰는 화면 수 |
|---|---|---|---|
| `AppViewTabs` | `app_calendar.dart` | 보기 고르기 pill (오늘 · 캘린더 · 기록) | 5 |
| `AppMonthNav` · `AppNavArrow` | `app_calendar.dart` | 월 이동 · 화살표 | 여러 곳 |
| `AppCalendarGrid` · `AppWeekDay` | `app_calendar.dart` | 한 달 달력 · 주간 날짜 칸 | 2 · 3 |
| `CalendarMarkRow` · `CalendarLegend` · `buildCalendarMarks` | `calendar_marks.dart` | 날짜 아래 표시(PT 완료·예약·개인 운동)와 범례 | 2 |

## 운동 · 식단

| 부품 | 파일 | 하는 일 | 쓰는 화면 수 |
|---|---|---|---|
| `WorkoutPickerRow` · `WorkoutSavedExerciseRow` · `WorkoutCollapsedRow` · `WorkoutSummaryStats` · `DoneConfirmButton` | `workout_parts.dart` | 회원·트레이너 운동 화면 공용. 고르기 줄은 `onInfo`로 끝 ⓘ. 저장된 종목 줄은 메모가 있으면 아래 메모 줄 | 2씩 |
| `showExerciseGuideSheet` · `ExerciseGuideSettings` · `ExerciseHistory` | `exercise_guide_sheet.dart` | 종목 설명 시트(설명 · 기록 · 설정). 근육 그림은 `muscle_map` 패키지(앞 · 뒤 한 장 `Maps.BODY`, 나머지 근육도 '없음'으로 넘겨 회색 채움). 옛 종목 메뉴 시트 · 휴식 시간 3열 시트를 대신한다 | 2 |
| `ExerciseNoteLine` · `showExerciseNoteSheet` · `isBodyweightExercise` · `strengthCountLabel` | `workout_parts.dart` | 종목 메모 한 줄(아이콘 14 + 13) · 메모 시트 · 맨몸 운동인지 · '회'/'초' | 3 |
| `RestTimer` · `RestTimerBar` · `showRestTimerSheet` · `startRestTimer` | `rest_timer.dart` | 앱 전체 휴식 타이머 하나. 남은 시간은 끝나는 시각 기준. 10초 전·끝 알림은 `services/rest_timer_alerts.dart`(`RestTimerAlerts`: 앞이면 바로 진동, 뒤로 가면 기기 알림 예약, 안드로이드 알림 센터 남은 시간, 아이폰 잠금 화면 · 다이내믹 아일랜드는 채널 `refit/rest_activity` → `ios/Runner/RestTimerActivityPlugin.swift` → 위젯 `ios/RestTimerWidget/`) | 2 |
| `AppNetworkPhoto` | `app_network_photo.dart` | 인터넷 사진 — 기기에 저장(`cached_network_image`) + 칸 크기 × 화면 배율로 줄여 풂, 받는 동안 회색 · 실패 시 사진 아이콘. 식단 피드 사진 · 회원 식단 사진 칸 | 2 |
| `MealFeedList` · `MealFeedCard` | `meal_feed.dart` | 트레이너 식단 피드 (식단 탭 · 회원 상세 식단 탭). 칼로리는 보이지 않는다. `guideFor`(사진 아래 끼니 가이드) · `hasPlanFor`(자주 쓰는 말 `goalPhrases` / `basicPhrases`) · `onMemberTap` · `onEditFeedback` · `onDeleteFeedback`(내 말풍선 ⋯) | 2 |
| `TrainerMemberRow` · `openTrainerMemberDetail` | `screens/trainer/trainer_members_screen.dart` | 트레이너 회원 탭의 회원 줄 · 회원 상세 열기(식단 피드 · PT 기록 · 일정이 함께 씀). 요약은 `services/trainer_members_service.dart`(`TrainerMemberSummary` · `TrainerMemberFilter`) | 4 |
| `ConsentChecklist` · `showConsentDocument` | `consent_checklist.dart` | 가입 동의 묶음(전체 · 개인정보 · 건강 정보, '보기' → 전문 시트). 문구 · 판은 `core/consent_terms.dart` | 2 |
| `NutritionGoalStrip` | `nutrition_plan_card.dart` | 트레이너 식단 탭 목표 줄 (정한 값만 · 칼로리 첫째 줄 · 탄단지 둘째 줄 · 끼니 가이드 / 목표 없음 '정하기') | 1 |
| `openNutritionPlanEditor` | `screens/trainer/nutrition_plan_screen.dart` | 인바디 · 신체 정보를 읽어 식단 목표 화면을 연다 (식단 탭에서) | 1 |
| `NutritionPlanCard` | `nutrition_plan_card.dart` | 식단 목표 카드 (회원 식단 화면 맨 위 · 트레이너 회원 상세 식단 탭 맨 위, `onEdit`이면 '고치기'/'정하기'). 자료는 `models/nutrition_plan.dart` · `services/nutrition_plan_service.dart` (`nutrition_plans/{memberId}`) | 2 |

## 로그인 · 그림 · 움직임

| 부품 | 파일 | 하는 일 |
|---|---|---|
| `AuthHeading` · `AuthTextLink` | `auth_parts.dart` | 로그인·가입 가운데 제목 · 아래 글자 링크 |
| `FlameIcon` · `PendingClockMark` · `MealBowlIllustration` · `LiftingBarbellMark` · `EnvelopeMark` | `brand_marks.dart` | 연속 운동 불꽃 · 승인 대기 시계 · 식단 그릇 · 빈 기록 바벨 · 메일 봉투 |
| `AppEntrance` · `AppPulse` · `AppGrow` · `AppPop` · `AppShake` · `AppBlink` · `AppFloat` · `AppMotion` | `app_motion.dart` | 시안 키프레임대로 움직임 (`AppEntrance` 24곳). 기기 '동작 줄이기'면 멈춤 |

## 정리할 것

화면에서 쓰지 않는 부품 — 지우거나 쓰기로 정한다.

- `AppFilterTabs` (`app_filter_tabs.dart`) — `AppScrollableChips`·`AppViewTabs`로 대신하고 있음
- `AppSectionHeader` (`app_section.dart`) — `AppMonthHeader`로 대신하고 있음
- `NoticeTile` (`notice_widgets.dart`)
- `StatusBadge` (`status_badge.dart`) — 기록 줄에 상태 태그를 두지 않기로 해서 남음
