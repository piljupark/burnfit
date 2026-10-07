import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
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
import '../../widgets/app_action_row.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_filter_tabs.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/feedback_sheet.dart';
import '../../widgets/orb_loader.dart';
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
  final _profileKey = GlobalKey<_ProfileTabState>();

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

  void _openInbodyInput() {
    if (_tabController.index != 0) _tabController.animateTo(0);
    _profileKey.currentState?.openInbodySheet();
  }

  /// '여성 · 28세 · 165cm · email' 형식의 메타 줄.
  String _memberMeta(AppUser m) {
    final gender = switch (m.gender) {
      Gender.male => '남성',
      Gender.female => '여성',
      Gender.other => null,
      null => null,
    };
    int? age;
    final birth = m.birthDate?.trim() ?? '';
    if (birth.length == 8) {
      final y = int.tryParse(birth.substring(0, 4));
      final mo = int.tryParse(birth.substring(4, 6));
      final d = int.tryParse(birth.substring(6, 8));
      if (y != null && mo != null && d != null) {
        final now = DateTime.now();
        age = now.year - y - ((now.month < mo || (now.month == mo && now.day < d)) ? 1 : 0);
      }
    }
    final height = m.profile?.height;
    return [
      ?gender,
      if (age != null) '$age세',
      if (height != null) '${_formatProfileValue(height)}cm',
      if (m.email.isNotEmpty) m.email,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    const tabs = ['프로필', '식단', '운동', '유산소'];
    final meta = _memberMeta(m);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 앱바 ─────────────────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.hairline)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: AppScreenHeader(
                title: '회원 상세',
                onBack: () => Navigator.of(context).pop(),
                trailing: Transform.translate(
                  offset: const Offset(12, 0),
                  child: AppIconButton(
                    icon: AppIcons.more,
                    label: '더보기',
                    onPressed: _showMoreActions,
                  ),
                ),
              ),
            ),
            // ── 회원 머리 ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, AppSpacing.base,
              ),
              child: Row(
                children: [
                  AppAvatar(name: m.name, seed: m.uid, size: 56),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: AppTextStyles.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (meta.isNotEmpty)
                          Text(meta, style: AppTextStyles.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── 행동 (외곽선 두 개) ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '피드백 작성',
                      icon: const Icon(AppIcons.feedback),
                      variant: AppButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: () => _writeFeedback(type: fb.FeedbackTargetType.general),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'InBody 입력',
                      icon: const Icon(AppIcons.inbody),
                      variant: AppButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: m.shareSettings.body ? _openInbodyInput : null,
                    ),
                  ),
                ],
              ),
            ),
            // ── 탭 칩 (위아래 hairline) ──────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: AppColors.hairline)),
              ),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) => AppScrollableChips(
                  labels: tabs,
                  selectedIndex: _tabController.index,
                  onSelected: (i) => _tabController.animateTo(i),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ProfileTab(key: _profileKey, member: m, ptInfo: _ptInfo),
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
      ),
    );
  }

  Future<void> _showMoreActions() async {
    final m = widget.member;
    await showAppBottomSheet<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBottomSheetHeader(title: m.name, subtitle: m.email.isEmpty ? null : m.email),
            AppSheetAction(
              icon: AppIcons.feedback,
              label: '피드백 작성',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _writeFeedback(type: fb.FeedbackTargetType.general);
              },
            ),
            if (m.shareSettings.body) ...[
              const AppRowDivider(),
              AppSheetAction(
                icon: AppIcons.inbody,
                label: 'InBody 입력',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openInbodyInput();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 프로필 탭: 신체 정보 숫자 격자 → PT 정보 카드 → InBody 목록
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  final AppUser member;
  final PtInfo? ptInfo;

  const _ProfileTab({super.key, required this.member, this.ptInfo});

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
        title: const Text('InBody 기록 삭제'),
        content: Text('${item.measurementDate} 측정 기록 1건을 삭제합니다. 되돌릴 수 없습니다.'),
        actions: [
          AppButton(
            label: '취소',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: '삭제',
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
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

  /// 상단 'InBody 입력' 버튼에서 부른다.
  Future<void> openInbodySheet() => _openInbodySheet();

  Future<void> _showInbodyDetail(Inbody item) async {
    String fmt(num v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
    final rows = <(String, String)>[
      ('체중', '${fmt(item.weight)} kg'),
      if (item.muscleMass != null) ('골격근량', '${fmt(item.muscleMass!)} kg'),
      if (item.bodyFat != null) ('체지방량', '${fmt(item.bodyFat!)} kg'),
      if (item.bodyFatPercent != null) ('체지방률', '${fmt(item.bodyFatPercent!)}%'),
      if (item.bmi != null) ('BMI', fmt(item.bmi!)),
      if (item.bmr != null) ('BMR', '${fmt(item.bmr!)} kcal'),
      if (item.visceralFat != null) ('내장지방 레벨', '${item.visceralFat}'),
    ];
    await showAppBottomSheet<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBottomSheetHeader(title: 'InBody 기록', subtitle: item.measurementDate),
            for (var i = 0; i < rows.length; i++) _KeyValueRow(label: rows[i].$1, value: rows[i].$2, divider: true),
            const SizedBox(height: AppSpacing.sm),
            AppSheetAction(
              icon: AppIcons.trash,
              label: '기록 삭제',
              destructive: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _deleteInbody(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final ptInfo = widget.ptInfo;
    final p = member.profile;
    final fmt = DateFormat('yyyy.MM.dd');

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
      children: [
        if (!member.shareSettings.body)
          const TrainerShareBlockedMessage(message: '회원이 신체 정보 공유를 꺼두었습니다.')
        else if (p != null) ...[
          const AppMonthHeader(label: '체성분'),
          AppStatGrid(
            cells: [
              _metric('키', p.height, 'cm'),
              _metric('체중', p.weight, 'kg'),
              _metric('골격근', p.muscleMass, 'kg'),
              _metric('체지방', p.bodyFat, 'kg'),
              AppKpiCard(
                label: 'BMI',
                value: p.bmi != null ? p.bmi!.toStringAsFixed(1) : '-',
                unit: '',
                framed: false,
                valueSize: 22,
              ),
            ],
          ),
        ],
        if (ptInfo != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: _PtInfoCard(
              remaining: '${ptInfo.remainingSessions} / ${ptInfo.totalSessions}회',
              startDate: ptInfo.startDate != null ? fmt.format(ptInfo.startDate!) : '-',
              endDate: ptInfo.endDate != null ? fmt.format(ptInfo.endDate!) : '-',
              dDay: _dDayLabel(ptInfo.endDate),
            ),
          ),
        if (member.shareSettings.body)
          _InbodySection(
            items: _inbodies,
            isLoading: _loadingInbodies,
            onAdd: _openInbodySheet,
            onOpen: _showInbodyDetail,
          ),
      ],
    );
  }

  Widget _metric(String label, double? value, String unit) {
    return AppKpiCard(
      label: label,
      value: value != null ? _formatProfileValue(value) : '-',
      unit: value != null ? unit : '',
      framed: false,
      valueSize: 22,
    );
  }

  /// 종료일까지 남은 날 (D-12, 당일이면 오늘, 지났으면 종료).
  String? _dDayLabel(DateTime? end) {
    if (end == null) return null;
    final now = DateTime.now();
    final days = DateTime(end.year, end.month, end.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return '종료';
    if (days == 0) return '오늘';
    return 'D-$days';
  }
}

class _PtInfoCard extends StatelessWidget {
  final String remaining;
  final String startDate;
  final String endDate;
  final String? dDay;

  const _PtInfoCard({required this.remaining, required this.startDate, required this.endDate, this.dDay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(child: Text('PT 정보', style: AppTextStyles.bodySm.copyWith(color: AppColors.body))),
                if (dDay != null) AppTag(dDay!, muted: dDay == '종료'),
              ],
            ),
          ),
          _KeyValueRow(label: '잔여 횟수', value: remaining, divider: true),
          _KeyValueRow(label: '시작일', value: startDate, divider: true),
          _KeyValueRow(label: '종료일', value: endDate),
        ],
      ),
    );
  }
}

/// 44 높이 키/값 줄. 키는 body, 값은 ink.
class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool divider;

  const _KeyValueRow({required this.label, required this.value, this.divider = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.touchMin),
      decoration: divider
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.hairline)))
          : null,
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyMd.copyWith(color: AppColors.body))),
          Text(value, style: AppTextStyles.bodyMd),
        ],
      ),
    );
  }
}

