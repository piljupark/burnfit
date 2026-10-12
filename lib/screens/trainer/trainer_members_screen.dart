import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/user.dart';
import '../../services/trainer_members_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/notification_bell_button.dart';
import 'trainer_member_detail_screen.dart';

/// 트레이너 '회원' 탭 (시안 08-trainer-members-tab): '회원 12' + 종 → 48 검색 →
/// 알약(전체 · 확인 필요 · PT 곧 끝남 · 목표 없음, 개수) → 68 회원 줄.
///
/// 회원 줄: 첫 글자 원 40 · 이름 16/500(+ '새 회원') · 'PT 7회 남음 · 3일 전 운동 · 목표 없음' 13
/// (주의할 값만 noticeText 500) · 오른쪽 피드백할 식단 수(주황 원) + 화살표.
/// 확인 필요한 회원이 위, 나머지는 이름순. 누르면 회원 상세 — 피드백할 식단이 있으면 식단 탭으로.
class TrainerMembersScreen extends StatefulWidget {
  const TrainerMembersScreen({super.key});

  @override
  State<TrainerMembersScreen> createState() => TrainerMembersScreenState();
}

class TrainerMembersScreenState extends State<TrainerMembersScreen> {
  /// 탭을 다시 열 때 (트레이너 셸이 부른다)
  Future<void> refresh() => _load();

  List<TrainerMemberSummary> _all = [];
  TrainerMemberFilter _filter = TrainerMemberFilter.all;
  bool _isLoading = false;
  bool _loadedOnce = false;
  String? _errorMessage;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final trainer = context.read<UserProvider>().user;
    if (trainer == null) return;
    // 처음에만 전체를 로딩으로 (새로고침 · 돌아와서 다시 읽을 때는 보이던 목록을 둔다)
    if (!_loadedOnce) setState(() => _isLoading = true);
    try {
      final list = await TrainerMembersService.load(trainer);
      if (!mounted) return;
      setState(() {
        _all = TrainerMembersService.sorted(list);
        _errorMessage = null;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (_loadedOnce) {
        AppFeedback.showErrorSnackBar(context, e);
      } else {
        setState(() => _errorMessage = AppFeedback.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<TrainerMemberSummary> get _visible {
    final q = _searchController.text.trim().toLowerCase();
    return _all
        .where(
          (s) =>
              _filter.matches(s) &&
              (q.isEmpty || s.member.name.toLowerCase().contains(q)),
        )
        .toList();
  }

  Future<void> _open(TrainerMemberSummary s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainerMemberDetailScreen(
          member: s.member,
          initialTab: s.pendingMeals > 0
              ? TrainerMemberDetailTab.meal
              : TrainerMemberDetailTab.workout,
        ),
      ),
    );
    // 상세에서 식단 목표를 정하거나 피드백했을 수 있다 → 표시를 바로 맞춘다.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final query = _searchController.text.trim();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppHero(
              title: '회원',
              count: _isLoading && _all.isEmpty ? null : '${_all.length}',
              actions: const [NotificationBellButton()],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
              ),
              child: AppTextField(
                label: '',
                hint: '이름으로 찾기',
                controller: _searchController,
                prefix: const Icon(AppIcons.search),
                dense: true,
                textInputAction: TextInputAction.search,
              ),
            ),
            AppViewTabs(
              labels: [for (final f in TrainerMemberFilter.values) f.label],
              counts: [
                for (final f in TrainerMemberFilter.values)
                  '${_all.where(f.matches).length}',
              ],
              selectedIndex: _filter.index,
              compact: true,
              scrollable: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                14 - 3,
                AppSpacing.screenH,
                0,
              ),
              onSelect: (i) =>
                  setState(() => _filter = TrainerMemberFilter.values[i]),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: visible.isEmpty,
                onRefresh: _load,
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm - 3,
                  bottom: AppSpacing.xl2 + AppSize.navClearance,
                ),
                empty: AppEmptyState(
                  icon: AppIcons.members,
                  compact: true,
                  top: 106,
                  message: _all.isEmpty
                      ? '아직 담당 회원이 없어요.\n관리자가 배정하면 여기에 보여요.'
                      : query.isNotEmpty
                      ? "'$query'에 맞는 회원이 없어요."
                      : '${_filter.label} 회원이 없어요.',
                ),
                children: [
                  for (int i = 0; i < visible.length; i++)
                    AppEntrance(
                      key: ValueKey(visible[i].member.uid),
                      offset: const Offset(0, 8),
                      duration: const Duration(milliseconds: 400),
                      delay: Duration(milliseconds: 50 * (i < 10 ? i : 10)),
                      child: TrainerMemberRow(
                        summary: visible[i],
                        onTap: () => _open(visible[i]),
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

/// 회원 줄 (68): 첫 글자 원 40 · 이름 + '새 회원' · 요약 13 (주의할 값만 noticeText) ·
/// 피드백할 식단 수 주황 원 22 · 화살표 18.
class TrainerMemberRow extends StatelessWidget {
  final TrainerMemberSummary summary;
  final VoidCallback onTap;

  const TrainerMemberRow({
    super.key,
    required this.summary,
    required this.onTap,
  });

  /// 요약 조각들: (글자, 주의 표시)
  List<(String, bool)> get _parts {
    final s = summary;
    final info = s.ptInfo;
    final parts = <(String, bool)>[];
    if (info == null) {
      parts.add(('PT 없음', false));
    } else if (!s.hasActivePt) {
      parts.add(('PT 끝남', false));
    } else {
      parts.add((
        'PT ${info.remainingSessions}회 남음',
        info.remainingSessions <= 3,
      ));
      final left = s.ptDaysLeft;
      if (left != null && left <= 14) {
        parts.add((left == 0 ? '오늘 종료' : '기간 D-$left', true));
      }
    }
    parts.add((s.workoutLabel, s.idle));
    if (!s.hasPlan) parts.add(('목표 없음', true));
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final parts = _parts;
    final warn = TextStyle(
      color: AppColors.noticeText,
      fontWeight: FontWeight.w500,
    );
    return Semantics(
      button: true,
      label: [
        s.member.name,
        if (s.isNew) '새 회원',
        ...parts.map((p) => p.$1),
        if (s.pendingMeals > 0) '피드백할 식단 ${s.pendingMeals}개',
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.canvasCard,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    s.member.name.isEmpty
                        ? '?'
                        : s.member.name.characters.first,
                    style: AppTextStyles.bodyMd.medium.copyWith(
                      color: AppColors.body,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              s.member.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.listTitle,
                            ),
                          ),
                          if (s.isNew) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.noticeBg,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                '새 회원',
                                style: AppTextStyles.badge.copyWith(
                                  color: AppColors.noticeText,
                                  height: 18 / 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            for (var i = 0; i < parts.length; i++) ...[
                              if (i > 0) const TextSpan(text: ' · '),
                              TextSpan(
                                text: parts[i].$1,
                                style: parts[i].$2 ? warn : null,
                              ),
                            ],
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
                if (s.pendingMeals > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${s.pendingMeals}',
                      style: AppTextStyles.captionSmall.bold.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.xs),
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

/// 회원 상세를 연다 (회원 이름을 누르는 곳들이 함께 쓴다).
Future<void> openTrainerMemberDetail(
  BuildContext context,
  AppUser member, {
  TrainerMemberDetailTab tab = TrainerMemberDetailTab.workout,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          TrainerMemberDetailScreen(member: member, initialTab: tab),
    ),
  );
}
