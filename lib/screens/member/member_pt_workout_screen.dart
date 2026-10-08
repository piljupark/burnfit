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
import '../../widgets/app_motion.dart';
import '../../widgets/brand_marks.dart';
import '../../widgets/workout_parts.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_loader.dart';

/// PT 운동 기록 (시안 MemA-PtWorkout · Empty): 가운데 17 머리 + 보조 12 →
/// 월 머리(17/500 '2026년 10월' + 개수) → 줄(날짜 칸 48 · 종목 16/500 · 요약 13 · 메모 회색 상자) → 월 사이 8 띠.
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
      final key = date == null
          ? workout.workoutDate
          : DateFormat('yyyy년 M월').format(date);
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
      content = [
        AppEmptyState(
          icon: AppIcons.workout,
          card: true,
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xl4,
            AppSpacing.screenH,
            0,
          ),
          // 시안 SVG(200×110)를 56×34에 늘려 그림: 봉 #C8C8CC + 양쪽 원판 faint 두 겹, 손잡이 없음,
          // 위아래 5씩 들렸다 내려옴.
          illustration: LiftingBarbellMark(
            size: const Size(56, 34),
            lift: 5,
            stretch: true,
            showHandle: false,
            barColor: _barColor,
            plateColor: AppColors.faint,
          ),
          message: 'PT 운동 기록이 없습니다',
          description: '최근 3개월 동안 트레이너와 함께한 운동이\n여기에 표시됩니다.',
        ),
      ];
    } else {
      content = [
        for (final group in _byMonth) ...[
          AppMonthHeader(
            label: group.key,
            count: '${group.value.length}',
            strong: true,
          ),
          for (final workout in group.value)
            // 시안 `slide`: 아래 10에서 떠오름, .4s
            AppEntrance(
              duration: const Duration(milliseconds: 400),
              child: _PtWorkoutRow(workout: workout),
            ),
          const AppSectionBand(top: AppSpacing.md),
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
            AppScreenHeader.centered(
              title: 'PT 운동 기록',
              subtitle: _isLoading || _workouts.isEmpty
                  ? null
                  : '최근 3개월 · ${_workouts.length}회',
              onBack: () => Navigator.of(context).pop(),
            ),
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

/// PT 기록 한 줄 (위아래 16, 아래 선 좌우 20 안쪽): 날짜 칸 48(위 2, 15/500 + 요일 12) + 간격 12 +
/// 종목 이름 16/500(줄 높이 1.4, 2줄) + 요약 13 mute(위 4) + 메모 회색 상자(위 10, 안쪽 12 14, 반경 14, 14 body).
class _PtWorkoutRow extends StatelessWidget {
  final Workout workout;

  const _PtWorkoutRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(workout.workoutDate);
    // 유산소 종목(속도 × 분)은 볼륨에서 뺀다 (종목마다 판단).
    final volume = NumberFormat(
      '#,###',
    ).format(workoutStrengthVolumeKg(workout).round());
    final names = workout.exercises.map((e) => e.name).join(', ');
    final note = workout.note?.trim() ?? '';

    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date == null
                            ? workout.workoutDate
                            : DateFormat('MM.dd').format(date),
                        style: AppTextStyles.bodyMd.medium.natural,
                      ),
                      if (date != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          DateFormat('E', 'ko').format(date),
                          style: AppTextStyles.captionSmall,
                        ),
                      ],
                    ],
                  ),
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
                      style: AppTextStyles.listTitle.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${workout.exercises.length}종목 · ${workout.totalSets}세트 · 총 볼륨 ${volume}kg',
                      style: AppTextStyles.bodySm,
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.canvasCard,
                          borderRadius: BorderRadius.circular(AppRadius.field),
                        ),
                        child: Text(
                          note,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.note.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 빈 화면 바벨 봉 색 (시안 #C8C8CC).
const Color _barColor = Color(0xFFC8C8CC);