class _InbodySection extends StatelessWidget {
  final List<Inbody> items;
  final bool isLoading;
  final VoidCallback onAdd;
  final void Function(Inbody) onOpen;

  const _InbodySection({
    required this.items,
    required this.isLoading,
    required this.onAdd,
    required this.onOpen,
  });

  String _fmt(num value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppMonthHeader(
          label: '인바디',
          count: '${items.length}건',
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, 0),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: OrbLoader.inline(semanticLabel: 'InBody 기록 불러오는 중')),
          )
        else if (items.isEmpty)
          AppEmptyState(
            icon: AppIcons.inbody,
            message: 'InBody 기록이 없습니다.',
            actionLabel: '첫 기록 입력',
            onAction: onAdd,
          )
        else
          for (final item in items)
            Semantics(
              button: true,
              child: InkWell(
                onTap: () => onOpen(item),
                highlightColor: AppColors.canvasSoft,
                splashFactory: NoSplash.splashFactory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.md),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.hairline))),
                  child: Row(
                    children: [
                      TrainerDateBlock(date: item.measurementDate),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_fmt(item.weight)}kg', style: AppTextStyles.bodyLg),
                            Text(
                              [
                                if (item.muscleMass != null) '골격근 ${_fmt(item.muscleMass!)}',
                                if (item.bodyFatPercent != null) '체지방률 ${_fmt(item.bodyFatPercent!)}%',
                                if (item.bodyFatPercent == null && item.bodyFat != null) '체지방 ${_fmt(item.bodyFat!)}kg',
                              ].join(' · '),
                              style: AppTextStyles.bodySm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(AppIcons.forward, size: AppSize.icon, color: AppColors.mute),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

String _formatProfileValue(num value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}
