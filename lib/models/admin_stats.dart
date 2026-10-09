import 'pt_info.dart';

class TrainerSessionStat {
  final String trainerId;
  final String trainerName;
  final int completedCount;

  const TrainerSessionStat({
    required this.trainerId,
    required this.trainerName,
    required this.completedCount,
  });
}

/// 관리자 홈·대시보드 숫자. 완료율 = 완료 / (완료 + 남은 예약), 취소는 빼고 센다.
class AdminStats {
  /// 통계를 낸 달 (그 달 1일)
  final DateTime month;
  final int memberCount;
  final int trainerCount;
  final int monthlyCompletedSessions;
  final int upcomingSessionCount;
  final int todayScheduledSessions;
  final int todayCompletedSessions;
  final double monthlyCompletionRate;

  /// 그 달 예약 중 아직 완료하지 않은 수 (완료율의 '남음')
  final int monthlyScheduledSessions;

  /// 그 달 취소된 수 (완료율에는 넣지 않는다)
  final int monthlyCancelledSessions;

  /// 그 달 주별 완료 수 (월요일 시작 주, 1주부터)
  final List<int> weeklyCompleted;
  final List<TrainerSessionStat> trainerStats;
  final List<PtInfo> lowPtMembers;
  final List<PtInfo> expiringPtMembers;

  const AdminStats({
    required this.month,
    required this.memberCount,
    required this.trainerCount,
    required this.monthlyCompletedSessions,
    required this.upcomingSessionCount,
    required this.todayScheduledSessions,
    required this.todayCompletedSessions,
    required this.monthlyCompletionRate,
    required this.monthlyScheduledSessions,
    required this.monthlyCancelledSessions,
    required this.weeklyCompleted,
    required this.trainerStats,
    required this.lowPtMembers,
    required this.expiringPtMembers,
  });
}
