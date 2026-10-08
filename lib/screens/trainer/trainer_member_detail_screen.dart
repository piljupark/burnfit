import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/birth_date.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_logger.dart';
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
import '../../services/body_profile_service.dart';
import '../../services/cardio_service.dart';
import '../../services/firestore_service.dart';
import '../../services/meal_service.dart';
import '../../services/user_provider.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_progress_bar.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/feedback_sheet.dart';
import 'trainer_inbody_sheet.dart';
import 'trainer_member_tabs.dart';

/// 트레이너 회원 상세 (기준 시안 TrainerMember):
/// 뒤로·더보기 머리(56) → 26 이름 + 14 요약 → 2칸 카드(주황 PT 남은 횟수 / 회색 최근 체중)
/// → 38 pill 탭 '운동 · 식단 · 유산소 · 정보' → 탭 내용 → 아래 고정 '인바디 입력' · '피드백 쓰기'.
class TrainerMemberDetailScreen extends StatefulWidget {
  final AppUser member;

  const TrainerMemberDetailScreen({super.key, required this.member});

  @override
  State<TrainerMemberDetailScreen> createState() =>
      _TrainerMemberDetailScreenState();
}

class _TrainerMemberDetailScreenState extends State<TrainerMemberDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['운동', '식단', '유산소', '정보'];
  static const _workoutTab = 0;
  static const _mealTab = 1;
  static const _cardioTab = 2;
  static const _infoTab = 3;

  late TabController _tabController;

  List<Meal> _meals = [];
  List<Workout> _workouts = [];
  List<Cardio> _cardios = [];
  List<Inbody> _inbodies = [];
  PtInfo? _ptInfo;

  /// 회원이 신체 정보 공유를 켠 경우에만 읽는다 (사용자 문서와 따로 저장됨).
  UserProfile? _body;

  bool _loadingMeals = false;
  bool _loadingWorkouts = false;
  bool _loadingCardios = false;
  bool _loadingInbodies = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPtInfo();
    _loadBody();
    _loadWorkouts();
    _loadInbodies();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// 탭을 누르거나 밀어서 바꿀 때, 아직 비어 있는 목록을 읽는다.
  void _onTabChanged() {
    switch (_tabController.index) {
      case _mealTab:
        if (_meals.isEmpty && !_loadingMeals) _loadMeals();
      case _workoutTab:
        if (_workouts.isEmpty && !_loadingWorkouts) _loadWorkouts();
      case _cardioTab:
        if (_cardios.isEmpty && !_loadingCardios) _loadCardios();
    }
    // 고른 pill을 다시 그린다.
    if (mounted) setState(() {});
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

  Future<void> _loadBody() async {
    try {
      final body = await BodyProfileService.loadShared(widget.member);
      if (!mounted) return;
      setState(() => _body = body);
    } catch (e) {
      // 신체 정보는 보조 정보라 실패해도 화면은 그대로 쓴다 ('-'로 보인다).
      AppLogger.debug('[TrainerMemberDetail] 신체 정보 로드 실패: $e');
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

  /// 'InBody 입력': 정보 탭으로 옮기고 입력 시트를 연다. 저장하면 인바디 목록을 다시 읽는다.
  Future<void> _openInbodyInput() async {
    if (!widget.member.shareSettings.body) return;
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;
    if (_tabController.index != _infoTab) _tabController.animateTo(_infoTab);

    final saved = await showAppBottomSheet<bool>(
      context: context,
      child: TrainerInbodyInputSheet(member: widget.member, trainer: trainer),
    );
    if (saved == true) await _loadInbodies();
  }

  Future<void> _deleteInbody(Inbody item) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'InBody 기록 삭제',
      message: '${item.measurementDate} 측정 기록 1건을 삭제합니다. 되돌릴 수 없습니다.',
      confirmLabel: '삭제',
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

  Future<void> _showInbodyDetail(Inbody item) async {
    final deleteRequested = await showTrainerInbodyDetailSheet(context, item);
    if (deleteRequested == true && mounted) await _deleteInbody(item);
  }

  /// '여성 · 28세 · 165cm · email' 형식의 요약 줄.
  String _memberMeta(AppUser m) {
    // '기타'는 요약 줄에 적지 않는다.
    final gender = m.gender == Gender.other ? null : m.gender?.label;
    final age = ageFromBirthDate(m.birthDate);
    // 신체 정보 공유를 끈 회원은 키도 보여주지 않는다.
    final height = m.shareSettings.body ? _body?.height : null;
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
    final meta = _memberMeta(m);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 머리: 뒤로 · 더보기 (제목 없음) ─────────────────────────────
            AppScreenHeader.large(
              title: '',
              onBack: () => Navigator.of(context).pop(),
              trailing: AppIconButton(
                icon: AppIcons.more,
                label: '더보기',
                onPressed: _showMoreActions,
                color: AppColors.ink,
              ),
            ),
            // ── 26 이름 + 14 요약 ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.xs,
                AppSpacing.screenH,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      m.name,
                      style: AppTextStyles.displayMd.bold.natural.copyWith(
                        fontSize: 26,
                        letterSpacing: 26 * -0.019,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const Gap(AppSpacing.xs),
                    Text(
                      meta,
                      style: AppTextStyles.fieldLabel.natural,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // ── 2칸 카드 ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.base,
                AppSpacing.screenH,
                0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _PtSummaryCard(info: _ptInfo)),
                    const Gap(AppSpacing.sm),
                    Expanded(
                      child: _WeightSummaryCard(
                        shared: m.shareSettings.body,
                        inbodies: _inbodies,
                        fallbackWeight: _body?.weight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── 38 pill 탭 ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: AppViewTabs(
                labels: _tabs,
                compact: true,
                selectedIndex: _tabController.index,
                onSelect: (i) => _tabController.animateTo(i),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
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
                  _InfoTab(
                    member: m,
                    body: _body,
                    ptInfo: _ptInfo,
                    inbodies: _inbodies,
                    loadingInbodies: _loadingInbodies,
                    onAddInbody: _openInbodyInput,
                    onOpenInbody: _showInbodyDetail,
                  ),
                ],
              ),
            ),
            // ── 아래 고정 2칸 버튼 ──────────────────────────────────────────
            Container(
              color: AppColors.canvas,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                bottomInset + AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '인바디 입력',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.lg,
                      labelSize: 16,
                      bold: true,
                      fullWidth: true,
                      onPressed: m.shareSettings.body ? _openInbodyInput : null,
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: '피드백 쓰기',
                      variant: AppButtonVariant.dark,
                      size: AppButtonSize.lg,
                      labelSize: 16,
                      bold: true,
                      fullWidth: true,
                      onPressed: () =>
                          _writeFeedback(type: fb.FeedbackTargetType.general),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 더보기 시트 (시안 Tr-Member-More): 이름 + 이메일(14 mute) → 피드백 작성 · InBody 입력.
  Future<void> _showMoreActions() async {
    final m = widget.member;
    await showAppBottomSheet<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBottomSheetHeader(
              title: m.name,
              subtitle: m.email.isEmpty ? null : m.email,
              mutedSubtitle: true,
              gap: AppSpacing.md,
            ),
            AppSheetAction(
              icon: AppIcons.feedback,
              label: '피드백 작성',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _writeFeedback(type: fb.FeedbackTargetType.general);
              },
            ),
            if (m.shareSettings.body)
              AppSheetAction(
                icon: AppIcons.inbody,
                label: 'InBody 입력',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openInbodyInput();
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 머리 2칸 카드 (시안 TrainerMember): 안쪽 16 · 반경 18
// ─────────────────────────────────────────────────────────────────────────────

/// 주황 카드: 'PT 남은 횟수' 13 · '6회 / 20회' 22 · 10 아래 6 진행 막대(쓴 비율).
class _PtSummaryCard extends StatelessWidget {
  final PtInfo? info;

  const _PtSummaryCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onPrimary;
    final info = this.info;
    final total = info?.totalSessions ?? 0;
    final remaining = info?.remainingSessions ?? 0;
    final used = total == 0 ? 0.0 : ((total - remaining) / total);
    return Semantics(
      label: info == null
          ? 'PT 남은 횟수 정보 없음'
          : 'PT 남은 횟수 $remaining회, 전체 $total회',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PT 남은 횟수',
              style: AppTextStyles.bodySm.bold.natural.copyWith(color: fg),
            ),
            const Gap(AppSpacing.xs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: info == null ? '-' : '$remaining회'),
                  if (info != null)
                    TextSpan(
                      text: ' / $total회',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: fg.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
              style: _cardValueStyle.copyWith(color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(10),
            AppProgressBar(
              value: used,
              height: 6,
              color: fg,
              trackColor: fg.withValues(alpha: 0.15),
            ),
          ],
        ),
      ),
    );
  }
}

/// 22/700 카드 값.
TextStyle get _cardValueStyle => AppTextStyles.title.bold.natural.copyWith(
  fontSize: 22,
  letterSpacing: 22 * -0.019,
);

/// 회색 카드: 최근 체중 (최근 InBody, 없으면 신체 정보) + 직전 측정과의 차이 + 최근 체중 선.
/// 시안의 '스쿼트 추정 1RM'은 계산 근거가 없어 체중으로 대신한다.
class _WeightSummaryCard extends StatelessWidget {
  final bool shared;
  final List<Inbody> inbodies;
  final double? fallbackWeight;

  const _WeightSummaryCard({
    required this.shared,
    required this.inbodies,
    required this.fallbackWeight,
  });

  @override
  Widget build(BuildContext context) {
    final latest = shared
        ? (inbodies.isNotEmpty ? inbodies.first.weight : fallbackWeight)
        : null;
    final delta = shared && inbodies.length >= 2
        ? inbodies[0].weight - inbodies[1].weight
        : null;
    final deltaText = delta == null || delta.abs() < 0.05
        ? null
        : '${delta > 0 ? '+' : '-'}${_formatProfileValue(delta.abs())}';
    // 오래된 것 → 최근 순서, 최대 6번
    final points = shared
        ? inbodies.take(6).map((e) => e.weight).toList().reversed.toList()
        : const <double>[];

    return Semantics(
      label: latest == null
          ? '최근 체중 정보 없음'
          : '최근 체중 ${_formatProfileValue(latest)}kg'
                '${deltaText == null ? '' : ', 직전보다 $deltaText'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shared ? '최근 체중' : '체중 · 공유 꺼짐',
              style: AppTextStyles.bodySm.natural,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(AppSpacing.xs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: latest == null
                        ? '-'
                        : '${_formatProfileValue(latest)}kg',
                  ),
                  if (deltaText != null)
                    TextSpan(
                      text: ' $deltaText',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: AppColors.mute,
                      ),
                    ),
                ],
              ),
              style: _cardValueStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(6),
            SizedBox(
              height: 16,
              width: double.infinity,
              child: points.length < 2
                  ? null
                  : CustomPaint(
                      painter: _SparklinePainter(points, AppColors.ink),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 작은 추이 선: 2px ink, 둥근 끝. 위아래 1 여백.
class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = maxV - minV;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final t = range == 0 ? 0.5 : (values[i] - minV) / range;
      final y = 1 + (size.height - 2) * (1 - t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color || old.values.join(',') != values.join(',');
}

// ─────────────────────────────────────────────────────────────────────────────
// 정보 탭 (시안 Tr-Member-Profile): 체성분 3칸 격자 → PT 정보 줄 → 8 띠 → 인바디 목록
// ─────────────────────────────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final AppUser member;
  final UserProfile? body;
  final PtInfo? ptInfo;
  final List<Inbody> inbodies;
  final bool loadingInbodies;
  final VoidCallback onAddInbody;
  final void Function(Inbody) onOpenInbody;

  const _InfoTab({
    required this.member,
    required this.body,
    required this.ptInfo,
    required this.inbodies,
    required this.loadingInbodies,
    required this.onAddInbody,
    required this.onOpenInbody,
  });

  @override
  Widget build(BuildContext context) {
    final ptInfo = this.ptInfo;
    final p = body;
    final shared = member.shareSettings.body;
    final fmt = DateFormat('yyyy.MM.dd');

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
      children: [
        if (!shared)
          const TrainerShareBlockedMessage(
            message: '회원이 신체 정보 공유를 꺼두었습니다.',
            top: 40,
            bottom: AppSpacing.xl2,
          )
        else if (p != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.lg,
              AppSpacing.screenH,
              0,
            ),
            child: Semantics(
              header: true,
              child: Text('체성분', style: AppTextStyles.section),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              10,
              AppSpacing.screenH,
              0,
            ),
            child: _MetricGrid(
              cells: [
                ('키', p.height, 'cm'),
                ('체중', p.weight, 'kg'),
                ('골격근', p.muscleMass, 'kg'),
                ('체지방', p.bodyFat, 'kg'),
                ('BMI', p.bmi, ''),
              ],
            ),
          ),
        ],
        if (ptInfo != null) ...[
          // 남은 횟수는 머리의 주황 카드에 있으므로 여기서는 기간만 줄로 둔다.
          AppDayHeader(label: 'PT 정보', count: _dDayLabel(ptInfo.endDate)),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xs,
              AppSpacing.screenH,
              0,
            ),
            child: Column(
              children: [
                _KeyValueRow(
                  label: '남은 횟수',
                  value:
                      '${ptInfo.remainingSessions} / ${ptInfo.totalSessions}회',
                  divider: true,
                ),
                _KeyValueRow(
                  label: '시작일',
                  value: ptInfo.startDate != null
                      ? fmt.format(ptInfo.startDate!)
                      : '-',
                  divider: true,
                ),
                _KeyValueRow(
                  label: '종료일',
                  value: ptInfo.endDate != null
                      ? fmt.format(ptInfo.endDate!)
                      : '-',
                ),
              ],
            ),
          ),
        ],
        if (shared) ...[
          if (p != null || ptInfo != null) const AppSectionBand(top: 12),
          AppMonthHeader(
            label: '인바디',
            count: '${inbodies.length}건',
            strong: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              18,
              AppSpacing.screenH,
              AppSpacing.xs,
            ),
          ),
          if (loadingInbodies && inbodies.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: AppLoader.inline(semanticLabel: 'InBody 기록 불러오는 중'),
              ),
            )
          else if (inbodies.isEmpty)
            TrainerEmptyCard(
              icon: AppIcons.inbody,
              message: 'InBody 기록이 없습니다.',
              actionLabel: '첫 기록 입력',
              onAction: onAddInbody,
              vertical: 32,
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                0,
              ),
            )
          else
            for (var i = 0; i < inbodies.length; i++)
              AppEntrance.slide(
                delay: Duration(milliseconds: 80 * i.clamp(0, 6)),
                child: _InbodyRow(
                  item: inbodies[i],
                  onTap: () => onOpenInbody(inbodies[i]),
                ),
              ),
        ],
      ],
    );
  }

  /// 종료일까지 남은 날 (D-12, 당일이면 오늘, 지났으면 종료).
  String? _dDayLabel(DateTime? end) {
    if (end == null) return null;
    final now = DateTime.now();
    final days = DateTime(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return '종료';
    if (days == 0) return '오늘';
    return 'D-$days';
  }
}

