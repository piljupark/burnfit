import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_info_log.dart';
import '../../models/pt_session.dart';
import '../../models/retained_pt_record.dart';
import '../../services/account_service.dart';
import '../../services/firestore_service.dart';
import '../../services/retained_pt_record_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/status_badge.dart';

final _date = DateFormat('yyyy.MM.dd');
final _dateTime = DateFormat('yyyy.MM.dd (E) HH:mm', 'ko');

String _formatDate(DateTime? value) =>
    value == null ? '-' : _date.format(value);

/// 탈퇴 회원 PT 이력 — 환불 등 분쟁 대응용 조회 화면 (읽기 전용).
///
/// 탈퇴 시 이름 등 개인정보는 지워졌으므로 계약 기간·담당 트레이너로 기록을 찾는다.
class AdminWithdrawnMembersScreen extends StatefulWidget {
  const AdminWithdrawnMembersScreen({super.key});

  @override
  State<AdminWithdrawnMembersScreen> createState() =>
      _AdminWithdrawnMembersScreenState();
}

class _AdminWithdrawnMembersScreenState
    extends State<AdminWithdrawnMembersScreen> {
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
      final membersFuture = RetainedPtRecordService.getWithdrawnMembers(
        user.centerId,
      );
      final trainersFuture = FirestoreService.getTrainersByCenter(
        user.centerId,
      );
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
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: '탈퇴 회원 PT 이력',
              subtitle: _members.isNotEmpty ? '${_members.length}명' : null,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _members.isEmpty,
                onRefresh: _load,
                empty: const Column(
                  children: [
                    _RetentionNotice(),
                    AppEmptyState(
                      icon: AppIcons.archive,
                      message: '보관 중인 탈퇴 회원 PT 이력이 없습니다.',
                    ),
                  ],
                ),
                children: [
                  const SizedBox(height: AppSpacing.base),
                  const _RetentionNotice(),
                  AppMonthHeader(
                    label: '탈퇴 회원',
                    count: '${_members.length}',
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xl,
                      bottom: AppSpacing.sm,
                    ),
                  ),
                  for (int i = 0; i < _members.length; i++) ...[
                    if (i > 0) const AppRowDivider(),
                    _WithdrawnMemberRow(
                      member: _members[i],
                      trainerLabel: _trainerLabel(_members[i].trainerIds),
                      onTap: () => _openDetail(_members[i]),
                    ),
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

/// 보관 안내: 카드 한 덩어리 (정보 아이콘 + 한 문단).
class _RetentionNotice extends StatelessWidget {
  const _RetentionNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.info, size: AppSize.icon, color: AppColors.body),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '탈퇴한 회원의 이름 등 개인정보는 삭제되었습니다. 계약 기간과 담당 트레이너로 기록을 찾아주세요. '
              'PT 종료일(또는 탈퇴일) 중 늦은 날로부터 ${AccountService.ptRecordRetentionYears}년이 지나면 자동으로 파기됩니다.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
            ),
          ),
        ],
      ),
    );
  }
}

/// 탈퇴 회원 한 줄: 탈퇴일 제목 + 키/값 요약 + 화살표 (읽기 전용 상세로 이동).
class _WithdrawnMemberRow extends StatelessWidget {
  final WithdrawnMemberSummary member;
  final String trainerLabel;
  final VoidCallback onTap;

  const _WithdrawnMemberRow({
    required this.member,
    required this.trainerLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contract = member.latestContract;
    final extra = member.contracts.length > 1
        ? ' 외 ${member.contracts.length - 1}건'
        : '';
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatDate(member.withdrawnAt)} 탈퇴',
                      style: AppTextStyles.bodyLg,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _InfoLine(
                      label: '계약 기간',
                      value:
                          '${_formatDate(contract.startDate)} ~ ${_formatDate(contract.endDate)}$extra',
                    ),
                    _InfoLine(
                      label: 'PT 횟수',
                      value:
                          '${contract.remainingSessions ?? '-'} / ${contract.totalSessions ?? '-'}회 남음',
                    ),
                    _InfoLine(label: '담당 트레이너', value: trainerLabel),
                    _InfoLine(
                      label: '파기 예정',
                      value: _formatDate(member.expireAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(AppIcons.forward, size: AppSize.icon, color: AppColors.mute),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 84, child: Text(label, style: AppTextStyles.bodySm)),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
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

class _AdminWithdrawnMemberDetailScreenState
    extends State<AdminWithdrawnMemberDetailScreen> {
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
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: '${_formatDate(widget.member.withdrawnAt)} 탈퇴 회원',
              subtitle: '${_formatDate(widget.member.expireAt)} 파기 예정',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _records.isEmpty,
                onRefresh: _load,
                empty: const AppEmptyState(
                  icon: AppIcons.archive,
                  message: '보관된 기록이 없습니다. 보관 기간이 지나 파기되었을 수 있습니다.',
                ),
                children: [
                  _Section(
                    title: 'PT 계약',
                    count: contracts.length,
                    children: [
                      for (final c in contracts)
                        _RecordTile(
                          title:
                              '${_formatDate(c.startDate)} ~ ${_formatDate(c.endDate)}',
                          lines: [
                            '${c.remainingSessions ?? '-'} / ${c.totalSessions ?? '-'}회 남음',
                            '담당 ${_trainerName(c)}',
                            if (c.renewalDate != null)
                              '갱신일 ${_formatDate(c.renewalDate)}',
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
                          title: s.scheduledAt == null
                              ? '-'
                              : _dateTime.format(s.scheduledAt!),
                          lines: [
                            '${s.durationMinutes ?? '-'}분 · ${_trainerName(s)}',
                          ],
                          badge: s.sessionStatus == null
                              ? null
                              : _statusBadge(s.sessionStatus!),
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
                            if (l.changedByName != null)
                              '처리 ${l.changedByName}',
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

  /// 완료 = 흰 채움, 예정 = 외곽선, 취소 = 흐린 글자 (색이 아니라 모양으로 구분).
  static StatusBadge _statusBadge(PtSessionStatus status) {
    switch (status) {
      case PtSessionStatus.completed:
        return StatusBadge(label: status.label, strong: true);
      case PtSessionStatus.scheduled:
        return StatusBadge(label: status.label);
      case PtSessionStatus.cancelled:
        return StatusBadge(label: status.label, color: AppColors.mute);
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final int count;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppMonthHeader(
          label: title,
          count: '$count',
          padding: const EdgeInsets.only(
            top: AppSpacing.xl,
            bottom: AppSpacing.sm,
          ),
        ),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('기록 없음', style: AppTextStyles.bodySm),
          )
        else
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const AppRowDivider(),
            children[i],
          ],
      ],
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMd),
                for (final line in lines)
                  Text(line, style: AppTextStyles.bodySm),
              ],
            ),
          ),
          if (badge != null) ...[const SizedBox(width: AppSpacing.sm), badge!],
        ],
      ),
    );
  }
}
