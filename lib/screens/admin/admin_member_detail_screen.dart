import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_info.dart';
import '../../models/pt_info_log.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_highlight.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_profile_card.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_text_field.dart';

/// 날짜 한 개: 올해면 '9월 1일', 아니면 '2025.9.1'
String _day(DateTime d) => d.year == DateTime.now().year
    ? DateFormat('M월 d일').format(d)
    : DateFormat('yyyy.M.d').format(d);

/// 회원 상세 (기준 시안 AdminMemberDetail): 뒤로 → 26 이름 · 14 '가입 · 이메일' →
/// 'PT' 회색 카드(총 횟수 · 남은 횟수 조절 68, 기간 56, 담당 트레이너 56 ›) → 13 안내 →
/// '변경 기록' 52 줄 → 아래 고정 주황 '저장'.
/// 고친 값은 '저장'을 눌러야 반영된다 (담당 트레이너 포함).
class AdminMemberDetailScreen extends StatefulWidget {
  final AppUser member;

  const AdminMemberDetailScreen({super.key, required this.member});

  @override
  State<AdminMemberDetailScreen> createState() =>
      _AdminMemberDetailScreenState();
}

class _AdminMemberDetailScreenState extends State<AdminMemberDetailScreen> {
  /// 조절 최대값. 저장된 값이 더 크면 그 값까지 허용한다.
  static const _maxSessions = 999;

  late AppUser _member;
  PtInfo? _ptInfo;
  List<PtInfoLog> _ptInfoLogs = [];
  List<AppUser> _trainers = [];
  bool _isLoading = false;
  bool _loadedOnce = false;
  bool _isSaving = false;
  String? _errorMessage;

