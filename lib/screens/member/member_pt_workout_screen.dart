import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/workout.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                0,
              ),
              child: AppScreenHeader(
                title: 'PT 운동 기록',
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.brand,
                      backgroundColor: AppColors.card,
                      child: _errorMessage != null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 120),
                                AppErrorCard(
                                  message: _errorMessage!,
                                  onRetry: _load,
                                ),
                              ],
                            )
                          : _workouts.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenH,
                              ),
                              children: [
                                const SizedBox(height: 120),
                                AppEmptyState(
                                  icon: Icons.fitness_center_outlined,
                                  message: 'PT 운동 기록이 없습니다.',
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.screenH,
                                0,
                                AppSpacing.screenH,
                                AppSpacing.xl2,
                              ),
                              itemCount: _workouts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 1),
                              itemBuilder: (_, index) {
                                final workout = _workouts[index];
                                return AppCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.xs,
                                              vertical: AppSpacing.xxs,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors
                                                  .trainer
                                                  .withValues(alpha: 0.16),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.full,
                                                  ),
                                            ),
                                            child: Text(
                                              'PT 기록',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                    color: AppColors
                                                        .trainer,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            workout.workoutDate,
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color: AppColors
                                                      .textTertiary,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const Gap(AppSpacing.sm),
                                      Text(
                                        workout.exercises
                                            .map((e) => e.name)
                                            .join(', '),
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const Gap(AppSpacing.xxs),
                                      Text(
                                        '${workout.exercises.length}종목 · ${workout.totalSets}세트 · 총 볼륨 ${workout.totalVolume.toStringAsFixed(0)} kg',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (workout.note != null) ...[
                                        const Gap(AppSpacing.xs),
                                        Text(
                                          workout.note!,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors
                                                    .textSecondary,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
