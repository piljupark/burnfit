/// 푸시 알림을 눌렀을 때 이동할 화면.
///
/// `data.type` 값은 functions/index.js의 sendNotification 호출과 맞춘다.
enum NotificationTarget {
  /// 트레이너 피드백 목록 (회원)
  feedback,

  /// PT 일정 (회원: PT 탭, 트레이너: 일정 탭)
  ptSchedule;

  static NotificationTarget? fromData(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'feedback_created':
        return NotificationTarget.feedback;
      case 'pt_session_created':
      case 'pt_session_updated':
      case 'pt_session_cancelled':
      case 'pt_remaining_warning':
        return NotificationTarget.ptSchedule;
      default:
        return null;
    }
  }
}
