import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

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
import '../../widgets/app_hero.dart';
import '../../widgets/app_kpi_card.dart';
import '../../widgets/app_profile_card.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/orb_loader.dart';

final _ymd = DateFormat('yyyy.MM.dd');

String _fmt(DateTime? d) => d == null ? '-' : _ymd.format(d);

class AdminMemberDetailScreen extends StatefulWidget {
  final AppUser member;

  const AdminMemberDetailScreen({super.key, required this.member});

  @override
  State<AdminMemberDetailScreen> createState() =>
      _AdminMemberDetailScreenState();
}

class _AdminMemberDetailScreenState extends State<AdminMemberDetailScreen> {
  late AppUser _member;
  PtInfo? _ptInfo;
  List<PtInfoLog> _ptInfoLogs = [];
  List<AppUser> _trainers = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _load();
  }

  Future<void> _load() async {
    final admin = context.read<UserProvider>().user;
    if (admin == null) return;
    setState(() => _isLoading = true);
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

  Future<void> _assignTrainer() async {
    final trainer = await showAppBottomSheet<AppUser>(
      context: context,
      child: _TrainerPickerSheet(
        trainers: _trainers,
        currentTrainerId: _member.trainerId,
      ),
    );
    if (trainer == null) return;

    try {
      await FirestoreService.assignTrainer(
        centerId: _member.centerId,
        memberId: _member.uid,
        trainerId: trainer.uid,
        trainerName: trainer.name,
      );
      if (!mounted) return;
      setState(() {
        _member = _member.copyWith(
          trainerId: trainer.uid,
          trainerName: trainer.name,
        );
      });
      await _load();
      if (!mounted) return;
      AppFeedback.showSuccessSnackBar(context, '${trainer.name} 트레이너를 배정했습니다.');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  Future<void> _editPtInfo() async {
    final admin = context.read<UserProvider>().user;
    final result = await showAppBottomSheet<PtInfo>(
      context: context,
      child: _PtInfoSheet(
        memberId: _member.uid,
        memberName: _member.name,
        centerId: _member.centerId,
        trainerId: _member.trainerId,
        changedById: admin?.uid,
        changedByName: admin?.name,
        existing: _ptInfo,
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    await _load();
  }

  Future<void> _openPtInfoLogs() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _PtInfoLogScreen(member: _member)),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final m = _member;
    final pt = _ptInfo;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: '회원 상세',
              onBack: () => Navigator.of(context).pop(_member),
            ),
            Expanded(
              child: _isLoading
                  ? const AppLoadingView()
                  : _errorMessage != null
                  ? AppErrorCard(message: _errorMessage!, onRetry: _load)
                  : ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
                      children: [
                        // 프로필 머리
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenH,
                            AppSpacing.xl,
                            AppSpacing.screenH,
                            AppSpacing.sm,
                          ),
                          child: AppProfileCard(
                            name: m.name,
                            subtitle: m.email,
                            roleLabel: '회원',
                          ),
                        ),

                        // 기본 정보
                        const AppMonthHeader(label: '기본 정보'),
                        _KeyValueRow(label: '이메일', value: m.email),
                        const AppRowDivider(indent: AppSpacing.screenH),
                        _KeyValueRow(
                          label: '트레이너',
                          value: m.trainerName ?? '미배정',
                          muted: m.trainerName == null,
                          trailing: AppButton(
                            label: m.trainerName != null
                                ? '트레이너 변경'
                                : '트레이너 배정',
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.sm,
                            onPressed: _assignTrainer,
                          ),
                        ),

                        // PT 관리
                        AppMonthHeader(
                          label: 'PT',
                          trailing: AppButton(
                            label: pt != null ? 'PT 정보 수정' : 'PT 정보 등록',
                            variant: AppButtonVariant.ghost,
                            size: AppButtonSize.sm,
                            onPressed: _editPtInfo,
                          ),
                        ),
                        if (pt != null) ...[
                          AppStatStrip(
                            cells: [
                              AppKpiCard(
                                framed: false,
                                label: '잔여',
                                value: '${pt.remainingSessions}',
                                unit: '회',
                              ),
                              AppKpiCard(
                                framed: false,
                                label: '전체',
                                value: '${pt.totalSessions}',
                                unit: '회',
                              ),
                            ],
                          ),
                          _KeyValueRow(label: '시작일', value: _fmt(pt.startDate)),
                          const AppRowDivider(indent: AppSpacing.screenH),
                          _KeyValueRow(label: '종료일', value: _fmt(pt.endDate)),
                          const AppRowDivider(indent: AppSpacing.screenH),
                          _KeyValueRow(
                            label: '갱신일',
                            value: _fmt(pt.renewalDate),
                          ),
                        ] else
                          const _MutedLine('PT 정보가 없습니다.'),

                        // PT 변경 이력
                        AppMonthHeader(
                          label: 'PT 변경 이력',
                          trailing: AppButton(
                            label: '전체 보기',
                            variant: AppButtonVariant.ghost,
                            size: AppButtonSize.sm,
                            onPressed: _openPtInfoLogs,
                          ),
                        ),
                        if (_ptInfoLogs.isEmpty)
                          const _MutedLine('변경 이력이 없습니다.')
                        else
                          for (int i = 0; i < _ptInfoLogs.length; i++) ...[
                            if (i > 0)
                              const AppRowDivider(indent: AppSpacing.screenH),
                            _PtInfoLogRow(log: _ptInfoLogs[i]),
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

// ── _KeyValueRow ──────────────────────────────────────────────────────────────

/// 화면 폭 키/값 줄: 왼쪽 라벨(13, mute) + 값(15) + (선택) 오른쪽 행동. 최소 높이 52.
class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;
  final Widget? trailing;

  const _KeyValueRow({
    required this.label,
    required this.value,
    this.muted = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(label, style: AppTextStyles.bodySm),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.bodyMd.copyWith(
                  color: muted ? AppColors.mute : AppColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _MutedLine extends StatelessWidget {
  final String text;

  const _MutedLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.md,
      ),
      child: Text(text, style: AppTextStyles.bodySm),
    );
  }
}

// ── _TrainerPickerSheet ───────────────────────────────────────────────────────

/// 트레이너 선택 시트: 아바타 + 이름, 현재 담당은 체크 표시. 고르면 그 트레이너를 돌려준다.
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
          subtitle: trainers.isEmpty ? null : '${trainers.length}명',
        ),
        if (trainers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
            child: Text(
              '등록된 트레이너가 없습니다.',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
            ),
          )
        else
          for (int i = 0; i < trainers.length; i++) ...[
            if (i > 0) const AppRowDivider(),
            _TrainerOption(
              trainer: trainers[i],
              selected: trainers[i].uid == currentTrainerId,
              onTap: () => Navigator.of(context).pop(trainers[i]),
            ),
          ],
      ],
    );
  }
}

