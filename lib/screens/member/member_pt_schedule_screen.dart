import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_info.dart';
import '../../models/pt_session.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';

class MemberPtScheduleScreen extends StatefulWidget {
  final bool showBackButton;

  const MemberPtScheduleScreen({super.key, this.showBackButton = true});

  @override
  State<MemberPtScheduleScreen> createState() => _MemberPtScheduleScreenState();
}

class _MemberPtScheduleScreenState extends State<MemberPtScheduleScreen> {
  PtInfo? _ptInfo;
  List<PtSession> _sessions = [];
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
      final now = DateTime.now();
      final results = await Future.wait([
        FirestoreService.getPtInfo(user.uid, centerId: user.centerId),
        FirestoreService.getPtSessionsByMember(
          user.uid,
          centerId: user.centerId,
          from: now.subtract(const Duration(days: 90)),
          to: now.add(const Duration(days: 180)),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _ptInfo = results[0] as PtInfo?;
        _sessions =
            (results[1] as List<PtSession>)
                .where((item) => item.status != PtSessionStatus.cancelled)
                .toList()
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
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

  List<PtSession> get _upcoming {
    final now = DateTime.now().subtract(const Duration(minutes: 1));
    return _sessions
        .where(
          (item) =>
              item.status == PtSessionStatus.scheduled &&
              item.scheduledAt.isAfter(now),
        )
        .toList();
  }

  List<PtSession> get _past {
    final now = DateTime.now();
    return _sessions
        .where(
          (item) =>
              item.status == PtSessionStatus.completed ||
              item.scheduledAt.isBefore(now),
        )
        .toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.brand,
          backgroundColor: AppColors.card,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppScreenHeader(
                        title: 'PT 일정',
                        onBack: widget.showBackButton
                            ? () => Navigator.of(context).pop()
                            : null,
                      ),
                      const Gap(16),
                      _PtSummaryCard(info: _ptInfo),
                      const Gap(20),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_errorMessage != null)
                        AppErrorCard(message: _errorMessage!, onRetry: _load)
                      else ...[
                        _SessionSection(
                          title: '예정된 일정',
                          sessions: _upcoming,
                          emptyText: '예정된 PT 일정이 없습니다.',
                          isPast: false,
                        ),
                        const Gap(20),
                        _SessionSection(
                          title: '지난 일정',
                          sessions: _past,
                          emptyText: '지난 PT 일정이 없습니다.',
                          isPast: true,
                        ),
                      ],
                      const Gap(120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PtSummaryCard extends StatelessWidget {
  final PtInfo? info;

  const _PtSummaryCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final renewalDate = info?.renewalDate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.trainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PT 잔여 횟수',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnAccent.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                const Gap(6),
                Text(
                  '${info?.remainingSessions ?? 0}회',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textOnAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            renewalDate == null
                ? '갱신일\n-'
                : '갱신일\n${DateFormat('M월 d일', 'ko').format(renewalDate)}',
            textAlign: TextAlign.right,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textOnAccent.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionSection extends StatelessWidget {
  final String title;
  final List<PtSession> sessions;
  final String emptyText;
  final bool isPast;

  const _SessionSection({
    required this.title,
    required this.sessions,
    required this.emptyText,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        if (sessions.isEmpty)
          AppCard(
            hasBorder: false,
            hasShadow: true,
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: Text(
              emptyText,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          Column(
            children: [
              for (final session in sessions) ...[
                _SessionCard(session: session, isPast: isPast),
                const Gap(12),
              ],
            ],
          ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final PtSession session;
  final bool isPast;

  const _SessionCard({required this.session, required this.isPast});

  Color _statusColor() {
    switch (session.status) {
      case PtSessionStatus.scheduled:
        return AppColors.brand;
      case PtSessionStatus.completed:
        return AppColors.workout;
      case PtSessionStatus.cancelled:
        return AppColors.destructive;
    }
  }

  String _statusLabel() {
    switch (session.status) {
      case PtSessionStatus.scheduled:
        return '예정';
      case PtSessionStatus.completed:
        return '완료';
      case PtSessionStatus.cancelled:
        return '취소';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('M월 d일(E)', 'ko').format(session.scheduledAt);
    final timeLabel = DateFormat('a h:mm', 'ko').format(session.scheduledAt);
    final trainerInitial = session.trainerName.trim().isNotEmpty
        ? session.trainerName.trim()[0]
        : 'T';

    return Opacity(
      opacity: isPast ? 0.72 : 1,
      child: AppCard(
        hasBorder: false,
        hasShadow: true,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.trainer.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                trainerInitial,
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.trainer,
                ),
              ),
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    '$timeLabel · ${session.trainerName} 트레이너',
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            _StatusBadge(label: _statusLabel(), color: _statusColor()),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

