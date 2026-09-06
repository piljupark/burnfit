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
import '../../models/pt_info.dart';
import '../../models/pt_info_log.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_button.dart';

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
    final trainer = await showDialog<AppUser>(
      context: context,
      builder: (ctx) => _TrainerPickerDialog(trainers: _trainers),
    );
    if (trainer == null) return;

    try {
      await FirestoreService.assignTrainer(
        _member.uid,
        trainer.uid,
        trainer.name,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${trainer.name} 트레이너를 배정했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  Future<void> _editPtInfo() async {
    final admin = context.read<UserProvider>().user;
    final result = await showDialog<PtInfo>(
      context: context,
      builder: (ctx) => _PtInfoDialog(
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 커스텀 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(_member),
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
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Text(m.name, style: AppTextStyles.h3),
                ],
              ),
            ),
            // 본문
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                      ),
                    )
                  : _errorMessage != null
                  ? AppErrorCard(message: _errorMessage!, onRetry: _load)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        AppSpacing.lg,
                        AppSpacing.screenH,
                        AppSpacing.xl2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 기본 정보 섹션
                          Text('기본 정보', style: AppTextStyles.overline),
                          const Gap(AppSpacing.xs),
                          _InfoSection(
                            children: [
                              _InfoRow(label: '이메일', value: m.email),
                              _InfoRow(
                                label: '트레이너',
                                value: m.trainerName ?? '미배정',
                              ),
                            ],
                          ),
                          const Gap(AppSpacing.md),
                          AppButton(
                            label: m.trainerName != null
                                ? '트레이너 변경'
                                : '트레이너 배정',
                            variant: AppButtonVariant.secondary,
                            onPressed: _assignTrainer,
                            fullWidth: true,
                          ),

                          const Gap(AppSpacing.xl),

                          // PT 관리 섹션
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'PT 관리',
                                  style: AppTextStyles.overline,
                                ),
                              ),
                              AppButton(
                                label: _ptInfo != null ? '수정' : '등록',
                                variant: AppButtonVariant.ghost,
                                onPressed: _editPtInfo,
                              ),
                            ],
                          ),
                          const Gap(AppSpacing.xs),
                          if (_ptInfo != null)
                            _InfoSection(
                              children: [
                                _InfoRow(
                                  label: '시작일',
                                  value: _ptInfo!.startDate != null
                                      ? DateFormat(
                                          'yyyy.MM.dd',
                                        ).format(_ptInfo!.startDate!)
                                      : '-',
                                ),
                                _InfoRow(
                                  label: '종료일',
                                  value: _ptInfo!.endDate != null
                                      ? DateFormat(
                                          'yyyy.MM.dd',
                                        ).format(_ptInfo!.endDate!)
                                      : '-',
                                ),
                                _InfoRow(
                                  label: '잔여',
                                  value:
                                      '${_ptInfo!.remainingSessions} / ${_ptInfo!.totalSessions}회',
                                ),
                                _InfoRow(
                                  label: '갱신일',
                                  value: _ptInfo!.renewalDate != null
                                      ? DateFormat(
                                          'yyyy.MM.dd',
                                        ).format(_ptInfo!.renewalDate!)
                                      : '-',
                                ),
                              ],
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                'PT 정보가 없습니다.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const Gap(AppSpacing.md),
                          _PtInfoLogSection(
                            logs: _ptInfoLogs,
                            onViewAll: _openPtInfoLogs,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _InfoSection ──────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final List<_InfoRow> children;

  const _InfoSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

// ── _InfoRow ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _TrainerPickerDialog ──────────────────────────────────────────────────────

class _TrainerPickerDialog extends StatelessWidget {
  final List<AppUser> trainers;
  const _TrainerPickerDialog({required this.trainers});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text('트레이너 선택', style: AppTextStyles.h3),
      content: SizedBox(
        width: 300,
        child: trainers.isEmpty
            ? Text(
                '등록된 트레이너가 없습니다.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: trainers.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, i) {
                  final t = trainers[i];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      child: Text(
                        t.name,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '취소',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PtInfoLogSection extends StatelessWidget {
  final List<PtInfoLog> logs;
  final VoidCallback onViewAll;

  const _PtInfoLogSection({required this.logs, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('PT 변경 이력', style: AppTextStyles.overline)),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                '전체 보기',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const Gap(AppSpacing.xs),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: logs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    '변경 이력이 없습니다.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < logs.length; i++) ...[
                      _PtInfoLogRow(log: logs[i]),
                      if (i < logs.length - 1)
                        const Divider(height: 1, color: AppColors.border),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

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
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.type.label,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(2),
                Text(
                  detail.isEmpty ? actor : '$detail · $actor',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (log.note != null && log.note!.trim().isNotEmpty) ...[
                  const Gap(2),
                  Text(
                    log.note!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          Text(
            date,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _signed(int value) {
    if (value > 0) return '+$value';
    return value.toString();
  }
}

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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.textPrimary,
                      size: 28,
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PT 변경 이력', style: AppTextStyles.h3),
                        const Gap(2),
                        Text(
                          widget.member.name,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                      ),
                    )
                  : _errorMessage != null
                  ? AppErrorCard(message: _errorMessage!, onRetry: _load)
                  : _logs.isEmpty
                  ? Center(
                      child: Text(
                        '변경 이력이 없습니다.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        AppSpacing.sm,
                        AppSpacing.screenH,
                        AppSpacing.xl,
                      ),
                      itemBuilder: (_, i) => Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: _PtInfoLogRow(log: _logs[i]),
                      ),
                      separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
                      itemCount: _logs.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _PtInfoDialog ─────────────────────────────────────────────────────────────

class _PtInfoDialog extends StatefulWidget {
  final String memberId;
  final String memberName;
  final String centerId;
  final String? trainerId;
  final String? changedById;
  final String? changedByName;
  final PtInfo? existing;

  const _PtInfoDialog({
    required this.memberId,
    required this.memberName,
    required this.centerId,
    this.trainerId,
    this.changedById,
    this.changedByName,
    this.existing,
  });

  @override
  State<_PtInfoDialog> createState() => _PtInfoDialogState();
}

class _PtInfoDialogState extends State<_PtInfoDialog> {
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
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final total = int.tryParse(_totalController.text) ?? 0;
    final remaining = int.tryParse(_remainingController.text) ?? 0;
    final note = _noteController.text.trim();

    if (_isEditing && note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('수정 사유를 입력해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        fetchPreviousInfo: false,
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
    final fmt = DateFormat('yyyy.MM.dd');

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text('PT 정보', style: AppTextStyles.h3),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DateRow(
              label: '시작일',
              value: _startDate != null ? fmt.format(_startDate!) : '선택',
              onTap: () => _pickDate(
                context,
                _startDate,
                (d) => setState(() => _startDate = d),
              ),
            ),
            const Gap(AppSpacing.xs),
            _DateRow(
              label: '종료일',
              value: _endDate != null ? fmt.format(_endDate!) : '선택',
              onTap: () => _pickDate(
                context,
                _endDate,
                (d) => setState(() => _endDate = d),
              ),
            ),
            const Gap(AppSpacing.xs),
            _DateRow(
              label: '갱신일',
              value: _renewalDate != null ? fmt.format(_renewalDate!) : '선택',
              onTap: () => _pickDate(
                context,
                _renewalDate,
                (d) => setState(() => _renewalDate = d),
              ),
            ),
            const Gap(AppSpacing.md),
            TextField(
              controller: _totalController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '총 횟수'),
            ),
            const Gap(AppSpacing.xs),
            TextField(
              controller: _remainingController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '잔여 횟수'),
            ),
            const Gap(AppSpacing.xs),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _isEditing ? '수정 사유' : '등록 메모',
                hintText: _isEditing ? '예: 추가 결제, 횟수 보정' : '선택 사항',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '취소',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  '저장',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── _DateRow ──────────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
