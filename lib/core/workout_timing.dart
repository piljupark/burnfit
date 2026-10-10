/// 개인 운동 시간 규칙 (회원이 직접 하는 개인 운동만. PT 기록은 시간을 재지 않는다).
///
/// - 시작: '운동 시작'을 누르거나 첫 세트를 완료한 때
/// - 끝: '운동 마치기'로 저장한 때 (앱을 닫아 자동 저장되면 마지막 세트를 완료한 때)
/// - 마지막 세트 뒤 [workoutReminderDelay] 동안 입력이 없으면 리마인드 알림
/// - 앱을 다시 열었을 때 마지막 세트가 [workoutAutoSaveAfter]보다 오래됐으면 자동 저장
library;

const Duration workoutReminderDelay = Duration(minutes: 10);
const Duration workoutAutoSaveAfter = Duration(minutes: 60);

/// 운동 시간으로 받아들이는 최대치 (시간 고치기 시트의 위 끝).
const int workoutDurationMaxMinutes = 600;

/// 임시저장에 넣는 시각 키.
const String draftStartedAtKey = 'startedAt';
const String draftLastSetAtKey = 'lastSetAt';

/// 두 시각 사이 초 (거꾸로면 0, 최대치를 넘으면 최대치).
int workoutDurationSeconds(DateTime start, DateTime end) {
  final seconds = end.difference(start).inSeconds;
  if (seconds <= 0) return 0;
  const max = workoutDurationMaxMinutes * 60;
  return seconds > max ? max : seconds;
}

/// '48분' · '1시간 12분' · '1분 미만'. 0이면 null (시간을 재지 않은 기록 — 보여 주지 않는다).
String? formatWorkoutDuration(int seconds) {
  if (seconds <= 0) return null;
  final minutes = seconds ~/ 60;
  if (minutes == 0) return '1분 미만';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$minutes분';
  return rest == 0 ? '$hours시간' : '$hours시간 $rest분';
}

/// 임시저장 값의 시각 (없거나 잘못됐으면 null).
DateTime? draftTime(Map<String, dynamic> draft, String key) {
  final value = draft[key];
  if (value is! String) return null;
  return DateTime.tryParse(value);
}

/// 앱을 다시 열었을 때 이 임시저장을 끝난 운동으로 보고 자동 저장할지.
/// 이미 저장한 기록을 고치던 중이면 덮어쓰지 않도록 저장하지 않는다.
bool shouldAutoSaveDraft(Map<String, dynamic> draft, DateTime now) {
  if (draft['editingWorkoutId'] != null) return false;
  final lastSetAt = draftTime(draft, draftLastSetAtKey);
  if (lastSetAt == null) return false;
  return now.difference(lastSetAt) >= workoutAutoSaveAfter;
}