  // ── 고치는 중인 값 ──
  int _total = 0;
  int _remaining = 0;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _renewalDate;
  AppUser? _pickedTrainer;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _noteController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final admin = context.read<UserProvider>().user;
    if (admin == null) return;
    // 처음에만 화면 전체를 로딩으로 바꾼다 (당겨서 새로고침·돌아와서 다시 불러올 때는 보이던 내용을 그대로 둔다).
    if (!_loadedOnce) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirestoreService.getPtInfo(_member.uid, centerId: _member.centerId),
        FirestoreService.getTrainersByCenter(admin.centerId),
        FirestoreService.getPtInfoLogs(
          centerId: _member.centerId,
          memberId: _member.uid,
          limit: 5,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _ptInfo = results[0] as PtInfo?;
        _trainers = results[1] as List<AppUser>;
        _ptInfoLogs = results[2] as List<PtInfoLog>;
        _errorMessage = null;
        _loadedOnce = true;
        _resetDraft();
      });
    } catch (e) {
      if (!mounted) return;
      if (_loadedOnce) {
        // 이미 보이는 내용은 두고 알리기만 한다
        AppFeedback.showErrorSnackBar(context, e);
      } else {
        setState(() => _errorMessage = AppFeedback.errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetDraft() {
    final pt = _ptInfo;
    _total = pt?.totalSessions ?? 0;
    _remaining = pt?.remainingSessions ?? 0;
    _startDate = pt?.startDate;
    _endDate = pt?.endDate;
    _renewalDate = pt?.renewalDate;
    _pickedTrainer = null;
    _noteController.clear();
  }

  // ── 바뀐 것 ──

  bool get _ptChanged {
    final pt = _ptInfo;
    if (pt == null) {
      return _total > 0 ||
          _startDate != null ||
          _endDate != null ||
          _renewalDate != null;
    }
    return _total != pt.totalSessions ||
        _remaining != pt.remainingSessions ||
        !_sameDay(_startDate, pt.startDate) ||
        !_sameDay(_endDate, pt.endDate) ||
        !_sameDay(_renewalDate, pt.renewalDate);
  }

  bool get _trainerChanged =>
      _pickedTrainer != null && _pickedTrainer!.uid != _member.trainerId;

  bool get _dirty => _ptChanged || _trainerChanged;

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a == null || b == null ? a == b : DateUtils.isSameDay(a, b);

  /// 저장을 막는 문제 (없으면 null). 카드 아래 안내 줄에 주황으로 보인다.
  String? get _problem {
    if (!_ptChanged) return null;
    if (_total < 1) return '총 횟수를 1회 이상으로 정해주세요';
    if (_remaining > _total) return '남은 횟수는 총 횟수보다 많을 수 없어요';
    final s = _startDate;
    final e = _endDate;
    if (s != null && e != null && e.isBefore(s)) {
      return '종료일이 시작일보다 앞설 수 없어요';
    }
    return null;
  }

  /// 이미 있는 PT를 바꾸면 변경 사유가 있어야 저장할 수 있다 (사유 칸은 안내 아래에 바로 보인다).
  bool get _noteMissing =>
      _ptInfo != null && _ptChanged && _noteController.text.trim().isEmpty;

  bool get _canSave => _dirty && _problem == null && !_noteMissing;

  /// 카드 아래 13 안내 (시안 '10회 추가 등록 · 남은 횟수도 함께 늘어나요')
  String? get _hint {
    final pt = _ptInfo;
    if (pt == null) {
      return _total == 0 ? '총 횟수를 정하고 저장하면 PT가 등록돼요' : '$_total회 등록';
    }
    final totalDiff = _total - pt.totalSessions;
    final remainingDiff = _remaining - pt.remainingSessions;
    if (totalDiff > 0) {
      return remainingDiff == totalDiff
          ? '$totalDiff회 추가 등록 · 남은 횟수도 함께 늘어나요'
          : '$totalDiff회 추가 등록 · 남은 ${pt.remainingSessions} → $_remaining회';
    }
    if (totalDiff < 0) {
      return remainingDiff == totalDiff
          ? '${-totalDiff}회 줄임 · 남은 횟수도 함께 줄어요'
          : '${-totalDiff}회 줄임 · 남은 ${pt.remainingSessions} → $_remaining회';
    }
    if (remainingDiff != 0) {
      return '남은 횟수 ${pt.remainingSessions} → $_remaining회';
    }
    return null;
  }

  // ── 고치기 ──

  void _changeTotal(int v) {
    setState(() {
      // 총 횟수를 늘리고 줄인 만큼 남은 횟수도 함께 움직인다 (0 ~ 총 횟수)
      _remaining = (_remaining + (v - _total)).clamp(0, v);
      _total = v;
    });
  }

  Future<void> _pickPeriod() async {
    final result = await showAppBottomSheet<_Period>(
      context: context,
      child: _PeriodSheet(initial: _Period(_startDate, _endDate, _renewalDate)),
    );
    if (result == null || !mounted) return;
    setState(() {
      _startDate = result.start;
      _endDate = result.end;
      _renewalDate = result.renewal;
    });
  }

  Future<void> _pickTrainer() async {
    final currentId = _pickedTrainer?.uid ?? _member.trainerId;
    final trainer = await showAppBottomSheet<AppUser>(
      context: context,
      child: _TrainerPickerSheet(
        trainers: _trainers,
        currentTrainerId: currentId,
      ),
    );
    if (trainer == null || !mounted) return;
    setState(() => _pickedTrainer = trainer);
  }

  Future<void> _save() async {
    if (_isSaving || !_canSave) return;
    final admin = context.read<UserProvider>().user;
    setState(() => _isSaving = true);
    try {
      // 1) 담당 트레이너 (회원·남은 예약·PT권의 담당을 함께 바꾼다)
      if (_trainerChanged) {
        final trainer = _pickedTrainer!;
        await FirestoreService.assignTrainer(
          centerId: _member.centerId,
          memberId: _member.uid,
          trainerId: trainer.uid,
          trainerName: trainer.name,
          changedById: admin?.uid ?? '',
          changedByName: admin?.name ?? '',
        );
        if (!mounted) return;
        setState(() {
          _member = _member.copyWith(
            trainerId: trainer.uid,
            trainerName: trainer.name,
          );
          _pickedTrainer = null;
        });
      }
      // 2) PT 정보 (변경 기록과 한 번에)
      if (_ptChanged) {
        final existing = _ptInfo;
        final now = DateTime.now();
        final note = _noteController.text.trim();
        final info = PtInfo(
          // 새 PT권은 회원당 하나: 문서 이름이 회원 ID
          id: existing?.id ?? _member.uid,
          centerId: _member.centerId,
          memberId: _member.uid,
          memberName: _member.name,
          trainerId: _member.trainerId,
          startDate: _startDate,
          endDate: _endDate,
          totalSessions: _total,
          remainingSessions: _remaining,
          renewalDate: _renewalDate,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        await FirestoreService.savePtInfo(
          info,
          changedById: admin?.uid,
          changedByName: admin?.name,
          note: note.isEmpty ? null : note,
          previousInfo: existing,
        );
      }
      if (!mounted) return;
      AppFeedback.showSuccessSnackBar(context, '저장했어요');
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openPtInfoLogs() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _PtInfoLogScreen(member: _member)),
    );
  }

  Future<void> _leave() async {
    if (_dirty && !_isSaving) {
      final discard = await showAppConfirmDialog(
        context,
        title: '저장하지 않고 나갈까요?',
        message: '고친 내용이 사라져요.',
        confirmLabel: '나가기',
      );
      if (discard != true || !mounted) return;
    }
    Navigator.of(context).pop(_member);
  }

  @override
  Widget build(BuildContext context) {
    final m = _member;
    final joined = DateFormat('yyyy년 M월').format(m.createdAt);

    return PopScope(
      canPop: !_dirty || _isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppScreenHeader.large(title: '', onBack: _leave),
              Expanded(
                child: _isLoading
                    ? const AppLoadingView()
                    : _errorMessage != null
                    ? ListView(
                        children: [
                          AppErrorCard(message: _errorMessage!, onRetry: _load),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenH,
                            ),
                            child: AppProfileCard(
                              name: m.name,
                              subtitle: '$joined 가입 · ${m.email}',
                              bold: true,
                            ),
                          ),
                          const AppMonthHeader(
                            label: 'PT',
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.screenH,
                              AppSpacing.xl,
                              AppSpacing.screenH,
                              AppSpacing.sm,
                            ),
                          ),
                          _ptCard(),
                          _hintLine(),
                          if (_ptInfo != null && _ptChanged)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.screenH,
                                AppSpacing.base,
                                AppSpacing.screenH,
                                0,
                              ),
                              child: AppTextField(
                                label: '변경 사유',
                                labelHint: '(필수)',
                                hint: '예: 추가 결제, 횟수 보정',
                                controller: _noteController,
                                maxLength: 200,
                                textInputAction: TextInputAction.done,
                              ),
                            ),
                          AppMonthHeader(
                            label: '변경 기록',
                            actionLabel: _ptInfoLogs.isEmpty ? null : '전체 보기',
                            onAction: _openPtInfoLogs,
                          ),
                          if (_ptInfoLogs.isEmpty)
                            const AppEmptyLine('변경 기록이 없습니다.')
                          else
                            for (final log in _ptInfoLogs) _LogLine(log: log),
                        ],
                      ),
              ),
              if (!_isLoading && _errorMessage == null)
                AppBottomActionBar(
                  primaryLabel: '저장',
                  bold: true,
                  loading: _isSaving,
                  onPrimary: _canSave ? _save : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 회색 카드: 총 횟수 · 남은 횟수 (68) · 기간 · 담당 트레이너 (56), 사이 선은 line.
  Widget _ptCard() {
    final trainerName = _pickedTrainer?.name ?? _member.trainerName;
    final hasTrainer = (trainerName ?? '').isNotEmpty;
    final s = _startDate;
    final e = _endDate;
    final Widget period = s == null && e == null
        ? Text(
            '선택',
            style: AppTextStyles.input.copyWith(color: AppColors.faint),
          )
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(text: s == null ? '시작 미정' : _day(s)),
                TextSpan(
                  text: ' ~ ',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: AppColors.mute,
                  ),
                ),
                TextSpan(text: e == null ? '종료 미정' : _day(e)),
              ],
            ),
            style: AppTextStyles.input.bold,
          );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _CardRow(
            label: '총 횟수',
            height: 68,
            divider: true,
            right: AppStepper(
              value: _total,
              max: _total > _maxSessions ? _total : _maxSessions,
              min: 0,
              unit: '회',
              semanticLabel: '총 횟수',
              compact: true,
              bold: true,
              onChanged: _changeTotal,
            ),
          ),
          _CardRow(
            label: '남은 횟수',
            height: 68,
            divider: true,
            right: AppStepper(
              value: _remaining,
              max: _total,
              unit: '회',
              semanticLabel: '남은 횟수',
              compact: true,
              bold: true,
              onChanged: (v) => setState(() => _remaining = v),
            ),
          ),
          _CardRow(
            label: '기간',
            divider: true,
            onTap: _pickPeriod,
            semanticValue: s == null && e == null
                ? '선택 안 됨'
                : '${s == null ? '시작 미정' : _day(s)}부터 ${e == null ? '종료 미정' : _day(e)}까지',
            right: period,
          ),
          _CardRow(
            label: '담당 트레이너',
            onTap: _pickTrainer,
            semanticValue: hasTrainer ? trainerName! : '없음',
            right: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasTrainer ? trainerName! : '없음',
                  style: hasTrainer
                      ? AppTextStyles.input.bold
                      : AppTextStyles.input.copyWith(color: AppColors.faint),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  AppIcons.chevronRightBold,
                  size: 16,
                  color: AppColors.chevron,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 카드 아래 13 안내 (위 10). 저장을 막는 문제가 있으면 noticeText 500으로 흔들린다.
  Widget _hintLine() {
    final problem = _problem;
    final text = problem ?? _hint;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        10,
        AppSpacing.screenH,
        0,
      ),
      child: Semantics(
        liveRegion: problem != null,
        child: AppShake(
          trigger: problem,
          child: Text(
            text,
            style: problem == null
                ? AppTextStyles.bodySm
                : AppTextStyles.bodySm.medium.copyWith(
                    color: AppColors.noticeText,
                  ),
          ),
        ),
      ),
    );
  }
}

