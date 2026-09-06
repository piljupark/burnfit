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

class AdminStats {
  final int memberCount;
  final int trainerCount;
  final int monthlyCompletedSessions;
  final int upcomingSessionCount;
  final int todayScheduledSessions;
  final int todayCompletedSessions;
  final double monthlyCompletionRate;
  final List<TrainerSessionStat> trainerStats;
  final List<PtInfo> lowPtMembers;
  final List<PtInfo> expiringPtMembers;

  const AdminStats({
    required this.memberCount,
    required this.trainerCount,
    required this.monthlyCompletedSessions,
    required this.upcomingSessionCount,
    required this.todayScheduledSessions,
    required this.todayCompletedSessions,
    required this.monthlyCompletionRate,
    required this.trainerStats,
    required this.lowPtMembers,
    required this.expiringPtMembers,
  });
}
