# 출시 전 점검 (구글 플레이 · 앱 스토어)

2026-10-11 점검. 데이터 저장 방식, 권한, 기능, 스토어 심사 기준으로 코드 전체를 훑어보고, 고쳐야 할 것을 급한 순서로 묶었다. 아직 고친 것은 없다.

- **꼭** — 이대로는 올릴 수 없거나, 나중에 바꿀 수 없는 것
- **고치면 좋음** — 올릴 수는 있지만 회원이 늘면 비용·보안·품질 문제가 되는 것
- **여유 있을 때** — 다듬기

## 먼저 정할 것 (사람이 결정)

1. **앱 식별자** — 지금 `com.example.burnfit`. 스토어에 한 번 올리면 바꿀 수 없다. 예: `kr.○○.refit`. 정하면 안드로이드 `applicationId`, iOS 번들 ID, Firebase 앱 등록(안드로이드·iOS 새로 추가 → `google-services.json`·`GoogleService-Info.plist` 다시 받기)을 함께 바꾼다.
2. **개발자 계정** — 구글 플레이 개발자 계정(1회 등록비), 애플 개발자 프로그램(유료, 연 단위). 지금 iOS는 무료 개인 팀이라 푸시 알림·배포가 안 된다.
3. **개인정보 처리방침 · 계정 삭제 안내 웹 주소** — 두 스토어 모두 필수. 센터(운영 주체) 이름으로 쓴다.

## 꼭

### 앱 식별 · 서명

- `android/app/build.gradle.kts:29` `applicationId = "com.example.burnfit"` → 정한 식별자로.
- `android/app/build.gradle.kts:42` 릴리스가 **디버그 키로 서명**됨 → 업로드 키(keystore) 만들고 `key.properties`로 연결, 키 파일은 저장소에 넣지 않는다. 플레이 앱 서명 사용.
- `.github/workflows/build-apk.yml` 이 디버그 키로 서명한 APK를 내보낸다 → 스토어용은 AAB(`flutter build appbundle`), 서명 키는 저장소 비밀값으로.
- `pubspec.yaml:4` `version: 1.0.0+1` — 올릴 때마다 뒤 숫자를 올린다.

### 스토어 제출 서류

- 개인정보 처리방침 주소 (앱 안 마이 탭에도 링크).
- **계정 삭제**: 앱 안 탈퇴는 회원·트레이너만 있음 → 관리자 탈퇴 방법을 정한다(센터 정리 포함). 구글은 앱 밖 웹에서 삭제 요청하는 주소도 요구.
- 심사용 **승인된 데모 계정** (회원·트레이너 각각, 가입 → 승인 대기 때문에 심사관이 새로 가입하면 막힌다). 심사 메모에 적는다.
- 구글 '데이터 보안' 양식 · 애플 '앱 개인정보' 라벨: 수집하는 것 = 이메일, 이름, 생년월일, 성별, 키·몸무게·인바디(건강 정보), 식단 사진, 운동 기록, 푸시 토큰. 광고·추적 없음.
- 건강 정보를 다루므로 애플 심사 지침 5.1.1·5.1.3(건강 자료) 문구 확인.

### iOS

- `ios/Runner/Info.plist` 에 **사진·카메라 사용 이유 문구가 없다** → `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription` (식단 사진). 없으면 사진 고를 때 앱이 꺼지고 심사에서 거절.
- `PrivacyInfo.xcprivacy`(개인정보 매니페스트) 없음 → 추가 (UserDefaults·파일 시각 등 사용 이유).
- 푸시: 엔타이틀먼트 파일 없음 → Push Notifications 기능 + `UIBackgroundModes` `remote-notification` + Firebase 콘솔에 APNs 키 등록. (유료 계정 필요)
- `ITSAppUsesNonExemptEncryption = false` 추가 (수출 규정 질문 생략).
- iPad 가로 화면이 켜져 있다(`Info.plist:62`) → iPhone 전용으로 할지, iPad 화면도 확인할지 정한다.

### Firebase · 보안

- **Firebase 프로젝트가 하나**(`burnfit-v01`)라 개발과 실제가 섞인다 → 개발용·실제용 둘로 나누고 `flutterfire configure`로 환경별 설정.
- **App Check 없음** → 켜기 (Play Integrity · App Attest). 우리 앱이 아닌 곳에서 Firestore·Storage·함수를 부르는 것을 막는다.
- **이메일 인증 없음** → 가입 뒤 인증 메일, 승인 전 확인.

## 고치면 좋음

### 비용 · 속도

- 트레이너 식단 피드가 회원마다 따로 읽는다 (`lib/services/meal_feed_service.dart:50` 회원당 피드백 300개) → 회원 수만큼 읽기가 늘어난다. 식단 탭을 오갈 때마다 다시 읽는다. → 날짜 범위로 묶어 읽기 · 탭 전환 때 다시 읽지 않기 · 피드백 수를 식단 문서에 모아 두기.
- 지난 운동 불러오기(`getPreviousWorkouts`)와 관리자 목록(회원·트레이너·탈퇴)에 개수 제한이 없다 → 페이지로 나눠 읽기.
- 관리자 대시보드가 매번 기록을 다 세서 계산 → 서버에서 미리 모아 두기.

