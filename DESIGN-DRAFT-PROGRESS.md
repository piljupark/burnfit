# BurnFit 디자인 시안 반영 현황

> 기준 시안: `C:\Users\USER\Downloads\BurnFit-디자인-시안\screens\` (정적 HTML 목업, "미니멀·강조색 하나" #FF7A33 방향 — 2026-10-08 커밋 `9635fe8` 팔레트 기준)
> 조사일: 2026-10-08
> 방법: 시안 HTML과 대응하는 `lib/screens/**/*.dart`, `lib/widgets/*.dart`를 직접 열어 구조·문구·컴포넌트·강조색 사용 여부를 비교. 코드 수정 없이 읽기 전용으로 조사함.
> 범례: ✅ 반영됨 · 🟡 부분 반영(기능은 있으나 레이아웃/컴포넌트/강조색이 시안과 다름) · ❌ 미반영(구현 없음 또는 완전히 다른 구조) · 참고(판정 보류/구버전/범위 외)

## 전체 요약

| 카테고리 | ✅ | 🟡 | ❌ | 참고 | 총계 |
|---|---|---|---|---|---|
| 관리자 (Admin) | 23 | 9 | 0 | 0 | 32 |
| 공지사항 (Notice) | 5 | 4 | 0 | 0 | 9 |
| 트레이너 A (홈/일정/예약) | 12 | 3 | 3 | 0 | 18 |
| 트레이너 B (회원상세/PT기록/피드백/인바디) | 25 | 1 | 1 | 0 | 27 |
| 회원 A (홈/운동/PT/통계) | 19 | 3 | 0 | 3 | 25 |
| 회원 B (프로필/식단/공유) | 18 | 0 | 0 | 1 | 19 |
| 공통 (로그인/온보딩/가입/알림/토스트) | 14 | 5 | 0 | 0 | 19 |
| **합계 (판정 대상만)** | **116** | **25** | **4** | **4** | **149** |

**완전 반영률 ≈ 78%** (116/149, 2026-10-08 공용 이슈 1~4번 + `TrainerPtDone` 신규 구현 + 공지사항 "중요" 강조 체계 반영). 체감상 "대부분 시안대로 안 됐을 것"이라는 예상과 달리, **기능·문구 단위로는 상당히 진행되어 있음** — Admin(72%)·Tr-B(93%)·MemA(76%)·MemB(95%)는 완성도가 매우 높습니다. 남은 🟡(부분 반영) 25건은 공용 패턴 문제가 아니라 화면별 개별 디테일(일러스트 박스, 레이아웃 세부 차이 등)입니다. ❌(미반영) 4건은 전부 신버전으로 이미 대체 구현된 구버전 시안이라 추가 작업이 필요 없습니다.

> **2026-10-08 업데이트 1**: 공용 이슈 1번("강조점" 주황색) 수정 완료 — 캘린더 PT 점, 토글 on, 알림/공지 새 글 점, InBody·영양소 그래프 강조, 공지 핀 아이콘에 주황(`primary`/`newDot`)을 적용해 9개 화면이 🟡→✅로 올라갔습니다. 반대로 `GenderSelector`는 다른 선택 pill들과 달리 주황 채움을 쓰고 있어서 검정(`ink`)으로 통일했습니다(Com-Onboarding-Basic). `docs/design-system.md` 원칙 6번에 예외 조항을 추가했습니다.
>
> **2026-10-08 업데이트 2**: 공용 이슈 2번(`showAppConfirmDialog` 재설계) 수정 완료 — 표준 `AlertDialog`(우측정렬 텍스트 버튼)를 2열 전체폭 버튼으로 교체하고, 파괴적 확정 버튼을 새 `AppButtonVariant.dark`(검정 채움+흰 글자)로 통일. 같은 변경을 `delete_account_sheet.dart`(탈퇴 시트)에도 적용. 4개 화면이 🟡→✅로 올라갔습니다. 다만 Tr-PtRecord/Inbody-DeleteConfirm의 주황빛 경고 콜아웃 박스, Com-DeleteAccount-*의 "복구 불가" 강조 박스는 아직 추가하지 않아 해당 화면들은 🟡로 남아있습니다.
>
> **2026-10-08 업데이트 3**: 공용 이슈 3번(`AppToast` 톤 교체) 수정 완료 — 밝은 카드 배경(canvasCard+hairline)을 검정 채움+둥근 사각형(radius 18)으로, 아이콘은 24px 주황 원 배지로, 제목·본문 글자는 흰색(본문은 70% 투명도), 행동 글자는 주황으로 교체. 8개 화면이 🟡→✅로 올라갔습니다.
>
> **2026-10-08 업데이트 4**: 공용 이슈 4번(경고 콜아웃 박스) 수정 완료 — `showAppConfirmDialog`에 선택적 `warning` 파라미터 추가, 재사용 가능한 `AppWarningCallout` 위젯 신설(주황 배경+경고 아이콘+글자). PT 기록 삭제(마지막 기록 시 잔여 횟수 복구 안내)와 탈퇴 시트("복구 불가" 안내)에 적용. 4개 화면이 🟡→✅로 올라갔습니다. 공용 이슈 1~4번 전부 완료.
>
> **2026-10-08 업데이트 5**: `TrainerPtDone.html` 신규 구현 완료 — `trainer_pt_done_screen.dart`에 `TrainerPtDoneScreen` 신설. PT 기록을 처음 저장해 세션이 완료로 바뀌는 순간 전체화면(주황 배경+흰 카드+잔여 횟수 롤 애니메이션)으로 표시, "확인"/"바로 피드백 쓰기"/"기록 다시 보기" 3가지 행동 지원. 시안의 떠다니는 SVG 일러스트·체크마크 draw 애니메이션은 "장식 애니메이션 금지" 원칙(`docs/design-system.md` 9번)에 따라 생략. 실제로 새로 만들어야 했던 유일한 화면이었고, 이제 ❌(미반영) 4건은 전부 신버전으로 대체된 구버전 시안뿐입니다.
>
> **2026-10-08 업데이트 6**: 공지사항 "중요 공지" 강조 체계 구현 완료 — `NoticeTile`에 `important` 플래그 기반 주황 하이라이트 카드(배경+테두리+핀 아이콘+메타 글자 색), `NoticeArticle`에 "중요 공지" 라벨+센터명(신규 `centerName` 파라미터, 상위 화면들에서 `user.centerName` 전달), `showImportantNoticeSheet`에 주황 메가폰 아이콘 배지+2열 버튼(자세히 보기/확인)+밑줄 텍스트 링크("다시 보지 않기")로 재설계. 3개 화면이 🟡→✅로 올라갔습니다. 공지사항 카테고리가 9건 중 5건 완료(56%)로 가장 낮았던 카테고리에서 크게 개선됐습니다.

>
> **2026-10-08 업데이트 7 (트레이너 전 화면 시안 재대조)**: 이 문서는 `TrainerHome/TrainerSchedule/TrainerReserve/TrainerMember.html`을 "구버전"으로 봤지만, 목차 맨 위 '화면' 묶음이라 **최우선 기준 시안**이다(`docs/design-system.md`). 회원 `Main` 계열과 같은 방식으로 트레이너 전 화면을 다시 그렸다 — 홈(오늘·캘린더 보기, 회원 홈과 같은 달력 부품 `app_calendar.dart`), 일정(주 이동·타임라인·현재 시각 선·'PT 예약' 버튼), 예약 시트(회색 묶음 카드·휠·겹침 안내), 회원 상세(2칸 카드·운동/식단/유산소/정보 pill·고정 2칸 버튼), 인바디 입력·상세 시트, 피드백 시트, PT 기록(회원 운동 화면과 같은 짜임), 운동 시트, PT 완료, 마이(60 메뉴 줄). 아래 트레이너 표의 🟡·❌ 메모는 이 변경 이전 기준이며, 시안과 일부러 다르게 둔 곳은 `docs/design-system.md` '시안과 아직 다른 곳'에 모았다.

## 다음에 손보면 좋은 것 (추천 순서)

화면별로 접근하지 말고 **공용 부품/토큰 레벨**에서 고치면 한 번의 수정으로 10개 이상의 🟡가 ✅로 바뀝니다. 영향도 순서:

1. ~~**"강조점" 주황색 복원**~~ — ✅ 완료(2026-10-08).
2. ~~**`showAppConfirmDialog` 재설계** + **파괴적 버튼 색상 통일**~~ — ✅ 완료(2026-10-08). `AppButtonVariant.dark` 신설, 다이얼로그·탈퇴 시트 모두 2열 버튼+검정 확정 버튼으로 교체.
3. ~~**`AppToast` 톤 교체**~~ — ✅ 완료(2026-10-08). 검정 채움+주황 배지로 교체.
4. ~~**남은 경고 콜아웃 박스**~~ — ✅ 완료(2026-10-08). `AppWarningCallout` 위젯 신설, `showAppConfirmDialog`에 `warning` 파라미터 추가.
5. ~~**`TrainerPtDone.html` 신규 구현**~~ — ✅ 완료(2026-10-08). `TrainerPtDoneScreen` 신설(주황 배경+흰 카드+잔여 횟수 롤 애니메이션), PT 기록 최초 저장 시 자동 표시.
6. **남은 건 전부 화면별 개별 디테일**(🟡 25건) — 일러스트 박스, 레이아웃 세부 차이 등. `TrainerMember.html`(구 IA)은 이미 신버전 탭 구조로 대체 구현됨, 트레이너 A 구버전 3종(`TrainerHome/TrainerSchedule/TrainerReserve.html`)도 신버전으로 대체됨 — 둘 다 별도 작업 불필요.

---

## 작업 중단 지점 (2026-10-08) — 다음에 이어서 하려면

공용 부품 레벨 작업(1~6번)은 여기서 일단 마무리. 전체 반영률 **78%(116/149)**, CI(analyze/test/build) 전부 통과 상태로 `master`에 push 완료.

**다음에 손댈 만한 후보** (화면별 개별 디테일, 우선순위순 — 공용 이슈처럼 한 번에 여러 화면이 풀리진 않음):
- **Admin**: `Ad-MemberDetail.html`의 `AppHighlightCard` 미사용(PT 잔여 강조 박스), `Ad-Requests.html`의 역할 필터 칩 없음 — Admin 카테고리에 🟡 9건 중 가장 눈에 띄는 2건.
- **Nt(공지)**: `Nt-Admin-Detail.html`의 "대상/표시/알림 발송 여부" 요약 카드 없음(관리자가 공지 상태를 확인 못 함 — 기능적 공백), `Nt-Admin-Compose.html`의 글자수 카운터·대상 안내 문구.
- **Tr-A**: `Tr-Reserve-Edit.html`(별도 화면 vs 인라인 시트), `Tr-Reserve-NoMember.html`(필드 흔들림 강조 없음) — 둘 다 경미.
- **MemA**: `Done.html` 전용 운동 완료 화면 없음(현재 스낵바만) — `TrainerPtDone`과 비슷한 성격이라 패턴 재사용 가능.
- **Com(공통)**: `Com-Register-Trainer.html` 오류 상태 강조색, `Com-PasswordReset.html` 일러스트 박스.

전체 목록은 이 문서의 카테고리별 표에서 🟡 상태만 찾으면 됩니다. 새 세션에서 이어가려면 이 문서를 먼저 읽고, 위 "다음에 손보면 좋은 것" 섹션의 번호 이후부터 진행하면 됩니다.

---

## 1. 관리자 (Admin) — 23✅ / 9🟡

| 시안 파일 | 구현 | 상태 | 메모 |
|---|---|---|---|
| Ad-Dashboard.html | `admin_dashboard_screen.dart` | 🟡 | 도넛 게이지 → 텍스트%+AppProgressBar로 단순화 |
| Ad-Home-Error.html | `admin_home_screen.dart` | ✅ | 일치 |
| Ad-Home-NoPending.html | `admin_home_screen.dart` | ✅ | 일치 |
| Ad-Home.html | `admin_home_screen.dart` | ✅ | AppAccentBar·AppKpiCard 2×2·메뉴 5개 일치 |
| Ad-MemberDetail-NoPt.html | `admin_member_detail_screen.dart` | ✅ | 일치 |
| Ad-MemberDetail.html | `admin_member_detail_screen.dart` | 🟡 | PT 잔여 강조 박스(AppHighlightCard) 미사용, 평범한 KPI 칩 |
| Ad-Members-NoResult.html | `admin_member_list_screen.dart` | ✅ | 일치 |
| Ad-Members-Pushed.html | `admin_member_list_screen.dart` | ✅ | 일치 |
| Ad-Members.html | `admin_member_list_screen.dart` | ✅ | 일치 |
| Ad-My-PasswordSheet.html | `password_reset_sheet.dart` | ✅ | 일치 |
| Ad-My-ThemeSheet.html | `theme_setting_row.dart` | ✅ | 일치 |
| Ad-My.html | `admin_home_screen.dart` | ✅ | 일치 |
| Ad-PtInfoLog.html | `admin_member_detail_screen.dart` | 🟡 | 날짜 배치(2줄 좌측 vs 1줄 우측)만 다름 |
| Ad-PtInfoSheet-DatePicker.html | `app_inputs.dart` | ✅ | 일치 |
| Ad-PtInfoSheet-Edit.html | `admin_member_detail_screen.dart` | ✅ | 일치 |
| Ad-PtInfoSheet-Error.html | `admin_member_detail_screen.dart` | ✅ | 일치 |
| Ad-PtInfoSheet-New.html | `admin_member_detail_screen.dart` | ✅ | 일치 |
| Ad-Requests-Empty.html | `admin_requests_screen.dart` | ✅ | 일치 |
| Ad-Requests-RejectDialog.html | `admin_requests_screen.dart` | ✅ | 일치 |
| Ad-Requests.html | `admin_requests_screen.dart` | 🟡 | 역할 필터 칩 없음, 승인/거절 버튼 축소됨 |
| Ad-TrainerDetailSheet-Empty.html | `admin_trainer_list_screen.dart` | ✅ | 일치 |
| Ad-TrainerDetailSheet.html | `admin_trainer_list_screen.dart` | ✅ | 일치 |
| Ad-TrainerPicker.html | `admin_member_detail_screen.dart` | ✅ | 일치 |
| Ad-Trainers.html | `admin_trainer_list_screen.dart` | ✅ | 일치 |
| Ad-Withdrawn-Empty.html | `admin_withdrawn_members_screen.dart` | ✅ | 일치 |
| Ad-Withdrawn.html | `admin_withdrawn_members_screen.dart` | ✅ | 일치 |
| Ad-WithdrawnDetail.html | `admin_withdrawn_members_screen.dart`(상세) | ✅ | 일치 |
| AdminDashboard.html(구) | `admin_dashboard_screen.dart` | 🟡 | 구버전, 신버전(Ad-Dashboard) 구조로 대체 구현됨 |
| AdminHome.html(구) | `admin_home_screen.dart` | 🟡 | 구버전, 신버전(Ad-Home) 구조로 대체 구현됨 |
| AdminMemberDetail.html(구) | `admin_member_detail_screen.dart` | 🟡 | 구버전, 신버전(Ad-MemberDetail) 구조로 대체 구현됨 |
| AdminMembers.html(구) | `admin_member_list_screen.dart` | 🟡 | 구버전, 신버전(Ad-Members) 구조로 대체 구현됨 |
| AdminRequests.html(구) | `admin_requests_screen.dart` | 🟡 | 구버전, 역할 필터 누락은 신/구 공통 이슈 |

## 2. 공지사항 (Notice) — 5✅ / 4🟡

| 시안 파일 | 구현 | 상태 | 메모 |
|---|---|---|---|
| Nt-Admin-Compose.html | `admin_notice_edit_screen.dart` | 🟡 | 글자수 카운터 숨김, 대상 안내 문구 없음, 대상 선택이 그리드 대신 pill |
| Nt-Admin-DeleteConfirm.html | `showAppConfirmDialog` | ✅ | 2열 전체폭 버튼으로 재설계 완료(2026-10-08) |
| Nt-Admin-Detail.html | `admin_notice_detail_screen.dart` | 🟡 | "대상/표시/알림 발송 여부" 요약 카드 없음 |
| Nt-Admin-Empty.html | `admin_notice_list_screen.dart` | ✅ | 문구 일치(아이콘만 다름) |
| Nt-Admin-List.html | `admin_notice_list_screen.dart` | 🟡 | 핀 아이콘 주황 적용 완료(2026-10-08). 남은 차이: 라벨 문구, FAB→헤더 버튼 |
| Nt-Admin-Posted.html | `AppToast` | 🟡 | 토스트 단순화(아이콘/발송 인원 문구 없음) |
| Nt-Detail.html | `notice_detail_screen.dart` | ✅ | "중요 공지" 라벨+센터명 적용 완료(2026-10-08) |
| Nt-ImportantSheet.html | `showImportantNoticeSheet` | ✅ | 주황 아이콘 배지+2열 버튼(자세히보기/확인)+밑줄 링크로 재설계 완료(2026-10-08) |
| Nt-List.html | `notice_list_screen.dart` | ✅ | 중요 공지 주황 하이라이트 카드 적용 완료(2026-10-08). 새 글 점은 이미 주황(1차 수정에서 완료) |

## 3. 트레이너 A — 홈/일정/예약 — 12✅ / 3🟡 / 3❌

| 시안 파일 | 구현 | 상태 | 메모 |
|---|---|---|---|
| Tr-Home-Empty.html | `trainer_calendar_screen.dart` | ✅ | 캘린더 점 주황 적용 완료(2026-10-08) |
| Tr-Home.html | `trainer_calendar_screen.dart` | ✅ | 동일 |
| Tr-Schedule-Empty.html | `trainer_schedule_screen.dart` | ✅ | 동일 |
| Tr-Schedule.html | `trainer_schedule_screen.dart` | 🟡 | 캘린더 점은 해결, 현재 시각 인디케이터는 아직 없음 |
| Tr-Reserve-Conflict.html | `_SessionSheet` | ✅ | 일치 |
| Tr-Reserve-Date.html | `_SessionSheet` | ✅ | 일치 |
| Tr-Reserve-Edit.html | `_SessionSheet` | 🟡 | 별도 화면 네비게이션 vs 인라인 시트 |
| Tr-Reserve-Member.html | `_MemberPickerList` | ✅ | 일치 |
| Tr-Reserve-NoMember.html | `_SessionSheet` | 🟡 | 필드 강조(흔들림) 없음 |
| Tr-Reserve-Time.html | `_SessionSheet` | ✅ | 일치 |
| Tr-Reserve.html | `_SessionSheet` | ✅ | 일치 |
| Tr-Session-Actions.html | `_showSessionActions` | ✅ | 일치 |
| Tr-Session-CancelConfirm.html | `_cancelSession` | ✅ | 일치 |
| Tr-My.html | `_TrainerProfileTab` | ✅ | 일치 |
| Tr-DeleteAccount.html | `delete_account_sheet.dart` | ✅ | 일치 |
| TrainerHome.html(구) | — | ❌ | 구버전, 신버전(Tr-Home)으로 대체됨 |
| TrainerSchedule.html(구) | — | ❌ | 구버전, 신버전(Tr-Schedule)으로 대체됨 |
| TrainerReserve.html(구) | — | ❌ | 구버전, 신버전(Tr-Reserve)으로 대체됨 |

## 4. 트레이너 B — 회원상세/PT기록/피드백/인바디 — 25✅ / 1🟡 / 1❌

| 시안 파일 | 구현 | 상태 | 메모 |
|---|---|---|---|
| Tr-Member-Blocked.html | `trainer_member_tabs.dart` | ✅ | 일치 |
| Tr-Member-Cardio.html | `trainer_member_tabs.dart` | ✅ | 일치 |
| Tr-Member-Empty.html | `trainer_member_tabs.dart` | ✅ | 일치 |
| Tr-Member-Meals.html | `trainer_member_tabs.dart` | ✅ | 일치 |
| Tr-Member-More.html | `trainer_member_detail_screen.dart` | ✅ | 일치 |
| Tr-Member-Profile-Blocked.html | `trainer_member_detail_screen.dart` | ✅ | 일치 |
| Tr-Member-Profile-Empty.html | `trainer_member_detail_screen.dart` | ✅ | 일치 |
| Tr-Member-Profile.html | `trainer_member_detail_screen.dart` | 🟡 | AppStatGrid 2열 vs 시안 3열 |
| Tr-Member-Workouts.html | `trainer_member_tabs.dart` | ✅ | 일치 |
| Tr-PtRecord.html | `trainer_pt_workout_screen.dart` | ✅ | 일치 |
| Tr-PtRecord-Cardio.html | 동일 | ✅ | 일치 |
| Tr-PtRecord-DeleteConfirm.html | `showAppConfirmDialog`(`warning` 파라미터) | ✅ | 주황 경고 콜아웃(`AppWarningCallout`) 조건부 표시 완료(2026-10-08) |
| Tr-PtRecord-Editing.html | `trainer_pt_workout_screen.dart` | ✅ | 일치 |
| Tr-PtRecord-Empty.html | 동일 | ✅ | 일치 |
| Tr-PtRecord-Saved.html | 동일 | ✅ | 일치 |
| TrainerPtDone.html | `trainer_pt_done_screen.dart`(`TrainerPtDoneScreen`) | ✅ | 신규 구현 완료(2026-10-08). 장식용 떠다니는 SVG 일러스트·체크마크 draw 애니메이션은 "장식 애니메이션 금지" 원칙에 따라 생략, 잔여 횟수 롤 애니메이션은 구현 |
| Tr-Feedback.html | `feedback_sheet.dart` | ✅ | 일치 |
| Tr-Feedback-Edit.html | 동일 | ✅ | 일치 |
| Tr-Feedback-General.html | 동일 | ✅ | 일치 |
| Tr-Inbody-Input.html | `trainer_inbody_sheet.dart` | ✅ | 일치 |
| Tr-Inbody-Detail.html | `trainer_member_detail_screen.dart` | ✅ | 일치 |
| Tr-Inbody-DeleteConfirm.html | `showAppConfirmDialog` | ✅ | 경고 콜아웃 없는 단순 버전 — 다이얼로그 재설계로 완전히 일치(2026-10-08) |
| Tr-Inbody-Error.html | `trainer_inbody_sheet.dart` | ✅ | 일치 |
| Tr-ExerciseMenu.html | `trainer_workout_sheets.dart` | ✅ | 일치 |
| Tr-ExercisePicker.html | 동일 | ✅ | 일치 |
| Tr-ExercisePicker-Custom.html | 동일 | ✅ | 일치 |
| TrainerMember.html(구) | `trainer_member_detail_screen.dart` | ❌ | 구 IA(단일 피드)는 탭 분리 구조로 완전히 교체됨 |

## 5. 회원 A — 홈/운동/PT/통계 — 19✅ / 3🟡 / 3참고

| 시안 파일 | 구현 | 상태 | 메모 |
|---|---|---|---|
| MemA-Home.html | `member_calendar_screen.dart` | ✅ | 캘린더 점 색만 차이(공통 이슈 1) |
| MemA-Home-EmptyDay.html | 동일 | ✅ | 일치 |
| MemA-Home-PtDay.html | 동일 | ✅ | 일치 |
| MemA-PtSchedule.html | `member_pt_schedule_screen.dart` | ✅ | AppHighlightCard 등 일치 |
| MemA-PtSchedule-Empty.html | 동일 | ✅ | 일치 |
| MemA-PtWorkout.html | `member_pt_workout_screen.dart` | 🟡 | 월 헤더 포맷만 차이 |
| MemA-PtWorkout-Empty.html | 동일 | ✅ | 일치 |
| MemA-Sheet-DatePicker.html | `showAppDatePicker` | ✅ | 일치 |
| MemA-Sheet-ExerciseMenu.html | `workout_sheets.dart` | 🟡 | 삭제 글자색 빨강(시안은 주황) |
| MemA-Sheet-ExercisePicker.html | 동일 | ✅ | 일치 |
| MemA-Sheet-ExerciseSearch.html | 동일 | ✅ | 일치 |
| MemA-Sheet-RestTimer.html | 동일 | ✅ | 일치 |
| MemA-Stats.html | `member_workout_stats_screen.dart` | ✅ | 일치 |
| MemA-Stats-Empty.html | 동일 | ✅ | 일치 |
| MemA-Stats-Monthly.html | 동일 | ✅ | 일치 |
| MemA-Workout-Cardio.html | `member_workout_screen.dart` | ✅ | 일치 |
| MemA-Workout-Editing.html | 동일 | ✅ | 일치 |
| MemA-Workout-Empty.html | 동일 | ✅ | 일치 |
| MemA-Workout-Recording.html | 동일 | ✅ | 일치 |
| MemA-Workout-Saved.html | `workout_saved_card.dart` | ✅ | 일치 |
| MemA-Dialog-DeleteWorkout.html | `showAppConfirmDialog` | ✅ | 일치 |
| Done.html | `member_workout_screen.dart`(저장 스낵바) | 🟡 | 전용 완료 화면/애니메이션 없음 |
| Main.html(구) | `member_calendar_screen.dart` | 참고 | 구버전, IA 자체가 다름(판정 보류) |
| Workout.html(구) | `member_workout_screen.dart` | 참고 | 구버전, 신버전 기준으로 참고만 |

## 6. 회원 B — 프로필/식단/공유 — 18✅ / 0🟡 / 1참고

| 시안 파일 | 구현 | 상태 | 메모 |
|---|---|---|---|
| MemB-DeleteSheet.html | `delete_account_sheet.dart` | ✅ | 탈퇴 버튼 검정 채움으로 변경 완료(2026-10-08) |
| MemB-EditBasicSheet.html | `edit_basic_info_sheet.dart` | ✅ | 토스트 톤 적용 완료(2026-10-08). 성별 선택 색도 이미 해결 |
| MemB-EditBodySheet.html | `edit_profile_sheet.dart` | ✅ | 일치 |
| MemB-Feedback.html | `member_feedback_screen.dart` | ✅ | 안읽음 점 주황 적용 완료(2026-10-08) |
| MemB-FeedbackEmpty.html | 동일 | ✅ | 일치 |
| MemB-FoodDetailSheet.html | `food_detail_sheet.dart` | ✅ | 단백질 막대 주황 강조 적용 완료(2026-10-08) |
| MemB-FoodList.html | `food_list_screen.dart` | ✅ | 일치 |
| MemB-MealDeleteDialog.html | `showAppConfirmDialog` | ✅ | 2열 전체폭 버튼으로 재설계 완료(2026-10-08) |
| MemB-MealInput.html | `meal_input_sheet.dart` | ✅ | 일치 |
| MemB-MealInputEmpty.html | 동일 | ✅ | 토스트 톤 적용 완료(2026-10-08) |
| MemB-MealLog.html | `member_meal_log_screen.dart` | ✅ | 일치 |
| MemB-MealLogEmpty.html | 동일 | ✅ | 일치 |
| MemB-My.html | `member_profile_screen.dart` | ✅ | 공지 새 글 강조색 적용 완료(2026-10-08) |
| MemB-NutritionGuide.html | `nutrition_guide_screen.dart` | ✅ | 일치 |
| MemB-Profile.html | `member_profile_detail_screen.dart` | ✅ | 추이 그래프 최신값 주황 강조 적용 완료(2026-10-08) |
| MemB-ProfileEmpty.html | 동일 | ✅ | 일치 |
| MemB-Share.html | `member_share_settings_screen.dart` | ✅ | 토글 on 색 주황 적용 완료(2026-10-08, 전역 `app_theme.dart` 수정) |
| MemB-ThemeSheet.html | `theme_setting_row.dart` | ✅ | 일치 |
| My.html(구) | `member_profile_screen.dart` | 참고 | 구버전(PT카드 있음), 신버전(MemB-My)이 기준 |

## 7. 공통 — 로그인/온보딩/가입/알림/토스트 — 14✅ / 5🟡

| 시안 파일 | 구현 | 상태 | 메모 |
|---|---|---|---|
| Com-Login.html | `login_screen.dart` | ✅ | 일치 |
| Com-Login-Error.html | `AppToast` | ✅ | 토스트 검정+주황 배지 스타일 적용 완료(2026-10-08) |
| Com-Login-ResetSent.html | 동일 | ✅ | 동일 |
| Com-Login-Deleted.html | 동일 | ✅ | 동일 |
| Com-PasswordReset.html | `password_reset_sheet.dart` | 🟡 | 일러스트 박스 없음 |
| Com-Splash.html | `splash_screen.dart` | 🟡 | OrbLoader로 브랜드 모티프 대체(의도적 변경 추정) |
| Com-Pending.html | `pending_approval_screen.dart` | 🟡 | 동일 |
| Com-Register-Member.html | `member_register_screen.dart` | ✅ | 일치 |
| Com-Register-Trainer.html | `trainer_register_screen.dart` | 🟡 | 오류 상태 강조색 차이 |
| Com-Register-Admin.html | `admin_register_screen.dart` | ✅ | 일치 |
| Com-CenterPicker.html | `login_screen.dart` 내부 | ✅ | 일치 |
| Com-Onboarding-Basic.html | `onboarding_screens.dart` | ✅ | 성별 선택 색을 검정으로 통일 완료(2026-10-08, `gender_selector.dart`) |
| Com-Onboarding-Body.html | 동일 | ✅ | 일치 |
| Com-DeleteAccount-Member.html | `delete_account_sheet.dart` | ✅ | 탈퇴 버튼 검정 채움 + "복구 불가" 주황 경고 콜아웃(`AppWarningCallout`) 적용 완료(2026-10-08) |
| Com-DeleteAccount-Trainer.html | 동일 | ✅ | 동일 |
| Com-Notifications.html | `notifications_screen.dart` | ✅ | 새 알림 점 주황 적용 완료(2026-10-08). 스와이프 삭제 배경은 빨강 유지(파괴적 행동 글자 원칙에 부합, 실제 차이 아님) |
| Com-Notifications-Empty.html | 동일 | 🟡 | 아이콘 고정(사소) |
| Com-ConfirmDialog.html | `showAppConfirmDialog` | ✅ | 2열 전체폭 버튼(취소=회색, 확정=검정)으로 재설계 완료(2026-10-08) |
| Com-Toast-Push.html | `AppToast`+`notification_bell_button.dart` | ✅ | 토스트 검정+주황 포인트 스타일 적용 완료(2026-10-08), 종 점은 기존부터 일치 |

## 부록: 컴포넌트/토큰 스펙 (C0~C4) 대조

색상·간격·모서리(radius) 토큰은 `lib/core/app_colors.dart`/`app_spacing.dart`와 시안이 거의 완벽히 일치합니다. 다만:
- 텍스트 스타일 일부 세부 단계가 시안 스펙보다 적게 구현됨
- 공용 `AppMotion`(전환 시간/커브) 토큰이 없음
- 차트류 3종(막대/가로바 리스트/스파크라인)이 별도 공용 위젯 없이 화면마다 인라인 구현된 것으로 추정됨 (재사용성 개선 여지)

---

*이 문서는 2026-10-08 기준 1회 스냅샷입니다. 화면을 고치면 해당 행만 수동으로 ✅로 갱신하세요. `DESIGN-SYSTEM-PROGRESS.md`/`DESIGN-SYSTEM-AUDIT.md`(Toss 시대 기록)는 더 이상 유효하지 않으니 참고하지 마세요.*
