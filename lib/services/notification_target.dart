/// 푸시 알림을 눌렀을 때 이동할 화면.
///
/// `data.type` 값은 functions/index.js의 sendNotification 호출과 맞춘다.
enum NotificationTarget {
  /// 트레이너 피드백 목록 (회원)
  feedback,

  /// PT 일정 (회원: PT 탭, 트레이너: 일정 탭)
  ptSchedule,

  /// 홈 첫 탭 (가입 승인, 새 담당 회원 배정)
  home,

  /// 센터 공지사항 목록
  notices;

  static NotificationTarget? fromData(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'feedback_created':
        return NotificationTarget.feedback;
      case 'pt_session_created':
      case 'pt_session_updated':
      case 'pt_session_cancelled':
      case 'pt_remaining_warning':
      case 'trainer_assigned':
        return NotificationTarget.ptSchedule;
      case 'notice_created':
        return NotificationTarget.notices;
      case 'account_approved':
      case 'member_assigned':
        return NotificationTarget.home;
      default:
        return null;
    }
  }
}