### 데이터 · 규칙

- 시각을 기기 시계로 저장하는 곳이 있다 → `FieldValue.serverTimestamp()`.
- `memberName`·`trainerName`·`imageUrls` 같은 값을 규칙에서 검사하지 않는다, 글자 길이·저장 빈도 제한 없음 → `firestore.rules` 에 길이·형식 검사.
- 트레이너가 다른 트레이너의 이메일·생년월일을 읽을 수 있다 → 공개용 필드만 따로 두거나 규칙 좁히기.
- 식단 사진 주소가 다운로드 토큰 주소라 주소만 알면 누구나 본다 → 규칙으로 읽는 경로를 쓰거나, 최소한 주소를 밖으로 내보내지 않기.
- 식단·계정을 지워도 Storage 사진이 남는 경우 → 삭제 함수에서 함께 지우기.
- 로그아웃해도 기기 캐시와 운동 임시저장이 남는다 (`lib/main.dart:67` 캐시 무제한, `clearPersistence` 없음) → 로그아웃 때 정리 (한 기기를 여럿이 쓰는 센터 기기 대비).

### 서버 · 알림

- 함수 지역이 기본(`us-central1`) → `asia-northeast3`(서울)로 (반응 속도).
- 안드로이드 알림 채널 `burnfit_default`(`functions/index.js:102`)를 앱에서 만들지 않는다 → 앱 시작 때 채널 만들기, 이름도 REFIT으로.
- 휴식 타이머 알림(2026-10-11 추가): 안드로이드 권한 `SCHEDULE_EXACT_ALARM` · `VIBRATE`, 알림 채널 `rest_timer_ongoing` · `rest_timer_warning` · `rest_timer_done`.
  - `SCHEDULE_EXACT_ALARM`은 플레이 신고서가 필요 없다 (`USE_EXACT_ALARM`만 알람·캘린더 앱 전용). 안드로이드 14+는 기본 꺼짐이라 앱이 한 번 허용을 권한다.
  - 아이폰 잠금 화면 · 다이내믹 아일랜드(실시간 현황): 위젯 확장 대상 `RestTimerWidget`(`ios/RestTimerWidget/`, 번들 `com.example.burnfit.RestTimerWidget`, iOS 16.2+)과 `Info.plist`의 `NSSupportsLiveActivities`. 앱 그룹은 쓰지 않는다. 번들 ID를 바꿀 때 확장 ID도 함께 `<앱 ID>.RestTimerWidget`으로 바꾼다. 스토어 심사 때 확장도 같은 팀으로 서명돼야 한다.
- `onMealCreated` 함수 배포 아직 (`firebase deploy --only functions:onMealCreated --project burnfit-v01`).

### 기타

- 종목 설명(`lib/core/exercise_guide_data.dart`) 운동 방법 248개는 트레이너 검수 전이다 → 검수 뒤 시트의 '검수 전' 꼬리표를 뗀다 (`exercise_guide_sheet.dart`). 자료 출처 free-exercise-db는 Unlicense(표시 의무 없음), 근육 그림 `muscle_map`은 MIT(앱 안 라이선스 화면이 생기면 자동으로 실린다).
- 안드로이드 `targetSdk`는 Flutter 기본값 — 플레이 요구 수준(해마다 오름) 확인.

## 여유 있을 때

- 비밀번호 규칙이 8자 이상뿐 → 숫자·문자 섞기 정도.
- `graphify-out/` 이 저장소에 올라가 있다 → `.gitignore`.
- 가입 때 센터 목록 검색 (센터가 많아지면).
- 쓰지 않는 Firestore 색인 정리 (`firestore.indexes.json`).
- 쓰지 않는 공용 부품 정리 → [컴포넌트 목록](components.md#정리할-것).

## 잘 되어 있는 것

- 규칙에서 권한을 스스로 올릴 수 없다 (역할·승인 상태·센터를 본인이 못 바꿈).
- 관리자 계정은 서버 함수 + 설정 코드(비밀값)로만 만든다.
- 계정 삭제 함수가 기록·사진·인증까지 정리한다 (관리자 탈퇴만 없음).
- 저장소에 비밀값이 없다.

## 권하는 순서

1. 앱 식별자 · 개발자 계정 · 처리방침 주소 정하기 (사람)
2. 식별자 바꾸기 + Firebase 앱 다시 등록 + 개발/실제 프로젝트 나누기 + 서명 키
3. iOS 권한 문구 · 개인정보 매니페스트 · 푸시 설정, App Check, 이메일 인증
4. 스토어 서류 (데이터 보안 · 앱 개인정보 · 데모 계정 · 관리자 탈퇴)
5. '고치면 좋음' — 비용 큰 것(식단 피드 읽기, 목록 개수 제한)부터
