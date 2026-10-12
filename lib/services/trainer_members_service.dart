import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_logger.dart';
import '../models/pt_info.dart';
import '../models/user.dart';
import '../models/workout.dart';
import 'firestore_service.dart';
import 'meal_feed_service.dart';
import 'nutrition_plan_service.dart';
import 'workout_service.dart';

/// 트레이너 '회원' 탭의 회원 한 명 요약 (회원 줄 · 알약 · 정렬에 쓴다).
class TrainerMemberSummary {
  final AppUser member;
  final PtInfo? ptInfo;

  /// 최근 [TrainerMembersService.workoutDays]일 안의 마지막 운동 날짜 ('2026-10-09'). 없으면 null.
  final String? lastWorkoutDate;

  /// 최근 7일 식단 중 이 트레이너가 아직 피드백하지 않은 수
  final int pendingMeals;

  /// 식단 목표가 있는지 (읽지 못했으면 true로 두어 '목표 없음'을 잘못 띄우지 않는다)
  final bool hasPlan;

  /// 가입한 지 7일이 안 된 회원
  final bool isNew;

  /// 오늘 (테스트에서 고정)
  final DateTime today;

  const TrainerMemberSummary({
    required this.member,
    required this.ptInfo,
    required this.lastWorkoutDate,
    required this.pendingMeals,
    required this.hasPlan,
    required this.isNew,
    required this.today,
  });

  /// PT 종료일까지 남은 날 (종료일이 없으면 null)
  int? get ptDaysLeft {
    final end = ptInfo?.endDate;
    if (end == null) return null;
    return DateUtils.dateOnly(end).difference(DateUtils.dateOnly(today)).inDays;
  }

  /// 진행 중인 PT가 있다 (남은 횟수 > 0, 기간 안)
  bool get hasActivePt {
    final info = ptInfo;
    if (info == null || info.remainingSessions <= 0) return false;
    final left = ptDaysLeft;
    return left == null || left >= 0;
  }

  /// 진행 중이면서 3회 이하 남았거나 14일 안에 끝난다 (관리자 회원 목록과 같은 기준)
  bool get ptEndingSoon {
    if (!hasActivePt) return false;
    final left = ptDaysLeft;
    return ptInfo!.remainingSessions <= 3 || (left != null && left <= 14);
  }

  /// '확인 필요': 피드백할 식단이 있거나 새 회원
  bool get needsAttention => pendingMeals > 0 || isNew;

  /// 마지막 운동이 며칠 전인지 (없으면 null)
  int? get daysSinceWorkout {
    final d = lastWorkoutDate == null
        ? null
        : DateTime.tryParse(lastWorkoutDate!);
    if (d == null) return null;
    return DateUtils.dateOnly(today).difference(DateUtils.dateOnly(d)).inDays;
  }

  /// 2주 넘게 운동 기록이 없다 (그만둘 위험 — 주황 글자). 새 회원은 아직 기록이 없어도 주의가 아니다.
  bool get idle {
    if (isNew) return false;
    final days = daysSinceWorkout;
    return days == null || days > 14;
  }

  String get workoutLabel {
    final days = daysSinceWorkout;
    if (days == null) {
      return '${TrainerMembersService.workoutDays}일간 운동 없음';
    }
    if (days <= 0) return '오늘 운동';
    if (days == 1) return '어제 운동';
    return '$days일 전 운동';
  }
}

/// 회원 탭 알약
enum TrainerMemberFilter {
  all('전체'),
  attention('확인 필요'),
  ptEndingSoon('PT 곧 끝남'),
  noPlan('목표 없음');

  final String label;

  const TrainerMemberFilter(this.label);

  bool matches(TrainerMemberSummary s) => switch (this) {
    TrainerMemberFilter.all => true,
    TrainerMemberFilter.attention => s.needsAttention,
    TrainerMemberFilter.ptEndingSoon => s.ptEndingSoon,
    TrainerMemberFilter.noPlan => !s.hasPlan,
  };
}