/// 회색 카드 안 한 줄: 왼쪽 16 라벨 + 오른쪽 내용. 누를 수 있으면 오른쪽 여백 14, 아니면 12.
class _CardRow extends StatelessWidget {
  final String label;
  final Widget right;
  final double height;
  final bool divider;
  final VoidCallback? onTap;
  final String? semanticValue;

  const _CardRow({
    required this.label,
    required this.right,
    this.height = 56,
    this.divider = false,
    this.onTap,
    this.semanticValue,
  });

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: BoxConstraints(minHeight: height),
      padding: EdgeInsets.only(left: 18, right: onTap == null ? 12 : 14),
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(
              excluding: onTap != null,
              child: Text(label, style: AppTextStyles.input),
            ),
          ),
          right,
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$label ${semanticValue ?? ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasMid,
        splashFactory: NoSplash.splashFactory,
        child: row,
      ),
    );
  }
}

// ── 변경 기록 ─────────────────────────────────────────────────────────────────

/// 변경 기록 한 줄의 글: 'PT 완료 8 → 7회', '20회 등록', '총 20 → 30회 · 남은 7 → 17회'
String _logTitle(PtInfoLog log) {
  switch (log.type) {
    case PtInfoLogType.created:
      return '${log.nextTotalSessions}회 등록';
    case PtInfoLogType.sessionCompleted:
      return 'PT 완료 ${log.previousRemainingSessions} → ${log.nextRemainingSessions}회';
    case PtInfoLogType.sessionReopened:
      return '완료 취소 ${log.previousRemainingSessions} → ${log.nextRemainingSessions}회';
    case PtInfoLogType.trainerChanged:
      // note에 '이전 → 새 트레이너' 이름이 있다
      return '담당 ${log.note?.trim().isNotEmpty == true ? log.note!.trim() : '변경'}';
    case PtInfoLogType.updated:
      final parts = [
        if (log.totalDiff != 0)
          '총 ${log.previousTotalSessions} → ${log.nextTotalSessions}회',
        if (log.remainingDiff != 0)
          '남은 ${log.previousRemainingSessions} → ${log.nextRemainingSessions}회',
      ];
      return parts.isEmpty ? 'PT 정보 수정' : parts.join(' · ');
  }
}

