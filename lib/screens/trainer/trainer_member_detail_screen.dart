import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../models/cardio.dart';
import '../../models/feedback.dart' as fb;
import '../../models/inbody.dart';
import '../../models/meal.dart';
import '../../models/pt_info.dart';
import '../../models/user.dart';
import '../../models/workout.dart';
import '../../services/cardio_service.dart';
import '../../services/firestore_service.dart';
import '../../services/meal_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/feedback_sheet.dart';
import '../../widgets/status_badge.dart';
import 'trainer_inbody_sheet.dart';
import 'trainer_member_tabs.dart';

class TrainerMemberDetailScreen extends StatefulWidget {
  final AppUser member;

  const TrainerMemberDetailScreen({super.key, required this.member});

  @override
  State<TrainerMemberDetailScreen> createState() =>
      _TrainerMemberDetailScreenState();
}

class _TrainerMemberDetailScreenState extends State<TrainerMemberDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Meal> _meals = [];
  List<Workout> _workouts = [];
  List<Cardio> _cardios = [];
  PtInfo? _ptInfo;

  bool _loadingMeals = false;
  bool _loadingWorkouts = false;
  bool _loadingCardios = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPtInfo();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    switch (_tabController.index) {
      case 1:
        if (_meals.isEmpty) _loadMeals();
        break;
      case 2:
        if (_workouts.isEmpty) _loadWorkouts();
        break;
      case 3:
        if (_cardios.isEmpty) _loadCardios();
        break;
    }
  }

  String get _rangeStart {
    return DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().subtract(Duration(days: AppConstants.recentDays)));
  }

  String get _rangeEnd {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _loadPtInfo() async {
    try {
      final ptInfo = await FirestoreService.getPtInfo(
        widget.member.uid,
        centerId: widget.member.centerId,
      );
      if (!mounted) return;
      setState(() => _ptInfo = ptInfo);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  Future<void> _loadMeals() async {
    if (!widget.member.shareSettings.meal) return;
    setState(() => _loadingMeals = true);
    try {
      final list = await MealService.getMealsByDateRange(
        widget.member.centerId,
        widget.member.uid,
        _rangeStart,
        _rangeEnd,
      );
      if (!mounted) return;
      setState(() => _meals = list);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _loadingMeals = false);
      }
    }
  }

  Future<void> _loadWorkouts() async {
    if (!widget.member.shareSettings.workout) return;
    setState(() => _loadingWorkouts = true);
    try {
      final list = await WorkoutService.getWorkoutsByDateRange(
        widget.member.centerId,
        widget.member.uid,
        _rangeStart,
        _rangeEnd,
        workoutType: WorkoutType.personal,
      );
      if (!mounted) return;
      setState(() => _workouts = list);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _loadingWorkouts = false);
      }
    }
  }

  Future<void> _loadCardios() async {
    if (!widget.member.shareSettings.workout) return;
    setState(() => _loadingCardios = true);
    try {
      final list = await CardioService.getCardiosByDateRange(
        widget.member.centerId,
        widget.member.uid,
        _rangeStart,
        _rangeEnd,
      );
      if (!mounted) return;
      setState(() => _cardios = list);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _loadingCardios = false);
      }
    }
  }

  Future<void> _writeFeedback({
    required fb.FeedbackTargetType type,
    String? targetId,
    String? targetDate,
  }) async {
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;

    fb.Feedback? existing;
    try {
      existing = targetId == null
          ? null
          : await FirestoreService.getFeedbackByTarget(
              targetId,
              centerId: widget.member.centerId,
              memberId: widget.member.uid,
              trainerId: trainer.uid,
            );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
      return;
    }

    if (!mounted) return;
    final result = await FeedbackSheet.show(
      context,
      centerId: widget.member.centerId,
      trainerId: trainer.uid,
      trainerName: trainer.name,
      memberId: widget.member.uid,
      memberName: widget.member.name,
      targetType: type,
      targetId: targetId,
      targetDate: targetDate,
      existing: existing,
    );

    if (result == true) {
      if (type == fb.FeedbackTargetType.meal) _loadMeals();
      if (type == fb.FeedbackTargetType.workout) _loadWorkouts();
      if (type == fb.FeedbackTargetType.cardio) _loadCardios();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final tabs = const ['프로필', '식단', '운동', '유산소'];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── 네비게이션 바 + 회원 프로필 ────────────────���─────────────────
          Builder(
            builder: (context) {
              final topPadding = MediaQuery.of(context).padding.top;
              return Padding(
                padding: EdgeInsets.fromLTRB(16, topPadding + AppSpacing.sm, 16, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 네비게이션 행
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              size: 28,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _writeFeedback(
                            type: fb.FeedbackTargetType.general,
                          ),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(AppSpacing.md),
                    // 아바타 + 이름 + 이메일
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.trainer.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            m.name.isNotEmpty
                                ? m.name.substring(0, 1).toUpperCase()
                                : '?',
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.trainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Gap(AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.name,
                                style: AppTextStyles.headline.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Gap(AppSpacing.xxs),
                              Text(
                                m.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          // ── 탭 바 ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: List.generate(tabs.length, (index) {
                      final selected = _tabController.index == index;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.brand
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              tabs[index],
                              style: AppTextStyles.label.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? AppColors.textOnAccent
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ProfileTab(member: m, ptInfo: _ptInfo),
                TrainerMealsTab(
                  meals: _meals,
                  isLoading: _loadingMeals,
                  canView: m.shareSettings.meal,
                  onFeedback: (meal) => _writeFeedback(
                    type: fb.FeedbackTargetType.meal,
                    targetId: meal.id,
                    targetDate: meal.mealDate,
                  ),
                  onRefresh: _loadMeals,
                ),
                TrainerWorkoutsTab(
                  workouts: _workouts,
                  isLoading: _loadingWorkouts,
                  canView: m.shareSettings.workout,
                  onFeedback: (w) => _writeFeedback(
                    type: fb.FeedbackTargetType.workout,
                    targetId: w.id,
                    targetDate: w.workoutDate,
                  ),
                  onRefresh: _loadWorkouts,
                ),
                TrainerCardiosTab(
                  cardios: _cardios,
                  isLoading: _loadingCardios,
                  canView: m.shareSettings.workout,
                  onFeedback: (c) => _writeFeedback(
                    type: fb.FeedbackTargetType.cardio,
                    targetId: c.id,
                    targetDate: c.cardioDate,
                  ),
                  onRefresh: _loadCardios,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  final AppUser member;
  final PtInfo? ptInfo;

  const _ProfileTab({required this.member, this.ptInfo});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  List<Inbody> _inbodies = [];
  bool _loadingInbodies = false;

  @override
  void initState() {
    super.initState();
    if (widget.member.shareSettings.body) {
      _loadInbodies();
    }
  }

  Future<void> _loadInbodies() async {
    if (!widget.member.shareSettings.body) return;
    setState(() => _loadingInbodies = true);
    try {
      final list = await FirestoreService.getInbodiesByMember(
        widget.member.uid,
        centerId: widget.member.centerId,
        limit: 20,
      );
      if (!mounted) return;
      setState(() => _inbodies = list);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _loadingInbodies = false);
      }
    }
  }

  Future<void> _openInbodySheet() async {
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;

    final saved = await showAppBottomSheet<bool>(
      context: context,
      child: TrainerInbodyInputSheet(member: widget.member, trainer: trainer),
    );

    if (saved == true) {
      await _loadInbodies();
    }
  }

  Future<void> _deleteInbody(Inbody item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('InBody 기록 삭제'),
        content: Text('${item.measurementDate} 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirestoreService.deleteInbody(item.id);
      await _loadInbodies();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final ptInfo = widget.ptInfo;
    final p = member.profile;
    final fmt = DateFormat('yyyy.MM.dd');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xl2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!member.shareSettings.body) ...[
            TrainerShareBlockedMessage(message: '회원이 신체 정보 공유를 꺼두었습니다.'),
            const Gap(AppSpacing.lg),
          ] else if (p != null) ...[
            Text('신체 정보', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700)),
            const Gap(AppSpacing.sm),
            _MetricGrid(
              metrics: [
                _MetricData(
                  '키',
                  p.height != null ? _formatProfileValue(p.height!) : '-',
                  'cm',
                ),
                _MetricData(
                  '체중',
                  p.weight != null ? _formatProfileValue(p.weight!) : '-',
                  'kg',
                ),
                _MetricData(
                  '골격근',
                  p.muscleMass != null
                      ? _formatProfileValue(p.muscleMass!)
                      : '-',
                  'kg',
                ),
                _MetricData(
                  '체지방',
                  p.bodyFat != null ? _formatProfileValue(p.bodyFat!) : '-',
                  'kg',
                ),
                _MetricData(
                  'BMI',
                  p.bmi != null ? p.bmi!.toStringAsFixed(1) : '-',
                  null,
                ),
              ],
            ),
            const Gap(AppSpacing.lg),
          ],
          if (ptInfo != null) ...[
            Text('PT 정보', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700)),
            const Gap(AppSpacing.sm),
            _InfoPanel(
              rows: [
                _InfoData(
                  '시작일',
                  ptInfo.startDate != null
                      ? fmt.format(ptInfo.startDate!)
                      : '-',
                ),
                _InfoData(
                  '종료일',
                  ptInfo.endDate != null ? fmt.format(ptInfo.endDate!) : '-',
                ),
                _InfoData(
                  '잔여 횟수',
                  '${ptInfo.remainingSessions} / ${ptInfo.totalSessions}회',
                ),
              ],
            ),
            const Gap(AppSpacing.lg),
          ],
          if (member.shareSettings.body) ...[
            _InbodySection(
              items: _inbodies,
              isLoading: _loadingInbodies,
              onAdd: _openInbodySheet,
              onDelete: _deleteInbody,
            ),
          ],
        ],
      ),
    );
  }
}

class _InbodySection extends StatelessWidget {
  final List<Inbody> items;
  final bool isLoading;
  final VoidCallback onAdd;
  final void Function(Inbody) onDelete;

  const _InbodySection({
    required this.items,
    required this.isLoading,
    required this.onAdd,
    required this.onDelete,
  });

  String _fmt(num value) {
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('InBody 기록', style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700))),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '입력',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.sm),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.brand,
              ),
            ),
          )
        else if (items.isEmpty)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.monitor_weight_outlined,
                    color: AppColors.textTertiary,
                    size: 28,
                  ),
                  const Gap(AppSpacing.xs),
                  Text(
                    'InBody 기록이 없습니다.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  AppButton(
                    label: '첫 기록 입력',
                    onPressed: onAdd,
                    size: AppButtonSize.sm,
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              for (final item in items) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.measurementDate,
                            style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const Gap(AppSpacing.sm),
                          StatusBadge.fromString(
                            item.measurementDate,
                            AppColors.info,
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => onDelete(item),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _InbodyMetric(
                            label: '체중',
                            value: '${_fmt(item.weight)} kg',
                          ),
                          if (item.muscleMass != null)
                            _InbodyMetric(
                              label: '골격근',
                              value: '${_fmt(item.muscleMass!)} kg',
                            ),
                          if (item.bodyFat != null)
                            _InbodyMetric(
                              label: '체지방',
                              value: '${_fmt(item.bodyFat!)} kg',
                            ),
                          if (item.bodyFatPercent != null)
                            _InbodyMetric(
                              label: '체지방률',
                              value: '${_fmt(item.bodyFatPercent!)}%',
                            ),
                          if (item.bmi != null)
                            _InbodyMetric(label: 'BMI', value: _fmt(item.bmi!)),
                          if (item.bmr != null)
                            _InbodyMetric(
                              label: 'BMR',
                              value: '${_fmt(item.bmr!)} kcal',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(AppSpacing.sm),
              ],
            ],
          ),
      ],
    );
  }
}

class _InbodyMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InbodyMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const Gap(2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatProfileValue(num value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}

class _MetricData {
  final String label;
  final String value;
  final String? suffix;

  const _MetricData(this.label, this.value, this.suffix);
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricData> metrics;

  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: metrics
              .map((metric) => _MetricTile(width: itemWidth, data: metric))
              .toList(),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final double width;
  final _MetricData data;

  const _MetricTile({required this.width, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: AppTextStyles.captionSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const Gap(AppSpacing.xs),
          RichText(
            text: TextSpan(
              style: AppTextStyles.h2.copyWith(
                fontSize: 22,
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(text: data.value),
                if (data.suffix != null && data.value != '-')
                  TextSpan(
                    text: ' ${data.suffix}',
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoData {
  final String label;
  final String value;

  const _InfoData(this.label, this.value);
}

class _InfoPanel extends StatelessWidget {
  final List<_InfoData> rows;

  const _InfoPanel({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Text(
                      row.label,
                      style: AppTextStyles.captionSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      row.value,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

