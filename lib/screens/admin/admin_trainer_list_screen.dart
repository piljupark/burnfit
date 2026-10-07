import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/user.dart';
import '../../models/pt_info.dart';
import '../../models/pt_session.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_text_field.dart';
import 'admin_member_detail_screen.dart';
import '../../widgets/app_kpi_card.dart';

class AdminTrainerListScreen extends StatefulWidget {
  const AdminTrainerListScreen({super.key});

  @override
  State<AdminTrainerListScreen> createState() => _AdminTrainerListScreenState();
}

class _AdminTrainerListScreenState extends State<AdminTrainerListScreen> {
  List<AppUser> _trainers = [];
  List<AppUser> _filtered = [];
  bool _isLoading = false;
  String? _errorMessage;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final list = await FirestoreService.getTrainersByCenter(user.centerId);
      if (!mounted) return;
      setState(() {
        _trainers = list;
        _filtered = list;
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

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _trainers
          : _trainers
                .where(
                  (t) =>
                      t.name.toLowerCase().contains(q) ||
                      t.email.toLowerCase().contains(q),
                )
                .toList();
    });
  }

  bool _openingDetail = false;

  Future<void> _showTrainerDetail(AppUser trainer) async {
    // 불러오는 동안 여러 번 눌러 시트가 겹쳐 열리지 않게 한다.
    if (_openingDetail) return;
    setState(() => _openingDetail = true);
    try {
      final now = DateTime.now();
      final (members, monthSessions) = await (
        FirestoreService.getMembersByTrainer(trainer.centerId, trainer.uid),
        FirestoreService.getPtSessionsByTrainer(
          trainer.centerId,
          trainer.uid,
          from: DateTime(now.year, now.month),
          // 조회는 끝 시각을 포함(<=)하므로 다음 달 1일 0시 직전까지
          to: DateTime(
            now.year,
            now.month + 1,
          ).subtract(const Duration(milliseconds: 1)),
        ),
      ).wait;
      // 배정 회원만 조회한다 (센터 전체 PT 정보를 읽지 않는다).
      final ptInfos = await Future.wait(
        members.map(
          (m) => FirestoreService.getPtInfo(m.uid, centerId: trainer.centerId),
        ),
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final opened = await showAppBottomSheet<AppUser>(
        context: context,
        child: _TrainerDetailSheet(
          trainer: trainer,
          members: members,
          ptInfos: {
            for (var i = 0; i < members.length; i++)
              if (ptInfos[i] != null) members[i].uid: ptInfos[i]!,
          },
          monthCompleted: monthSessions
              .where((s) => s.status == PtSessionStatus.completed)
              .length,
        ),
      );
      // 회원 줄을 누르면 시트를 닫고 회원 상세로 간다 (담당 변경은 거기서).
      if (opened != null) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => AdminMemberDetailScreen(member: opened),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _openingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 탭으로 열리면 AppHero, 메뉴에서 밀어 열리면 뒤로 버튼 앱바.
            if (canPop) ...[
              AppScreenHeader(
                title: '트레이너 관리',
                subtitle: '${_trainers.length}명',
                onBack: () => Navigator.of(context).pop(),
              ),
            ] else
              const AppHero(title: '트레이너'),
            // 검색
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.base,
                AppSpacing.screenH,
                AppSpacing.base,
              ),
              child: AppTextField(
                label: '',
                hint: '이름 또는 이메일 검색',
                controller: _searchController,
                prefix: const Icon(AppIcons.search),
                textInputAction: TextInputAction.search,
              ),
            ),
            const AppRowDivider(),
            // 목록
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _filtered.isEmpty,
                onRefresh: _load,
                empty: AppEmptyState(
                  icon: AppIcons.trainers,
                  message: _trainers.isEmpty
                      ? '등록된 트레이너가 없습니다.'
                      : '검색 결과가 없습니다.',
                ),
                children: [
                  for (int i = 0; i < _filtered.length; i++) ...[
                    if (i > 0) const AppRowDivider(),
                    _TrainerListItem(
                      trainer: _filtered[i],
                      onTap: () => _showTrainerDetail(_filtered[i]),
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

// ── _TrainerListItem ──────────────────────────────────────────────────────────

/// 트레이너 한 줄: 아바타 + 이름 + 이메일 + (승인 대기면 "승인 대기" 태그) + 화살표.
class _TrainerListItem extends StatelessWidget {
  final AppUser trainer;
  final VoidCallback onTap;

  const _TrainerListItem({required this.trainer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.listRow),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trainer.name,
                        style: AppTextStyles.bodyLg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        trainer.email,
                        style: AppTextStyles.bodySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!trainer.isApproved) ...[
                  const AppTag('승인 대기'),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Icon(
                  AppIcons.forward,
                  size: AppSize.icon,
                  color: AppColors.mute,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── _TrainerDetailSheet ───────────────────────────────────────────────────────

/// 트레이너 상세 시트: 이름 · 이메일 · 등록일 → 숫자 2칸(배정 회원 · 이번 달 PT 완료) → 배정 회원(PT 잔여).
/// 센터는 관리자 센터와 항상 같아서 적지 않는다. 승인 대기면 태그로 알린다.
/// 회원 줄을 누르면 그 회원을 돌려주며 닫힌다.
class _TrainerDetailSheet extends StatelessWidget {
  final AppUser trainer;
  final List<AppUser> members;
  final Map<String, PtInfo> ptInfos;
  final int monthCompleted;

  const _TrainerDetailSheet({
    required this.trainer,
    required this.members,
    required this.ptInfos,
    required this.monthCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final created = trainer.createdAt;
    final createdLabel =
        '${created.year}.${created.month.toString().padLeft(2, '0')}.${created.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(
          title: trainer.name,
          subtitle: [
            if (!trainer.isApproved) '승인 대기',
            trainer.email,
            '$createdLabel 등록',
          ].join(' · '),
        ),
        AppStatStrip(
          topBorder: true,
          cells: [
            AppKpiCard(
              label: '배정 회원',
              value: '${members.length}',
              unit: '명',
              framed: false,
              valueSize: 24,
            ),
            AppKpiCard(
              label: '이번 달 PT 완료',
              value: '$monthCompleted',
              unit: '회',
              framed: false,
              valueSize: 24,
            ),
          ],
        ),
        AppMonthHeader(
          label: '배정 회원',
          count: '${members.length}',
          padding: const EdgeInsets.only(
            top: AppSpacing.xl,
            bottom: AppSpacing.sm,
          ),
        ),
        if (members.isEmpty)
          const AppEmptyLine('배정된 회원이 없습니다.', inset: false)
        else
          for (int i = 0; i < members.length; i++) ...[
            if (i > 0) const AppRowDivider(),
            _MemberRowItem(
              member: members[i],
              ptInfo: ptInfos[members[i].uid],
              onTap: () => Navigator.of(context).pop(members[i]),
            ),
          ],
      ],
    );
  }
}

// ── _MemberRowItem ────────────────────────────────────────────────────────────

/// 배정 회원 한 줄: 이름 + PT 잔여 + 화살표.
class _MemberRowItem extends StatelessWidget {
  final AppUser member;
  final PtInfo? ptInfo;
  final VoidCallback onTap;

  const _MemberRowItem({
    required this.member,
    required this.ptInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pt = ptInfo;
    final ptLabel = pt == null
        ? 'PT 이용권 없음'
        : 'PT ${pt.remainingSessions} / ${pt.totalSessions}회 남음';
    return Semantics(
      button: true,
      label: '${member.name}, $ptLabel',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.listRow),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: AppTextStyles.bodyLg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        ptLabel,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.body,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  AppIcons.forward,
                  size: AppSize.icon,
                  color: AppColors.mute,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