/// 체성분 3칸 격자 (사이 8): 칸 안쪽 12 14 · 반경 14 · canvasCard,
/// 라벨 12 mute · 값 20/500 + 단위 400 mute (위 2).
class _MetricGrid extends StatelessWidget {
  final List<(String, double?, String)> cells;

  const _MetricGrid({required this.cells});

  @override
  Widget build(BuildContext context) {
    const columns = 3;
    final rows = <Widget>[];
    for (var start = 0; start < cells.length; start += columns) {
      if (start > 0) rows.add(const Gap(AppSpacing.sm));
      rows.add(
        Row(
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const Gap(AppSpacing.sm),
              Expanded(
                child: start + c < cells.length
                    ? _MetricCell(cell: cells[start + c])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _MetricCell extends StatelessWidget {
  final (String, double?, String) cell;

  const _MetricCell({required this.cell});

  @override
  Widget build(BuildContext context) {
    final (label, value, unit) = cell;
    final valueText = value == null
        ? '-'
        : label == 'BMI'
        ? value.toStringAsFixed(1)
        : _formatProfileValue(value);
    return Semantics(
      label: '$label ${value == null ? '정보 없음' : '$valueText$unit'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.captionSmall.natural),
            const Gap(2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: valueText),
                  if (value != null && unit.isNotEmpty)
                    TextSpan(
                      text: unit,
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: AppColors.mute,
                      ),
                    ),
                ],
              ),
              style: AppTextStyles.title.natural,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 52 높이 키/값 줄 (시안 Tr-Member-Profile): 키 16 body, 값 16/500.
class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool divider;

  const _KeyValueRow({
    required this.label,
    required this.value,
    this.divider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.input.copyWith(color: AppColors.body),
            ),
          ),
          Text(value, style: AppTextStyles.input.medium),
        ],
      ),
    );
  }
}

/// 인바디 한 줄 (시안 Tr-Member-Profile): 68 높이, 60 폭 날짜 칸, 체중 16/500 + 'kg' mute,
/// 보조 13 mute(위 2), 오른쪽 20 화살표(chevron).
class _InbodyRow extends StatelessWidget {
  final Inbody item;
  final VoidCallback onTap;

  const _InbodyRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (item.muscleMass != null)
        '골격근 ${_formatProfileValue(item.muscleMass!)}',
      if (item.bodyFatPercent != null)
        '체지방률 ${item.bodyFatPercent!.toStringAsFixed(1)}%',
      if (item.bodyFatPercent == null && item.bodyFat != null)
        '체지방 ${_formatProfileValue(item.bodyFat!)}kg',
    ].join(' · ');
    return Semantics(
      button: true,
      label:
          '${item.measurementDate} 체중 ${_formatProfileValue(item.weight)}kg'
          '${meta.isEmpty ? '' : ', $meta'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          height: 68,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              TrainerDateBlock(date: item.measurementDate),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: _formatProfileValue(item.weight)),
                          TextSpan(
                            text: 'kg',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
                      ),
                      style: AppTextStyles.listTitle.natural,
                    ),
                    if (meta.isNotEmpty) ...[
                      const Gap(2),
                      Text(
                        meta,
                        style: AppTextStyles.bodySm.natural,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                AppIcons.chevronRightBold,
                size: AppSize.icon,
                color: AppColors.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatProfileValue(num value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}