String _logActor(PtInfoLog log) => log.changedByName?.trim().isNotEmpty == true
    ? log.changedByName!.trim()
    : '시스템';

/// 기준 시안 AdminMemberDetail '변경 기록': 52 · 15 글 + ' · 처리한 사람'(mute) · 오른쪽 14 mute 날짜.
class _LogLine extends StatelessWidget {
  final PtInfoLog log;

  const _LogLine({required this.log});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: _logTitle(log)),
                    TextSpan(
                      text: ' · ${_logActor(log)}',
                      style: TextStyle(color: AppColors.mute),
                    ),
                  ],
                ),
                style: AppTextStyles.bodyMd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(_day(log.createdAt), style: AppTextStyles.fieldLabel),
          ],
        ),
      ),
    );
  }
}

// ── 기간 시트 ─────────────────────────────────────────────────────────────────

class _Period {
  final DateTime? start;
  final DateTime? end;
  final DateTime? renewal;

  const _Period(this.start, this.end, this.renewal);
}

/// 기간 고르기 (시안 Ad-PtInfoSheet 날짜 묶음): 회색 묶음(시작일 · 종료일 · 갱신일) → '확인'.
class _PeriodSheet extends StatefulWidget {
  final _Period initial;

  const _PeriodSheet({required this.initial});

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late DateTime? _start = widget.initial.start;
  late DateTime? _end = widget.initial.end;
  late DateTime? _renewal = widget.initial.renewal;

