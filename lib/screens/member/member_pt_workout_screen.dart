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
      content = const [
        AppEmptyState(
          icon: AppIcons.workout,
          card: true,
          margin: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xl4,
            AppSpacing.screenH,
            0,
          ),
          illustration: _LiftingBarbell(),
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
    final volume = NumberFormat('#,###').format(workout.totalVolume.round());
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

/// 빈 화면 그림: 바벨 56×34가 위아래로 들렸다 내려옴 (시안 `lift`: 1.8s, 5 → -5 → 5).
class _LiftingBarbell extends StatefulWidget {
  const _LiftingBarbell();

  @override
  State<_LiftingBarbell> createState() => _LiftingBarbellState();
}

class _LiftingBarbellState extends State<_LiftingBarbell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: const CustomPaint(size: Size(56, 34), painter: _BarbellPainter()),
      builder: (context, child) {
        final v = _controller.value;
        final tri = v < 0.5 ? v * 2 : (1 - v) * 2;
        final dy = 5 - 10 * Curves.easeInOut.transform(tri);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
    );
  }
}

/// 시안 SVG(200×110): 가운데 봉 #C8C8CC + 양쪽 원판 #9A9AA0 두 겹.
class _BarbellPainter extends CustomPainter {
  const _BarbellPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 110);
    void rect(double x, double y, double w, double h, double r, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        Paint()..color = c,
      );
    }

    const bar = Color(0xFFC8C8CC);
    final plate = AppColors.faint;
    rect(40, 49, 120, 12, 6, bar);
    rect(26, 23, 22, 64, 8, plate);
    rect(8, 33, 18, 44, 7, plate);
    rect(152, 23, 22, 64, 8, plate);
    rect(174, 33, 18, 44, 7, plate);
  }

  @override
  bool shouldRepaint(covariant _BarbellPainter oldDelegate) => false;
}
