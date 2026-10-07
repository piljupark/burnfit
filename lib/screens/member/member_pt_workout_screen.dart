import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/orb_loader.dart';

class MemberPtWorkoutScreen extends StatefulWidget {
  const MemberPtWorkoutScreen({super.key});

  @override
  State<MemberPtWorkoutScreen> createState() => _MemberPtWorkoutScreenState();
}

class _MemberPtWorkoutScreenState extends State<MemberPtWorkoutScreen> {
  bool _isLoading = false;
  List<Workout> _workouts = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final end = DateFormat('yyyy-MM-dd').format(now);
      final start = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(now.year, now.month - 2, now.day));
      final list = await WorkoutService.getWorkoutsByDateRange(
        user.centerId,
        user.uid,
        start,
        end,
        workoutType: WorkoutType.pt,
      );
      if (!mounted) return;
      setState(() {
        _workouts = list;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 월별 묶음 (입력 순서 유지).
  List<MapEntry<String, List<Workout>>> get _byMonth {
    final groups = <String, List<Workout>>{};
    for (final workout in _workouts) {
      final date = DateTime.tryParse(workout.workoutDate);
      final key = date == null ? workout.workoutDate : DateFormat('yyyy.MM').format(date);
      groups.putIfAbsent(key, () => []).add(workout);
    }
    return groups.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> content;
    if (_errorMessage != null) {
      content = [
        const SizedBox(height: 120),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: AppErrorCard(message: _errorMessage!, onRetry: _load),
        ),
      ];
    } else if (_workouts.isEmpty) {
      content = const [
        SizedBox(height: AppSpacing.xl3),
        AppEmptyState(
          icon: AppIcons.workout,
          message: 'PT 운동 기록이 없습니다',
          description: '최근 3개월 동안 트레이너와 함께한 운동이 여기에 표시됩니다.',
        ),
      ];
    } else {
      content = [
        for (final group in _byMonth) ...[
          AppMonthHeader(label: group.key, count: '${group.value.length}'),
          for (var i = 0; i < group.value.length; i++) ...[
            if (i > 0) const AppRowDivider(),
            _PtWorkoutRow(workout: group.value[i]),
          ],
        ],
        const SizedBox(height: AppSpacing.xl2),
      ];
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: AppScreenHeader(
                title: 'PT 운동 기록',
                subtitle: _isLoading || _workouts.isEmpty ? null : '최근 3개월 · ${_workouts.length}회',
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            const AppRowDivider(),
            Expanded(
              child: _isLoading
                  ? const AppLoadingView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.ink,
                      backgroundColor: AppColors.canvasCard,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: content,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PT 기록 한 줄: 왼쪽 모노 날짜(10.07 / WED) + 종목 이름 + 요약 + 메모.
class _PtWorkoutRow extends StatelessWidget {
  final Workout workout;

  const _PtWorkoutRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(workout.workoutDate);
    final volume = NumberFormat('#,###').format(workout.totalVolume.round());
    final names = workout.exercises.map((e) => e.name).join(', ');

    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text(
                    date == null ? workout.workoutDate : DateFormat('MM.dd').format(date),
                    style: AppTextStyles.eyebrow.copyWith(color: AppColors.ink),
                  ),
                  if (date != null)
                    Text(DateFormat('EEE', 'en_US').format(date).toUpperCase(), style: AppTextStyles.counter),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    names.isEmpty ? 'PT 운동' : names,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLg,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${workout.exercises.length}종목 · ${workout.totalSets}세트 · 총 볼륨 $volume kg',
                    style: AppTextStyles.bodySm,
                  ),
                  if (workout.note != null && workout.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      workout.note!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