  bool get _invalid =>
      _start != null && _end != null && _end!.isBefore(_start!);

  Future<void> _pick(
    DateTime? current,
    String label,
    void Function(DateTime) onPicked,
  ) async {
    // 범위는 오늘 기준 ±10년 (저장된 날짜가 범위 밖이어도 열리도록 그 날짜를 포함한다).
    final now = DateTime.now();
    final initial = current ?? now;
    final first = DateTime(now.year - 10);
    final last = DateTime(now.year + 10, 12, 31);
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: initial.isAfter(last) ? initial : last,
      title: label,
    );
    if (picked != null && mounted) setState(() => onPicked(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppBottomSheetHeader(title: '기간'),
        Container(
          decoration: BoxDecoration(
            color: AppColors.canvasCard,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _DateRow(
                label: '시작일',
                value: _start,
                divider: true,
                onTap: () => _pick(_start, '시작일', (d) => _start = d),
              ),
              _DateRow(
                label: '종료일',
                value: _end,
                divider: true,
                onTap: () => _pick(_end, '종료일', (d) => _end = d),
              ),
              _DateRow(
                label: '갱신일',
                value: _renewal,
                onTap: () => _pick(_renewal, '갱신일', (d) => _renewal = d),
              ),
            ],
          ),
        ),
        if (_invalid) ...[
          const SizedBox(height: 10),
          AppShake(
            trigger: _end,
            child: const AppInlineNotice('종료일이 시작일보다 앞설 수 없어요'),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: '확인',
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: _invalid
              ? null
              : () =>
                    Navigator.of(context).pop(_Period(_start, _end, _renewal)),
        ),
      ],
    );
  }
}

/// 회색 묶음 안 날짜 줄 (시안 Ad-PtInfoSheet-Edit): 52 · 라벨 15 mute(폭 64) · 10 ·
/// 값 16/500(없으면 '선택' faint) · 달력 아이콘 20 mute. 사이 선은 line.
class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool divider;
  final VoidCallback onTap;

  const _DateRow({
    required this.label,
    required this.value,
    this.divider = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Semantics(
      button: true,
      label: '$label ${v == null ? '선택 안 됨' : _day(v)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasMid,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          height: 52,
          padding: const EdgeInsets.only(left: AppSpacing.base, right: 14),
          decoration: divider
              ? BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                )
              : null,
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  label,
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.mute),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  v == null ? '선택' : _day(v),
                  style: v == null
                      ? AppTextStyles.input.copyWith(color: AppColors.faint)
                      : AppTextStyles.input.medium,
                ),
              ),
              Icon(
                AppIcons.calendar,
                size: AppSize.icon,
                color: AppColors.mute,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 트레이너 선택 시트 ────────────────────────────────────────────────────────

/// 트레이너 선택 (시안 Ad-TrainerPicker): 제목 22/500 + ' 4명' 400 mute → (8) 56 줄
/// (이름 16, 고른 사람은 500 + 22 Bold 체크). 고르면 그 트레이너를 돌려준다.
class _TrainerPickerSheet extends StatelessWidget {
  final List<AppUser> trainers;
  final String? currentTrainerId;

  const _TrainerPickerSheet({required this.trainers, this.currentTrainerId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(
          title: '트레이너 선택',
          gap: AppSpacing.sm,
          trailingTitle: trainers.isEmpty
              ? null
              : Text(
                  '${trainers.length}명',
                  style: AppTextStyles.sheetTitle.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.mute,
                  ),
                ),
        ),
        if (trainers.isEmpty)
          const AppEmptyLine('등록된 트레이너가 없습니다.', inset: false)
        else
          for (int i = 0; i < trainers.length; i++)
            _TrainerOption(
              trainer: trainers[i],
              selected: trainers[i].uid == currentTrainerId,
              divider: i < trainers.length - 1,
              onTap: () => Navigator.of(context).pop(trainers[i]),
            ),
      ],
    );
  }
}

