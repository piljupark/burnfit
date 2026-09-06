import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
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
import '../../widgets/app_section.dart';
import '../../services/meal_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/feedback_sheet.dart';
import '../../widgets/status_badge.dart';

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
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: AppTextStyles.h3),
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
                  GestureDetector(
                    onTap: () =>
                        _writeFeedback(type: fb.FeedbackTargetType.general),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.md,
              AppSpacing.screenH,
              0,
            ),
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5,
                    ),
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
                              style: AppTextStyles.bodySmall.copyWith(
                                color: selected
                                    ? AppColors.textOnAccent
                                    : AppColors.textTertiary,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
                _MealsTab(
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
                _WorkoutsTab(
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
                _CardiosTab(
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
      child: _InbodyInputSheet(member: widget.member, trainer: trainer),
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
            _ShareBlockedMessage(message: '회원이 신체 정보 공유를 꺼두었습니다.'),
            const Gap(AppSpacing.lg),
          ] else if (p != null) ...[
            Text('신체 정보', style: AppTextStyles.overline),
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
            Text('PT 정보', style: AppTextStyles.overline),
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
            Expanded(child: Text('InBody 기록', style: AppTextStyles.overline)),
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
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border, width: 0.5),
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
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
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
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
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
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InbodyInputSheet extends StatefulWidget {
  final AppUser member;
  final AppUser trainer;

  const _InbodyInputSheet({required this.member, required this.trainer});

  @override
  State<_InbodyInputSheet> createState() => _InbodyInputSheetState();
}

class _InbodyInputSheetState extends State<_InbodyInputSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dateCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _muscleCtrl = TextEditingController();
  final _bodyFatCtrl = TextEditingController();
  final _bodyFatPercentCtrl = TextEditingController();
  final _bmiCtrl = TextEditingController();
  final _bmrCtrl = TextEditingController();
  final _visceralFatCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _weightCtrl.dispose();
    _muscleCtrl.dispose();
    _bodyFatCtrl.dispose();
    _bodyFatPercentCtrl.dispose();
    _bmiCtrl.dispose();
    _bmrCtrl.dispose();
    _visceralFatCtrl.dispose();
    super.dispose();
  }

  double? _doubleOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  int? _intOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  String? _optionalNumber(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed) == null ? '숫자만 입력해주세요.' : null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateCtrl.text) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (selected == null) return;
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(selected);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final inbody = Inbody(
        id: const Uuid().v4(),
        centerId: widget.member.centerId,
        memberId: widget.member.uid,
        memberName: widget.member.name,
        trainerId: widget.trainer.uid,
        measurementDate: _dateCtrl.text.trim(),
        weight: double.parse(_weightCtrl.text.trim()),
        muscleMass: _doubleOrNull(_muscleCtrl),
        bodyFat: _doubleOrNull(_bodyFatCtrl),
        bodyFatPercent: _doubleOrNull(_bodyFatPercentCtrl),
        bmi: _doubleOrNull(_bmiCtrl),
        bmr: _doubleOrNull(_bmrCtrl),
        visceralFat: _intOrNull(_visceralFatCtrl),
        createdAt: now,
        updatedAt: now,
      );

      await FirestoreService.saveInbody(inbody);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final numberType = const TextInputType.numberWithOptions(decimal: true);
    final numberFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
    ];

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBottomSheetHeader(
              title: 'InBody 입력',
              subtitle: '${widget.member.name} 회원의 측정 기록',
            ),
            AppTextField(
              label: '측정일',
              controller: _dateCtrl,
              readOnly: true,
              suffix: IconButton(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
              ),
              validator: (v) => DateTime.tryParse(v?.trim() ?? '') == null
                  ? '측정일을 선택해주세요.'
                  : null,
            ),
            const Gap(AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: '체중 (kg)',
                    controller: _weightCtrl,
                    keyboardType: numberType,
                    inputFormatters: numberFormatters,
                    validator: (v) {
                      final value = double.tryParse(v?.trim() ?? '');
                      if (value == null) return '체중을 입력해주세요.';
                      if (value <= 0) return '0보다 큰 값을 입력해주세요.';
                      return null;
                    },
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: '골격근량 (kg)',
                    controller: _muscleCtrl,
                    keyboardType: numberType,
                    inputFormatters: numberFormatters,
                    validator: _optionalNumber,
                  ),
                ),
              ],
            ),
            const Gap(AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: '체지방량 (kg)',
                    controller: _bodyFatCtrl,
                    keyboardType: numberType,
                    inputFormatters: numberFormatters,
                    validator: _optionalNumber,
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: '체지방률 (%)',
                    controller: _bodyFatPercentCtrl,
                    keyboardType: numberType,
                    inputFormatters: numberFormatters,
                    validator: _optionalNumber,
                  ),
                ),
              ],
            ),
            const Gap(AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'BMI',
                    controller: _bmiCtrl,
                    keyboardType: numberType,
                    inputFormatters: numberFormatters,
                    validator: _optionalNumber,
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: 'BMR',
                    controller: _bmrCtrl,
                    keyboardType: numberType,
                    inputFormatters: numberFormatters,
                    validator: _optionalNumber,
                  ),
                ),
              ],
            ),
            const Gap(AppSpacing.sm),
            AppTextField(
              label: '내장지방 레벨',
              controller: _visceralFatCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final trimmed = v?.trim() ?? '';
                if (trimmed.isEmpty) return null;
                return int.tryParse(trimmed) == null ? '숫자만 입력해주세요.' : null;
              },
              textInputAction: TextInputAction.done,
            ),
            const Gap(AppSpacing.lg),
            AppButton(
              label: '저장',
              onPressed: _save,
              isLoading: _isSaving,
              fullWidth: true,
              size: AppButtonSize.lg,
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(AppSpacing.xs),
          RichText(
            text: TextSpan(
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(text: data.value),
                if (data.suffix != null && data.value != '-')
                  TextSpan(
                    text: ' ${data.suffix}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
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
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
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
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      row.value,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
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

class _ShareBlockedMessage extends StatelessWidget {
  final String message;

  const _ShareBlockedMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.visibility_off_outlined,
                color: AppColors.textTertiary,
                size: 28,
              ),
              const Gap(AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _MealsTab extends StatelessWidget {
  final List<Meal> meals;
  final bool isLoading;
  final bool canView;
  final void Function(Meal) onFeedback;
  final Future<void> Function() onRefresh;

  const _MealsTab({
    required this.meals,
    required this.isLoading,
    required this.canView,
    required this.onFeedback,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!canView) {
      return const _ShareBlockedMessage(message: '회원이 식단 기록 공유를 꺼두었습니다.');
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: onRefresh,
      child: meals.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenH),
              children: const [
                AppEmptyState(
                  icon: Icons.restaurant_outlined,
                  message: '최근 30일 식단 기록이 없습니다.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.xl2,
              ),
              itemCount: meals.length,
              separatorBuilder: (_, __) => const Gap(AppSpacing.sm),
              itemBuilder: (_, i) {
                final meal = meals[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge.fromString(
                            meal.mealType.label,
                            AppColors.info,
                          ),
                          const Spacer(),
                          Text(
                            meal.mealDate,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      if (meal.imageUrls.isNotEmpty) ...[
                        const Gap(10),
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: meal.imageUrls.length,
                            separatorBuilder: (_, __) =>
                                const Gap(AppSpacing.xs),
                            itemBuilder: (_, j) => ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                              child: Image.network(
                                meal.imageUrls[j],
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (meal.description != null) ...[
                        const Gap(AppSpacing.xs),
                        Text(meal.description!, style: AppTextStyles.bodySmall),
                      ],
                      const Gap(AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (meal.calories != null)
                            Text(
                              '${meal.calories} kcal',
                              style: AppTextStyles.caption,
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => onFeedback(meal),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                ),
                                child: Text(
                                  meal.hasFeedback ? '피드백 수정' : '피드백 작성',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _WorkoutsTab extends StatelessWidget {
  final List<Workout> workouts;
  final bool isLoading;
  final bool canView;
  final void Function(Workout) onFeedback;
  final Future<void> Function() onRefresh;

  const _WorkoutsTab({
    required this.workouts,
    required this.isLoading,
    required this.canView,
    required this.onFeedback,
    required this.onRefresh,
  });

  Color _categoryColor(WorkoutCategory c) {
    switch (c) {
      case WorkoutCategory.shoulder:
        return AppColors.trainer;
      case WorkoutCategory.chest:
        return AppColors.categoryUpper;
      case WorkoutCategory.back:
        return AppColors.categoryLower;
      case WorkoutCategory.lower:
        return AppColors.categoryCore;
      case WorkoutCategory.arms:
        return AppColors.diet;
      case WorkoutCategory.abs:
        return AppColors.workout;
      case WorkoutCategory.cardio:
        return AppColors.categoryCardio;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canView) {
      return const _ShareBlockedMessage(message: '회원이 운동 기록 공유를 꺼두었습니다.');
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: onRefresh,
      child: workouts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenH),
              children: const [
                AppEmptyState(
                  icon: Icons.fitness_center_outlined,
                  message: '최근 30일 운동 기록이 없습니다.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.xl2,
              ),
              itemCount: workouts.length,
              separatorBuilder: (_, __) => const Gap(AppSpacing.sm),
              itemBuilder: (_, i) {
                final w = workouts[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge.fromString(
                            w.category.label,
                            _categoryColor(w.category),
                          ),
                          const Spacer(),
                          Text(
                            w.workoutDate,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.xs),
                      Text(
                        w.exercises.map((e) => e.name).join(', '),
                        style: AppTextStyles.body,
                      ),
                      const Gap(AppSpacing.xxs),
                      Text(
                        '${w.exercises.length}종목 · ${w.totalSets}세트 · 총 볼륨 ${w.totalVolume.toStringAsFixed(0)} kg',
                        style: AppTextStyles.caption,
                      ),
                      const Gap(AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => onFeedback(w),
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
                              w.hasFeedback ? '피드백 수정' : '피드백 작성',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _CardiosTab extends StatelessWidget {
  final List<Cardio> cardios;
  final bool isLoading;
  final bool canView;
  final void Function(Cardio) onFeedback;
  final Future<void> Function() onRefresh;

  const _CardiosTab({
    required this.cardios,
    required this.isLoading,
    required this.canView,
    required this.onFeedback,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!canView) {
      return const _ShareBlockedMessage(message: '회원이 운동 기록 공유를 꺼두었습니다.');
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: onRefresh,
      child: cardios.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenH),
              children: const [
                AppEmptyState(
                  icon: Icons.directions_run_rounded,
                  message: '최근 30일 유산소 기록이 없습니다.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.xl2,
              ),
              itemCount: cardios.length,
              separatorBuilder: (_, __) => const Gap(AppSpacing.sm),
              itemBuilder: (_, i) {
                final c = cardios[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge.fromString(
                            c.type.label,
                            AppColors.categoryCardio,
                          ),
                          const Spacer(),
                          Text(
                            c.cardioDate,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.xs),
                      Text(c.summary, style: AppTextStyles.body),
                      if (c.note != null) ...[
                        const Gap(AppSpacing.xxs),
                        Text(c.note!, style: AppTextStyles.bodySmall),
                      ],
                      const Gap(AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => onFeedback(c),
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
                              c.hasFeedback ? '피드백 수정' : '피드백 작성',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