class _TrainerOption extends StatelessWidget {
  final AppUser trainer;
  final bool selected;
  final VoidCallback onTap;

  const _TrainerOption({
    required this.trainer,
    required this.selected,
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
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  trainer.name,
                  style: AppTextStyles.bodyMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                Icon(AppIcons.check, size: AppSize.icon, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _PtInfoLogRow ─────────────────────────────────────────────────────────────

class _PtInfoLogRow extends StatelessWidget {
  final PtInfoLog log;

  const _PtInfoLogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MM.dd HH:mm').format(log.createdAt);
    final totalDiff = _signed(log.totalDiff);
    final remainingDiff = _signed(log.remainingDiff);
    final actor = log.changedByName?.trim().isNotEmpty == true
        ? log.changedByName!
        : '시스템';
    final detail = [
      if (totalDiff != '0') '전체 $totalDiff',
      if (remainingDiff != '0') '잔여 $remainingDiff',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.type.label, style: AppTextStyles.bodyMd),
                Text(
                  detail.isEmpty ? actor : '$detail · $actor',
                  style: AppTextStyles.bodySm,
                ),
                if (log.note != null && log.note!.trim().isNotEmpty)
                  Text(
                    log.note!,
                    style: AppTextStyles.bodySm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(date, style: AppTextStyles.counter),
        ],
      ),
    );
  }

  String _signed(int value) {
    if (value > 0) return '+$value';
    return value.toString();
  }
}

// ── _PtInfoLogScreen ──────────────────────────────────────────────────────────

class _PtInfoLogScreen extends StatefulWidget {
  final AppUser member;

  const _PtInfoLogScreen({required this.member});

