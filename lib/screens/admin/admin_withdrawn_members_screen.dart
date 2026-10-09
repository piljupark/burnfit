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
import '../../widgets/app_hero.dart';
import '../../widgets/app_highlight.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';

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
  bool _loadedOnce = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    // 처음에만 화면 전체를 로딩으로 바꾼다 (당겨서 새로고침·돌아와서 다시 불러올 때는 보이던 내용을 그대로 둔다).
    if (!_loadedOnce) setState(() => _isLoading = true);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 계약마다 남겨 둔 담당 이름을 먼저 쓰고, 없으면 지금 트레이너 목록에서 찾는다.
  String _trainerLabel(WithdrawnMemberSummary member) {
    final names = <String>{};
    for (final c in member.contracts) {
      final id = c.trainerId;
      if (id == null) continue;
      names.add(c.trainerName ?? _trainerNames[id] ?? '퇴사한 트레이너');
    }
    return names.isEmpty ? '미배정' : names.join(', ');
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
            AppScreenHeader.large(
              title: '탈퇴 회원 PT 이력',
              count: _members.isEmpty ? null : '${_members.length}',
              onBack: () => Navigator.of(context).pop(),
            ),
            // 시안 Ad-Withdrawn: 제목 아래 16 회색 안내 상자
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.base,
                AppSpacing.screenH,
                0,
              ),
              child: AppInlineNotice(
                '탈퇴한 회원의 이름 등 개인정보는 삭제되었습니다. 계약 기간과 담당 트레이너로 기록을 찾아주세요. '
                'PT 종료일(또는 탈퇴일) 중 늦은 날로부터 ${AccountService.ptRecordRetentionYears}년이 지나면 자동으로 파기됩니다.',
                warning: false,
                neutral: true,
              ),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _members.isEmpty,
                onRefresh: _load,
                padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
                // 시안 Ad-Withdrawn-Empty: 안내 상자 아래 110 (본문 위 24 + 86)
                empty: const AppEmptyState(
                  icon: AppIcons.archive,
                  message: '보관 중인 탈퇴 회원 PT 이력이 없습니다.',
                  compact: true,
                  top: 86,
                ),
                children: [
                  AppMonthHeader(
                    label: '탈퇴 회원',
                    count: '${_members.length}명',
                    strongCount: true,
                  ),
                  for (int i = 0; i < _members.length; i++)
                    // 시안 `fade`: 아래 8에서 .4s, 0.05초 간격
                    AppEntrance(
                      offset: const Offset(0, 8),
                      duration: const Duration(milliseconds: 400),
                      delay: Duration(milliseconds: 50 * (i < 10 ? i : 10)),
                      child: _WithdrawnMemberRow(
                        member: _members[i],
                        trainerLabel: _trainerLabel(_members[i]),
                        onTap: () => _openDetail(_members[i]),
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

/// 탈퇴 회원 한 줄 (시안 Ad-Withdrawn): 위아래 16 · 아래 hairline, '2026.08.14 탈퇴' 16/500 ·
/// (8) 키/값 13 (라벨 84 mute · 값 body, 줄 사이 3) · 18 Bold 화살표.
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatDate(member.withdrawnAt)} 탈퇴',
                        style: AppTextStyles.listTitle,
                      ),
                      const SizedBox(height: AppSpacing.sm),
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
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(
                  AppIcons.chevronRightBold,
                  size: 18,
                  color: AppColors.chevron,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const _InfoLine({
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 3),
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
  bool _loadedOnce = false;
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
    // 처음에만 화면 전체를 로딩으로 바꾼다 (당겨서 새로고침·돌아와서 다시 불러올 때는 보이던 내용을 그대로 둔다).
    if (!_loadedOnce) setState(() => _isLoading = true);
    try {
      final records = await RetainedPtRecordService.getMemberRecords(
        centerId: user.centerId,
        memberAlias: widget.member.memberAlias,
      );
      if (!mounted) return;
      setState(() {
        _records = records;
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
            AppScreenHeader.large(
              title: '${_formatDate(widget.member.withdrawnAt)} 탈퇴 회원',
              titleSize: 26,
              subtitle: '${_formatDate(widget.member.expireAt)} 파기 예정',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _records.isEmpty,
                onRefresh: _load,
                padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
                empty: const AppEmptyState(
                  icon: AppIcons.archive,
                  compact: true,
                  top: 96,
                  message: '보관된 기록이 없습니다.',
                  description: '보관 기간이 지나 파기되었을 수 있습니다.',
                ),
                children: [
                  // ── PT 계약 ──
                  _SectionHeader(
                    title: 'PT 계약',
                    count: contracts.length,
                    top: 28 - 24, // 본문 위 24를 빼고 제목 아래 28
                  ),
                  if (contracts.isEmpty)
                    const AppEmptyLine('기록 없음')
                  else
                    for (final c in contracts)
                      _ContractCard(record: c, trainer: _trainerName(c)),
                  const AppSectionBand(top: AppSpacing.xl),
                  // ── 수업 기록 ──
                  _SectionHeader(title: '수업 기록', count: sessions.length),
                  if (sessions.isEmpty)
                    const AppEmptyLine('기록 없음')
                  else
                    for (int i = 0; i < sessions.length; i++)
                      AppEntrance.slide(
                        delay: Duration(milliseconds: 40 * (i < 10 ? i : 10)),
                        child: _sessionRow(sessions[i]),
                      ),
                  const AppSectionBand(top: AppSpacing.base),
                  // ── 횟수 변경 이력 ──
                  _SectionHeader(title: '횟수 변경 이력', count: logs.length),
                  if (logs.isEmpty)
                    const AppEmptyLine('기록 없음')
                  else
                    for (int i = 0; i < logs.length; i++)
                      AppEntrance.slide(
                        delay: Duration(milliseconds: 40 * (i < 10 ? i : 10)),
                        child: _logRow(logs[i]),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 수업 줄 (시안): 64 · '2026.08.17 (월) 19:00' 15/500 · 13 mute '50분 · 이트레이너' ·
  /// 오른쪽 14 상태 — 예약 noticeText 500 · 완료 ink 500 · 취소 faint 400(제목도 faint).
  Widget _sessionRow(RetainedPtRecord s) {
    final status = s.sessionStatus;
    final cancelled = status == PtSessionStatus.cancelled;
    final statusStyle = switch (status) {
      PtSessionStatus.scheduled => AppTextStyles.bodySmall.medium.copyWith(
        color: AppColors.noticeText,
      ),
      PtSessionStatus.completed => AppTextStyles.bodySmall.medium.copyWith(
        color: AppColors.ink,
      ),
      _ => AppTextStyles.bodySmall.copyWith(color: AppColors.faint),
    };
    return AppListRow(
      title: s.scheduledAt == null ? '-' : _dateTime.format(s.scheduledAt!),
      titleStyle: AppTextStyles.bodyMd.medium,
      subtitle: '${s.durationMinutes ?? '-'}분 · ${_trainerName(s)}',
      height: 64,
      dimmed: cancelled,
      trailing: status == null ? null : Text(status.label, style: statusStyle),
    );
  }

  /// 횟수 변경 줄 (시안): 왼쪽 날짜 칸('08.10' 15/500 + '2026') · 15/500 종류 ·
  /// 13 body '잔여 5 → 4회' · 13 mute '처리 이트레이너'.
  Widget _logRow(RetainedPtRecord l) {
    final at = l.createdAt;
    return AppListRow(
      leading: at == null
          ? null
          : AppDateCell(
              top: DateFormat('MM.dd').format(at),
              bottom: '${at.year}',
              small: true,
            ),
      title: l.logType?.label ?? '변경',
      titleStyle: AppTextStyles.bodyMd.medium,
      subtitle:
          '잔여 ${l.previousRemainingSessions ?? '-'} → ${l.nextRemainingSessions ?? '-'}회'
          '${_totalChange(l)}',
      subtitleColor: AppColors.body,
      note: l.changedByName == null ? null : '처리 ${l.changedByName}',
      noteColor: AppColors.mute,
      height: 0,
      verticalPadding: 14,
    );
  }

  static String _totalChange(RetainedPtRecord log) {
    final prev = log.previousTotalSessions;
    final next = log.nextTotalSessions;
    if (prev == null || next == null || prev == next) return '';
    return ' · 총 $prev → $next회';
  }
}

/// 섹션 머리말 (시안 Ad-WithdrawnDetail): 17/500 라벨 + 오른쪽 15/500 개수 · '건' mute. 여백 [top] 20 4.
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final double top;

  const _SectionHeader({
    required this.title,
    required this.count,
    this.top = AppSpacing.lg,
  });

  @override
  Widget build(BuildContext context) {
    return AppMonthHeader(
      label: title,
      strong: true,
      count: '$count',
      unit: '건',
      strongCount: true,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        top,
        AppSpacing.screenH,
        AppSpacing.xs,
      ),
    );
  }
}

/// PT 계약 카드 (시안): 회색 · 반경 18 · 안쪽 16 18, 기간 16/500 → (8) 3칸
/// (남은 횟수 · 담당 · 갱신일 — 라벨 12 mute, 값 15/500).
class _ContractCard extends StatelessWidget {
  final RetainedPtRecord record;
  final String trainer;

  const _ContractCard({required this.record, required this.trainer});

  @override
  Widget build(BuildContext context) {
    final c = record;
    Widget cell(String label, InlineSpan value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.captionSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text.rich(
            value,
            style: AppTextStyles.bodyMd.medium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatDate(c.startDate)} ~ ${_formatDate(c.endDate)}',
            style: AppTextStyles.listTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cell(
                '남은 횟수',
                TextSpan(
                  children: [
                    TextSpan(text: '${c.remainingSessions ?? '-'}'),
                    TextSpan(
                      text: ' / ${c.totalSessions ?? '-'}회',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: AppColors.mute,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              cell('담당', TextSpan(text: trainer)),
              const SizedBox(width: AppSpacing.sm),
              cell(
                '갱신일',
                TextSpan(
                  text: c.renewalDate == null
                      ? '-'
                      : _formatDate(c.renewalDate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
