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
import '../../widgets/app_highlight.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_key_value_row.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_profile_card.dart';
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

  /// 인바디는 최근 이 건수까지만 읽는다.
  static const _inbodyLimit = 20;

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

  /// 운동 탭: 처음 읽기를 마쳤는지, 회원이 운동 공유를 켰는지(꺼져 있으면 내 PT 기록만), 읽기 오류.
  bool _workoutsLoaded = false;
  bool _workoutsShared = true;
  String? _workoutsError;

  /// 기록 줄을 빠르게 두 번 눌러 피드백 시트가 두 번 열리지 않게 한다.
  bool _openingFeedback = false;

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
        if (!_workoutsLoaded && !_loadingWorkouts) _loadWorkouts();
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
    if (!mounted || !widget.member.shareSettings.body) return;
    setState(() => _loadingInbodies = true);
    try {
      final list = await FirestoreService.getInbodiesByMember(
        widget.member.uid,
        centerId: widget.member.centerId,
        limit: _inbodyLimit,
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
    if (!mounted || !widget.member.shareSettings.meal) return;
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

  /// PT·개인 운동을 함께 읽는다. 회원이 운동 공유를 껐으면 내가 남긴 PT 기록만 온다.
  Future<void> _loadWorkouts() async {
    if (!mounted) return;
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;
    setState(() {
      _loadingWorkouts = true;
      _workoutsError = null;
    });
    try {
      final result = await WorkoutService.getMemberWorkoutsForTrainer(
        centerId: widget.member.centerId,
        memberId: widget.member.uid,
        trainerId: trainer.uid,
        startDate: _rangeStart,
        endDate: _rangeEnd,
      );
      if (!mounted) return;
      setState(() {
        _workouts = result.workouts;
        _workoutsShared = result.shared;
        _workoutsLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (_workouts.isEmpty) {
        // 빈 목록이면 탭 안에 오류 카드(다시 시도)로 보인다.
        setState(() => _workoutsError = AppFeedback.errorMessage(e));
      } else {
        // 이미 보이는 목록은 두고 토스트로만 알린다.
        AppFeedback.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingWorkouts = false);
      }
    }
  }

  Future<void> _loadCardios() async {
    if (!mounted || !widget.member.shareSettings.workout) return;
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

  /// [targetLinked]: 대상 기록에 이미 피드백이 이어져 있는지 (hasFeedback).
  /// 이어져 있으면 연결값을 덮어쓰지 않고(이전 담당 트레이너 피드백과 함께 남는다),
  /// 아니면 저장할 때 잇는다. 이전 담당자의 피드백은 시트 위에 읽기 전용으로 보인다.
  Future<void> _writeFeedback({
    required fb.FeedbackTargetType type,
    String? targetId,
    String? targetDate,
    bool targetLinked = true,
  }) async {
    if (_openingFeedback) return;
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;

    _openingFeedback = true;
    try {
      fb.Feedback? existing;
      var others = const <fb.Feedback>[];
      try {
        if (targetId != null) {
          final loaded = await FeedbackSheet.loadForTarget(
            targetId: targetId,
            centerId: widget.member.centerId,
            memberId: widget.member.uid,
            trainerId: trainer.uid,
          );
          existing = loaded.mine;
          others = loaded.others;
        }
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
        others: others,
        targetLinked: targetLinked,
      );

      if (result == true && mounted) {
        if (type == fb.FeedbackTargetType.meal) _loadMeals();
        if (type == fb.FeedbackTargetType.workout) _loadWorkouts();
        if (type == fb.FeedbackTargetType.cardio) _loadCardios();
      }
    } finally {
      _openingFeedback = false;
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
    if (saved == true && mounted) await _loadInbodies();
  }

  Future<void> _deleteInbody(Inbody item) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'InBody 기록 삭제',
      message:
          '${inbodyDayLabel(item.measurementDate)} 측정 기록 1건을 삭제합니다. 되돌릴 수 없습니다.',
      confirmLabel: '삭제',
    );
    if (confirmed != true || !mounted) return;

    try {
      await FirestoreService.deleteInbody(item.id);
      if (!mounted) return;
      await _loadInbodies();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  Future<void> _showInbodyDetail(Inbody item) async {
    // 규칙상 자기가 입력한 인바디만 지울 수 있다.
    final myUid = context.read<UserProvider>().user?.uid;
    final deleteRequested = await showTrainerInbodyDetailSheet(
      context,
      item,
      canDelete: myUid != null && item.trainerId == myUid,
    );
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
    final pt = _ptInfo;

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
              child: AppProfileCard(name: m.name, subtitle: meta, bold: true),
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
                    Expanded(
                      // 시안 TrainerMember 주황 카드: 'PT 남은 횟수' · '6회 / 20회' · 쓴 비율 막대
                      child: AppHighlightCard(
                        label: 'PT 남은 횟수',
                        value: pt == null ? '-' : '${pt.remainingSessions}회',
                        unit: pt == null ? null : ' / ${pt.totalSessions}회',
                        progress: pt == null || pt.totalSessions <= 0
                            ? null
                            : ((pt.totalSessions - pt.remainingSessions) /
                                      pt.totalSessions)
                                  .clamp(0.0, 1.0),
                        bold: true,
                        compact: true,
                        semanticLabel: pt == null
                            ? 'PT 남은 횟수 정보 없음'
                            : 'PT 남은 횟수 ${pt.remainingSessions}회, 전체 ${pt.totalSessions}회',
                      ),
                    ),
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
                    loaded: _workoutsLoaded,
                    shared: _workoutsShared,
                    errorMessage: _workoutsError,
                    onFeedback: (w) => _writeFeedback(
                      type: fb.FeedbackTargetType.workout,
                      targetId: w.id,
                      targetDate: w.workoutDate,
                      targetLinked: w.hasFeedback,
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
                      targetLinked: meal.hasFeedback,
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
                      targetLinked: c.hasFeedback,
                    ),
                    onRefresh: _loadCardios,
                  ),
                  _InfoTab(
                    member: m,
                    body: _body,
                    ptInfo: _ptInfo,
                    inbodies: _inbodies,
                    inbodyLimit: _inbodyLimit,
                    loadingInbodies: _loadingInbodies,
                    onOpenInbody: _showInbodyDetail,
                    onAddInbody: m.shareSettings.body ? _openInbodyInput : null,
                  ),
                ],
              ),
            ),
            // ── 아래 고정 2칸 버튼: 인바디 입력(회색) · 피드백 쓰기(검정) ────────
            AppBottomActionBar(
              secondaryLabel: '인바디 입력',
              onSecondary: m.shareSettings.body ? _openInbodyInput : null,
              primaryLabel: '피드백 쓰기',
              onPrimary: () =>
                  _writeFeedback(type: fb.FeedbackTargetType.general),
              primaryVariant: AppButtonVariant.dark,
              bold: true,
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

/// 22/700 카드 값 (시트 제목과 같은 22 크기 토큰).
TextStyle get _cardValueStyle =>
    AppTextStyles.sheetTitle.bold.natural.copyWith(letterSpacing: 22 * -0.019);

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
  final int inbodyLimit;
  final bool loadingInbodies;
  final void Function(Inbody) onOpenInbody;

  /// 인바디가 없을 때 '첫 기록 입력' (신체 정보 공유가 꺼져 있으면 null)
  final VoidCallback? onAddInbody;

  const _InfoTab({
    required this.member,
    required this.body,
    required this.ptInfo,
    required this.inbodies,
    required this.inbodyLimit,
    required this.loadingInbodies,
    required this.onOpenInbody,
    required this.onAddInbody,
  });

  @override
  Widget build(BuildContext context) {
    final ptInfo = this.ptInfo;
    final p = body;
    final shared = member.shareSettings.body;
    final fmt = DateFormat('yyyy.MM.dd');
    // 체중은 머리의 '최근 체중' 카드와 같은 기준: 최근 인바디가 있으면 그 값, 없으면 신체 정보.
    final latestInbody = shared && inbodies.isNotEmpty ? inbodies.first : null;
    final weight = latestInbody?.weight ?? p?.weight;
    final showMetrics = shared && (p != null || latestInbody != null);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
      children: [
        if (!shared)
          const TrainerShareBlockedMessage(
            message: '회원이 신체 정보 공유를 꺼두었습니다.',
            top: 40,
            bottom: AppSpacing.xl2,
          )
        else if (showMetrics) ...[
          const AppMonthHeader(
            label: '체성분',
            strong: true,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.lg,
              AppSpacing.screenH,
              0,
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
                ('키', p?.height, 'cm'),
                ('체중', weight, 'kg'),
                ('골격근', p?.muscleMass, 'kg'),
                ('체지방', p?.bodyFat, 'kg'),
                ('BMI', p?.bmi, ''),
              ],
            ),
          ),
          if (latestInbody != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                0,
              ),
              child: Text(
                '체중은 ${inbodyDayLabel(latestInbody.measurementDate)} InBody 측정값입니다.',
                style: AppTextStyles.bodySm.natural,
              ),
            ),
        ],
        if (ptInfo != null) ...[
          // 남은 횟수는 머리의 주황 카드에 있으므로 여기서는 기간만 줄로 둔다.
          AppMonthHeader(
            strong: true,
            label: 'PT 정보',
            count: _dDayLabel(ptInfo.endDate),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xs,
              AppSpacing.screenH,
              0,
            ),
            child: Column(
              children: [
                AppKeyValueRow(
                  label: '남은 횟수',
                  value:
                      '${ptInfo.remainingSessions} / ${ptInfo.totalSessions}회',
                  divider: true,
                ),
                AppKeyValueRow(
                  label: '시작일',
                  value: ptInfo.startDate != null
                      ? fmt.format(ptInfo.startDate!)
                      : '-',
                  divider: true,
                ),
                AppKeyValueRow(
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
          if (showMetrics || ptInfo != null) const AppSectionBand(top: 12),
          AppMonthHeader(
            label: '인바디',
            // 최대 [inbodyLimit]건만 읽으므로 꽉 찼으면 전체 건수가 아님을 밝힌다.
            count: inbodies.length >= inbodyLimit
                ? '최근 $inbodyLimit건'
                : '${inbodies.length}건',
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
            TrainerEmptyState(
              icon: AppIcons.inbody,
              message: 'InBody 기록이 없습니다.',
              actionLabel: '첫 기록 입력',
              onAction: onAddInbody,
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
          '${inbodyDayLabel(item.measurementDate)} 체중 ${_formatProfileValue(item.weight)}kg'
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
