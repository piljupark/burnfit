import 'workout.dart';

class DailyVolume {
  final String date;
  final double volume;
  final int sessionCount;

  const DailyVolume({
    required this.date,
    required this.volume,
    required this.sessionCount,
  });
}

class WorkoutStats {
  final List<DailyVolume> dailyVolumes;
  final Map<WorkoutCategory, int> categorySetCounts;
  final int totalWorkoutDays;
  final int totalSessions;
  final int totalSets;
  final double totalVolume;
  final double avgVolumePerDay;
  final double avgVolumePerSession;
  final int activeStreakDays;
  final DailyVolume? bestVolumeDay;

  const WorkoutStats({
    required this.dailyVolumes,
    required this.categorySetCounts,
    required this.totalWorkoutDays,
    required this.totalSessions,
    required this.totalSets,
    required this.totalVolume,
    required this.avgVolumePerDay,
    required this.avgVolumePerSession,
    required this.activeStreakDays,
    required this.bestVolumeDay,
  });

  factory WorkoutStats.fromWorkouts(
    List<Workout> workouts, {
    required String startDate,
    required String endDate,
  }) {
    final Map<String, DailyVolume> dailyMap = {};
    final Map<WorkoutCategory, int> catMap = {};
    int totalSets = 0;
    double totalVolume = 0;

    for (final w in workouts) {
      final prev = dailyMap[w.workoutDate];
      dailyMap[w.workoutDate] = DailyVolume(
        date: w.workoutDate,
        volume: (prev?.volume ?? 0) + w.totalVolume,
        sessionCount: (prev?.sessionCount ?? 0) + 1,
      );
      totalVolume += w.totalVolume;
      totalSets += w.totalSets;

      final prevCount = catMap[w.category] ?? 0;
      catMap[w.category] = prevCount + w.totalSets;
    }

    final sortedDays = dailyMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final workoutDays = dailyMap.length;
    final avgVolume = workoutDays > 0 ? totalVolume / workoutDays : 0.0;
    final totalSessions = workouts.length;
    final avgVolumePerSession = totalSessions > 0
        ? totalVolume / totalSessions
        : 0.0;
    final bestVolumeDay = sortedDays.isEmpty
        ? null
        : sortedDays.reduce((a, b) => a.volume >= b.volume ? a : b);
    final activeStreakDays = _calculateActiveStreak(sortedDays);

    return WorkoutStats(
      dailyVolumes: sortedDays,
      categorySetCounts: catMap,
      totalWorkoutDays: workoutDays,
      totalSessions: totalSessions,
      totalSets: totalSets,
      totalVolume: totalVolume,
      avgVolumePerDay: avgVolume,
      avgVolumePerSession: avgVolumePerSession,
      activeStreakDays: activeStreakDays,
      bestVolumeDay: bestVolumeDay,
    );
  }

  bool get isEmpty => dailyVolumes.isEmpty;

  static int _calculateActiveStreak(List<DailyVolume> sortedDays) {
    if (sortedDays.isEmpty) return 0;

    final dates = sortedDays.map((d) => d.date).toSet();
    final latest = DateTime.tryParse(sortedDays.last.date);
    if (latest == null) return 0;
    var cursor = latest;

    var streak = 0;
    while (dates.contains(_dateKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