/// 트레이너 '회원' 탭 자료: 담당 회원 + 회원마다 PT 이용권 · 최근 운동 · 식단 목표, 최근 7일 식단 피드.
/// 한 회원의 보조 자료를 읽지 못해도 그 칸만 비우고 목록은 보여 준다 (담당 회원 목록 실패만 예외).
class TrainerMembersService {
  TrainerMembersService._();

  /// '마지막 운동'을 찾는 기간
  static const workoutDays = 30;

  /// 피드백할 식단을 세는 기간 (식단 탭과 같다)
  static const mealDays = 7;

  static final _dateKey = DateFormat('yyyy-MM-dd');

  static Future<List<TrainerMemberSummary>> load(AppUser trainer) async {
    final members = await FirestoreService.getMembersByTrainer(
      trainer.centerId,
      trainer.uid,
    );
    if (members.isEmpty) return const [];

    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final workoutStart = _dateKey.format(
      today.subtract(const Duration(days: workoutDays)),
    );
    final todayKey = _dateKey.format(today);

    Future<T?> quiet<T extends Object>(String what, Future<T?> future) async {
      try {
        return await future;
      } catch (e) {
        AppLogger.debug('[TrainerMembers] $what 읽기 실패: $e');
        return null;
      }
    }

    final mealsFuture = quiet(
      '식단 피드',
      MealFeedService.load(
        members: members,
        from: today.subtract(const Duration(days: mealDays - 1)),
        to: today,
      ),
    );
    final perMember = await Future.wait(
      members.map((m) async {
        final results = await Future.wait<Object?>([
          quiet(
            '${m.uid} PT',
            FirestoreService.getPtInfo(m.uid, centerId: m.centerId),
          ),
          quiet(
            '${m.uid} 운동',
            WorkoutService.getWorkoutsByDateRange(
              m.centerId,
              m.uid,
              workoutStart,
              todayKey,
            ),
          ),
          // 있음/없음으로 바꿔 읽기 실패(null)와 구분한다.
          quiet(
            '${m.uid} 식단 목표',
            NutritionPlanService.get(m.uid).then((plan) => plan != null),
          ),
        ]);
        return results;
      }),
    );
    final meals = await mealsFuture;
    final pending = <String, int>{};
    for (final item in meals ?? const <MealFeedItem>[]) {
      if (!item.hasFeedbackFrom(trainer.uid)) {
        pending[item.member.uid] = (pending[item.member.uid] ?? 0) + 1;
      }
    }

    return [
      for (var i = 0; i < members.length; i++)
        build(
          member: members[i],
          ptInfo: perMember[i][0] as PtInfo?,
          workouts: perMember[i][1] as List<Workout>?,
          // 목표를 읽지 못했으면 있다고 본다 ('목표 없음'을 잘못 띄우지 않게)
          hasPlan: perMember[i][2] as bool? ?? true,
          pendingMeals: pending[members[i].uid] ?? 0,
          today: today,
        ),
    ];
  }

  /// 읽어 온 자료로 요약을 만든다 (테스트용으로 따로 둔다).
  static TrainerMemberSummary build({
    required AppUser member,
    required PtInfo? ptInfo,
    required List<Workout>? workouts,
    required bool hasPlan,
    required int pendingMeals,
    required DateTime today,
  }) {
    String? last;
    for (final w in workouts ?? const <Workout>[]) {
      if (last == null || w.workoutDate.compareTo(last) > 0) {
        last = w.workoutDate;
      }
    }
    final joinedDays = DateUtils.dateOnly(
      today,
    ).difference(DateUtils.dateOnly(member.createdAt)).inDays;
    return TrainerMemberSummary(
      member: member,
      ptInfo: ptInfo,
      lastWorkoutDate: last,
      pendingMeals: pendingMeals,
      hasPlan: hasPlan,
      isNew: joinedDays < 7,
      today: today,
    );
  }

  /// 확인 필요한 회원이 위, 나머지는 이름순.
  static List<TrainerMemberSummary> sorted(List<TrainerMemberSummary> list) =>
      [...list]..sort((a, b) {
        if (a.needsAttention != b.needsAttention) {
          return a.needsAttention ? -1 : 1;
        }
        return a.member.name.compareTo(b.member.name);
      });
}