class _TrainerOption extends StatelessWidget {
  final AppUser trainer;
  final bool selected;
  final bool divider;
  final VoidCallback onTap;

  const _TrainerOption({
    required this.trainer,
    required this.selected,
    required this.divider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          height: 56,
          decoration: divider
              ? BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.hairline)),
                )
              : null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  trainer.name,
                  style: selected
                      ? AppTextStyles.input.medium
                      : AppTextStyles.input,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                Icon(AppIcons.checkBold, size: 22, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PT 변경 이력 (전체) ───────────────────────────────────────────────────────

/// PT 변경 이력 (시안 Ad-PtInfoLog): 큰 제목 + 회원 이름 → '변경 이력 12건' →
/// 왼쪽 날짜 칸(52) + 15/500 종류 · 13 '잔여 -1 · 이트레이너' · 13 body 사유.
class _PtInfoLogScreen extends StatefulWidget {
  final AppUser member;

  const _PtInfoLogScreen({required this.member});

  @override
  State<_PtInfoLogScreen> createState() => _PtInfoLogScreenState();
}

class _PtInfoLogScreenState extends State<_PtInfoLogScreen> {
  /// 한 번에 불러오는 최대 건수
  static const _limit = 100;

  List<PtInfoLog> _logs = [];
  bool _isLoading = false;
  bool _loadedOnce = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 처음에만 화면 전체를 로딩으로 바꾼다 (당겨서 새로고침·돌아와서 다시 불러올 때는 보이던 내용을 그대로 둔다).
    if (!_loadedOnce) setState(() => _isLoading = true);
    try {
      final logs = await FirestoreService.getPtInfoLogs(
        centerId: widget.member.centerId,
        memberId: widget.member.uid,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _errorMessage = null;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (_loadedOnce) {
        // 이미 보이는 내용은 두고 알리기만 한다
        AppFeedback.showErrorSnackBar(context, e);
      } else {
        setState(() => _errorMessage = AppFeedback.errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _detail(PtInfoLog log) {
    String signed(int v) => v > 0 ? '+$v' : '$v';
    return [
      if (log.totalDiff != 0) '전체 ${signed(log.totalDiff)}',
      if (log.remainingDiff != 0) '잔여 ${signed(log.remainingDiff)}',
      _logActor(log),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.large(
              title: 'PT 변경 이력',
              subtitle: widget.member.name,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: _isLoading
                  ? const AppLoadingView()
                  : _errorMessage != null
                  ? ListView(
                      children: [
                        AppErrorCard(message: _errorMessage!, onRetry: _load),
                      ],
                    )
                  : _logs.isEmpty
                  ? const AppEmptyState(
                      icon: AppIcons.clipboard,
                      message: '변경 이력이 없습니다.',
                      compact: true,
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      children: [
                        AppMonthHeader(
                          label: '변경 이력',
                          // 다 불러오지 못했으면 '최근 100건'
                          count: _logs.length >= _limit
                              ? '최근 $_limit건'
                              : '${_logs.length}건',
                          strongCount: true,
                        ),
                        for (int i = 0; i < _logs.length; i++)
                          // 시안 `slide`: .4s, 0.04초 간격 (화면 밖 줄은 늦게 기다리지 않게 10번째까지만)
                          AppEntrance.slide(
                            delay: Duration(
                              milliseconds: 40 * (i < 10 ? i : 10),
                            ),
                            child: AppListRow(
                              leading: AppDateCell(
                                top: DateFormat(
                                  'MM.dd',
                                ).format(_logs[i].createdAt),
                                bottom: DateFormat(
                                  'HH:mm',
                                ).format(_logs[i].createdAt),
                              ),
                              title: _logs[i].type.label,
                              titleStyle: AppTextStyles.bodyMd.medium,
                              subtitle: _detail(_logs[i]),
                              note: _logs[i].note,
                              height: 0,
                              verticalPadding: 14,
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
}
