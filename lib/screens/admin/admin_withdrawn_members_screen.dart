import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_info_log.dart';
import '../../models/pt_session.dart';
import '../../models/retained_pt_record.dart';
import '../../services/account_service.dart';
import '../../services/firestore_service.dart';
import '../../services/retained_pt_record_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/status_badge.dart';

final _date = DateFormat('yyyy.MM.dd');
final _dateTime = DateFormat('yyyy.MM.dd (E) HH:mm', 'ko');

String _formatDate(DateTime? value) => value == null ? '-' : _date.format(value);

/// 탈퇴 회원 PT 이력 — 환불 등 분쟁 대응용 조회 화면 (읽기 전용).
///
/// 탈퇴 시 이름 등 개인정보는 지워졌으므로 계약 기간·담당 트레이너로 기록을 찾는다.
class AdminWithdrawnMembersScreen extends StatefulWidget {
  const AdminWithdrawnMembersScreen({super.key});

  @override
  State<AdminWithdrawnMembersScreen> createState() => _AdminWithdrawnMembersScreenState();
}

class _AdminWithdrawnMembersScreenState extends State<AdminWithdrawnMembersScreen> {
  List<WithdrawnMemberSummary> _members = [];
  Map<String, String> _trainerNames = {};
  bool _isLoading = false;
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
      // 함께 시작하고, 실패하면 원래 오류를 그대로 받는다 (오류 문구 매핑 유지).
      final membersFuture = RetainedPtRecordService.getWithdrawnMembers(user.centerId);
      final trainersFuture = FirestoreService.getTrainersByCenter(user.centerId);
      await Future.wait([membersFuture, trainersFuture]);
      final members = await membersFuture;
      final trainers = await trainersFuture;
      if (!mounted) return;
      setState(() {
        _members = members;
        _trainerNames = {for (final t in trainers) t.uid: t.name};
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _trainerLabel(Set<String> ids) {
    if (ids.isEmpty) return '미배정';
    return ids.map((id) => _trainerNames[id] ?? '퇴사한 트레이너').join(', ');
  }

  void _openDetail(WithdrawnMemberSummary member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminWithdrawnMemberDetailScreen(
          member: member,
          trainerNames: _trainerNames,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, 0,
              ),
              child: AppScreenHeader(
                title: '탈퇴 회원 PT 이력',
                subtitle: _members.isNotEmpty ? '${_members.length}명' : null,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _members.isEmpty,
                onRefresh: _load,
                empty: const Column(
                  children: [
                    _RetentionNotice(),
                    Gap(AppSpacing.lg),
                    AppEmptyState(
                      icon: Icons.inventory_2_outlined,
                      message: '보관 중인 탈퇴 회원 PT 이력이 없습니다.',
                    ),
                  ],
                ),
                children: [
                  const _RetentionNotice(),
                  const Gap(AppSpacing.md),
                  for (final member in _members) ...[
                    _WithdrawnMemberCard(
                      member: member,
                      trainerLabel: _trainerLabel(member.trainerIds),
                      onTap: () => _openDetail(member),
                    ),
                    const Gap(AppSpacing.sm),
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

class _RetentionNotice extends StatelessWidget {
  const _RetentionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textSecondary),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Text(
              '탈퇴한 회원의 이름 등 개인정보는 삭제되었습니다. 계약 기간과 담당 트레이너로 기록을 찾아주세요. '
              'PT 종료일(또는 탈퇴일) 중 늦은 날로부터 ${AccountService.ptRecordRetentionYears}년이 지나면 자동으로 파기됩니다.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawnMemberCard extends StatelessWidget {
  final WithdrawnMemberSummary member;
  final String trainerLabel;
  final VoidCallback onTap;

  const _WithdrawnMemberCard({
    required this.member,
    required this.trainerLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contract = member.latestContract;
    final extra = member.contracts.length > 1 ? ' 외 ${member.contracts.length - 1}건' : '';
    return AppCard(
      onTap: onTap,
      hasShadow: true,
      hasBorder: false,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_formatDate(member.withdrawnAt)} 탈퇴',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            ],
          ),
          const Gap(AppSpacing.sm),
          _InfoLine(
            label: '계약 기간',
            value: '${_formatDate(contract.startDate)} ~ ${_formatDate(contract.endDate)}$extra',
          ),
          _InfoLine(
            label: 'PT 횟수',
            value: '${contract.remainingSessions ?? '-'} / ${contract.totalSessions ?? '-'}회 남음',
          ),
          _InfoLine(label: '담당 트레이너', value: trainerLabel),
          _InfoLine(label: '파기 예정', value: _formatDate(member.expireAt)),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 상세: 한 회원의 계약 · 수업 · 횟수 변경 이력
// ─────────────────────────────────────────────────────────────────────────────

class AdminWithdrawnMemberDetailScreen extends StatefulWidget {
  final WithdrawnMemberSummary member;
  final Map<String, String> trainerNames;

  const AdminWithdrawnMemberDetailScreen({
    super.key,
    required this.member,
    required this.trainerNames,
  });

  @override
  State<AdminWithdrawnMemberDetailScreen> createState() =>
      _AdminWithdrawnMemberDetailScreenState();
}

class _AdminWithdrawnMemberDetailScreenState extends State<AdminWithdrawnMemberDetailScreen> {
  List<RetainedPtRecord> _records = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<RetainedPtRecord> _ofKind(RetainedPtRecordKind kind) =>
      _records.where((r) => r.kind == kind).toList();

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
      final records = await RetainedPtRecordService.getMemberRecords(
        centerId: user.centerId,
        memberAlias: widget.member.memberAlias,
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _trainerName(RetainedPtRecord record) =>
      record.trainerName ?? widget.trainerNames[record.trainerId] ?? '퇴사한 트레이너';

  @override
  Widget build(BuildContext context) {
    final contracts = _ofKind(RetainedPtRecordKind.ptInfo);
    final sessions = _ofKind(RetainedPtRecordKind.ptSession);
    final logs = _ofKind(RetainedPtRecordKind.ptInfoLog);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, 0,
              ),
              child: AppScreenHeader(
                title: '${_formatDate(widget.member.withdrawnAt)} 탈퇴 회원',
                subtitle: '${_formatDate(widget.member.expireAt)} 파기 예정',
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _records.isEmpty,
                onRefresh: _load,
                empty: const AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: '보관된 기록이 없습니다. 보관 기간이 지나 파기되었을 수 있습니다.',
                ),
                children: [
                  _Section(
                    title: 'PT 계약',
                    count: contracts.length,
                    children: [
                      for (final c in contracts)
                        _RecordTile(
                          title: '${_formatDate(c.startDate)} ~ ${_formatDate(c.endDate)}',
                          lines: [
                            '${c.remainingSessions ?? '-'} / ${c.totalSessions ?? '-'}회 남음',
                            '담당 ${_trainerName(c)}',
                            if (c.renewalDate != null) '갱신일 ${_formatDate(c.renewalDate)}',
                          ],
                        ),
                    ],
                  ),
                  _Section(
                    title: '수업 기록',
                    count: sessions.length,
                    children: [
                      for (final s in sessions)
                        _RecordTile(
                          title: s.scheduledAt == null ? '-' : _dateTime.format(s.scheduledAt!),
                          lines: [
                            '${s.durationMinutes ?? '-'}분 · ${_trainerName(s)}',
                          ],
                          badge: s.sessionStatus == null
                              ? null
                              : StatusBadge(
                                  label: s.sessionStatus!.label,
                                  color: _statusColor(s.sessionStatus!),
                                ),
                        ),
                    ],
                  ),
                  _Section(
                    title: '횟수 변경 이력',
                    count: logs.length,
                    children: [
                      for (final l in logs)
                        _RecordTile(
                          title: l.logType?.label ?? '변경',
                          lines: [
                            _formatDate(l.createdAt),
                            '잔여 ${l.previousRemainingSessions ?? '-'} → ${l.nextRemainingSessions ?? '-'}회'
                                '${_totalChange(l)}',
                            if (l.changedByName != null) '처리 ${l.changedByName}',
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _totalChange(RetainedPtRecord log) {
    final prev = log.previousTotalSessions;
    final next = log.nextTotalSessions;
    if (prev == null || next == null || prev == next) return '';
    return ' · 총 $prev → $next회';
  }

  static Color _statusColor(PtSessionStatus status) {
    switch (status) {
      case PtSessionStatus.completed:
        return AppColors.workout;
      case PtSessionStatus.scheduled:
        return AppColors.brand;
      case PtSessionStatus.cancelled:
        return AppColors.textTertiary;
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final int count;
  final List<Widget> children;

  const _Section({required this.title, required this.count, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: '$title $count'),
          const Gap(AppSpacing.sm),
          if (children.isEmpty)
            Text(
              '기록 없음',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            )
          else
            AppCard(
              hasShadow: true,
              hasBorder: false,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const Divider(height: 1, thickness: 0.5, color: AppColors.border),
                    children[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final String title;
  final List<String> lines;
  final Widget? badge;

  const _RecordTile({required this.title, required this.lines, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final line in lines) ...[
                  const Gap(2),
                  Text(
                    line,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          if (badge != null) badge!,
        ],
      ),
    );
  }
}