  @override
  State<_PtInfoLogScreen> createState() => _PtInfoLogScreenState();
}

class _PtInfoLogScreenState extends State<_PtInfoLogScreen> {
  List<PtInfoLog> _logs = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final logs = await FirestoreService.getPtInfoLogs(
        centerId: widget.member.centerId,
        memberId: widget.member.uid,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
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
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: 'PT 변경 이력',
              subtitle: widget.member.name,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: _isLoading
                  ? const AppLoadingView()
                  : _errorMessage != null
                  ? AppErrorCard(message: _errorMessage!, onRetry: _load)
                  : _logs.isEmpty
                  ? const AppEmptyState(
                      icon: AppIcons.clipboard,
                      message: '변경 이력이 없습니다.',
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      children: [
                        AppMonthHeader(
                          label: '변경 이력',
                          count: '${_logs.length}',
                        ),
                        for (int i = 0; i < _logs.length; i++) ...[
                          if (i > 0)
                            const AppRowDivider(indent: AppSpacing.screenH),
                          _PtInfoLogRow(log: _logs[i]),
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

// ── _PtInfoSheet ──────────────────────────────────────────────────────────────

class _PtInfoSheet extends StatefulWidget {
  final String memberId;
  final String memberName;
  final String centerId;
  final String? trainerId;
  final String? changedById;
  final String? changedByName;
  final PtInfo? existing;

  const _PtInfoSheet({
    required this.memberId,
    required this.memberName,
    required this.centerId,
    this.trainerId,
    this.changedById,
    this.changedByName,
    this.existing,
  });

  @override
  State<_PtInfoSheet> createState() => _PtInfoSheetState();
}

class _PtInfoSheetState extends State<_PtInfoSheet> {
  final _totalController = TextEditingController();
  final _remainingController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _renewalDate;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _totalController.text = e.totalSessions.toString();
      _remainingController.text = e.remainingSessions.toString();
      _startDate = e.startDate;
      _endDate = e.endDate;
      _renewalDate = e.renewalDate;
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    _remainingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime? current,
    void Function(DateTime) onPicked,
  ) async {
    // 범위는 오늘 기준 ±10년 (저장된 날짜가 범위 밖이어도 열리도록 그 날짜를 포함한다).
    final now = DateTime.now();
    final initial = current ?? now;
    final first = DateTime(now.year - 10);
    final last = DateTime(now.year + 10, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: initial.isAfter(last) ? initial : last,
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final total = int.tryParse(_totalController.text.trim());
    final remaining = int.tryParse(_remainingController.text.trim());
    if (total == null || remaining == null || total < 0 || remaining < 0) {
      AppFeedback.showWarning(context, '전체·잔여 횟수를 0 이상의 숫자로 입력해주세요.');
      return;
    }
    if (remaining > total) {
      AppFeedback.showWarning(context, '잔여 횟수는 전체 횟수보다 많을 수 없습니다.');
      return;
    }
    final note = _noteController.text.trim();

    if (_isEditing && note.isEmpty) {
      AppFeedback.showErrorSnackBar(context, ArgumentError('수정 사유를 입력해주세요.'));
      return;
    }

    setState(() => _isSaving = true);
    try {
      const uuid = Uuid();
      final id = widget.existing?.id ?? uuid.v4();
      final now = DateTime.now();
      final info = PtInfo(
        id: id,
        centerId: widget.centerId,
        memberId: widget.memberId,
        memberName: widget.memberName,
        trainerId: widget.trainerId,
        startDate: _startDate,
        endDate: _endDate,
        totalSessions: total,
        remainingSessions: remaining,
        renewalDate: _renewalDate,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );
      await FirestoreService.savePtInfo(
        info,
        changedById: widget.changedById,
        changedByName: widget.changedByName,
        note: note.isEmpty ? null : note,
        previousInfo: widget.existing,
      );
      if (!mounted) return;
      Navigator.of(context).pop(info);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(
          title: _isEditing ? 'PT 정보 수정' : 'PT 정보 등록',
          subtitle: widget.memberName,
        ),
        _DateRow(
          label: '시작일',
          value: _startDate,
          onTap: () => _pickDate(
            context,
            _startDate,
            (d) => setState(() => _startDate = d),
          ),
        ),
        const AppRowDivider(),
        _DateRow(
          label: '종료일',
          value: _endDate,
          onTap: () =>
              _pickDate(context, _endDate, (d) => setState(() => _endDate = d)),
        ),
        const AppRowDivider(),
        _DateRow(
          label: '갱신일',
          value: _renewalDate,
          onTap: () => _pickDate(
            context,
            _renewalDate,
            (d) => setState(() => _renewalDate = d),
          ),
        ),
        const AppRowDivider(),
        const SizedBox(height: AppSpacing.base),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: '총 횟수',
                controller: _totalController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                label: '잔여 횟수',
                controller: _remainingController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        AppTextField(
          label: _isEditing ? '수정 사유' : '등록 메모',
          hint: _isEditing ? '예: 추가 결제, 횟수 보정' : '선택 사항',
          controller: _noteController,
          maxLines: 2,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: '취소',
              variant: AppButtonVariant.ghost,
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: '저장',
              onPressed: _isSaving ? null : _save,
              isLoading: _isSaving,
            ),
          ],
        ),
      ],
    );
  }
}

// ── _DateRow ──────────────────────────────────────────────────────────────────

/// 시트 안 날짜 선택 줄 (높이 52): 라벨 + 값(미선택이면 '선택', mute) + 화살표.
class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label ${value == null ? '선택 안 됨' : _fmt(value)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                ),
              ),
              Expanded(
                child: Text(
                  value == null ? '선택' : _fmt(value),
                  style: AppTextStyles.bodyMd.copyWith(
                    color: value == null ? AppColors.body : AppColors.ink,
                  ),
                ),
              ),
              Icon(
                AppIcons.calendar,
                size: AppSize.icon,
                color: AppColors.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
