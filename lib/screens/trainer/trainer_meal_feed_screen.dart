import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/meal_feed_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/app_section.dart';
import '../../widgets/meal_feed.dart';
import '../../widgets/notification_bell_button.dart';

/// 트레이너 '식단' 탭: 담당 회원들의 식단을 최신순 피드로 보고 카드 아래에서 바로 피드백한다.
///
/// 맨 위 '전체 · 회원 이름' 버튼 — 회원 버튼에는 피드백할 식단 수(연한 주황 숫자)와
/// 새 식단(주황 점)을 따로 표시한다. 회원 버튼을 누르면 그 회원의 새 표시를 지운다.
/// 처음에는 최근 7일, 맨 아래 '이전 7일 더 보기'로 더 불러온다.
class TrainerMealFeedScreen extends StatefulWidget {
  /// 피드백할 식단 수가 바뀔 때 (아래 탭 점).
  final ValueChanged<int>? onPendingChanged;

  const TrainerMealFeedScreen({super.key, this.onPendingChanged});

  @override
  State<TrainerMealFeedScreen> createState() => TrainerMealFeedScreenState();
}

class TrainerMealFeedScreenState extends State<TrainerMealFeedScreen> {
  List<AppUser> _members = [];
  List<MealFeedItem> _items = [];
  Map<String, DateTime> _seen = {};

  /// 고른 회원 (null이면 전체).
  String? _memberId;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// 불러온 가장 오래된 날 (이전 7일 더 보기의 기준).
  late DateTime _oldest;

  AppUser? get _trainer => context.read<UserProvider>().user;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// 처음부터 다시 불러온다 (탭에 다시 들어올 때 · 당겨서 새로고침 · 알림).
  Future<void> refresh() async {
    final trainer = _trainer;
    if (trainer == null) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final from = today.subtract(
      const Duration(days: MealFeedService.pageDays - 1),
    );
    if (_items.isEmpty) setState(() => _loading = true);
    try {
      final members = await FirestoreService.getMembersByTrainer(
        trainer.centerId,
        trainer.uid,
      );
      final results = await Future.wait([
        MealFeedService.load(members: members, from: from, to: today),
        MealFeedSeenStore.load(trainer.uid),
      ]);
      if (!mounted) return;
      setState(() {
        _members = members;
        _items = results[0] as List<MealFeedItem>;
        _seen = results[1] as Map<String, DateTime>;
        _oldest = from;
        _error = null;
        if (_memberId != null && !members.any((m) => m.uid == _memberId)) {
          _memberId = null;
        }
      });
      _notifyPending();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AppFeedback.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _members.isEmpty) return;
    final to = _oldest.subtract(const Duration(days: 1));
    final from = to.subtract(
      const Duration(days: MealFeedService.pageDays - 1),
    );
    setState(() => _loadingMore = true);
    try {
      final older = await MealFeedService.load(
        members: _members,
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _items = MealFeedService.sortNewestFirst([..._items, ...older]);
        _oldest = from;
      });
      _notifyPending();
    } catch (e) {
      if (mounted) AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _notifyPending() {
    final trainer = _trainer;
    if (trainer == null) return;
    widget.onPendingChanged?.call(
      MealFeedBadges.pendingCount(_items, trainer.uid),
    );
  }

  Future<void> _selectMember(String? memberId) async {
    setState(() => _memberId = memberId);
    final trainer = _trainer;
    if (memberId == null || trainer == null) return;
    // 이 회원의 식단을 봤으므로 새 표시를 지운다.
    final now = DateTime.now();
    setState(() => _seen = {..._seen, memberId: now});
    await MealFeedSeenStore.markSeen(trainer.uid, memberId, now);
  }

  Future<bool> _send(MealFeedItem item, String content) async {
    final trainer = _trainer;
    if (trainer == null) return false;
    try {
      final feedback = await MealFeedService.sendFeedback(
        trainer: trainer,
        item: item,
        content: content,
      );
      if (!mounted) return true;
      setState(() {
        _items = [
          for (final x in _items)
            x.meal.id == item.meal.id ? x.withFeedback(feedback) : x,
        ];
      });
      _notifyPending();
      return true;
    } catch (e) {
      if (mounted) AppFeedback.showErrorSnackBar(context, e);
      return false;
    }
  }

  /// 새 식단·피드백할 식단이 있는 회원을 앞으로 (그다음 이름순).
  List<(AppUser, MealFeedBadge)> _memberChips(String trainerId, DateTime now) {
    final chips = [
      for (final m in _members)
        (
          m,
          MealFeedBadges.forMember(
            _items,
            memberId: m.uid,
            trainerId: trainerId,
            lastSeen: _seen[m.uid],
            now: now,
          ),
        ),
    ];
    chips.sort((a, b) {
      final fresh = (b.$2.fresh ? 1 : 0) - (a.$2.fresh ? 1 : 0);
      if (fresh != 0) return fresh;
      final todo = b.$2.todo - a.$2.todo;
      if (todo != 0) return todo;
      return a.$1.name.compareTo(b.$1.name);
    });
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final trainer = _trainer;
    final now = DateTime.now();
    final visible = _memberId == null
        ? _items
        : _items.where((i) => i.member.uid == _memberId).toList();
    final fresh = trainer == null
        ? const <String>{}
        : {
            for (final i in _items)
              if (MealFeedBadges.isNew(
                i,
                trainerId: trainer.uid,
                lastSeen: _seen[i.member.uid],
                now: now,
              ))
                i.meal.id,
          };

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppHero(
              title: '식단',
              bottomGap: AppSpacing.sm,
              actions: [NotificationBellButton()],
            ),
            if (trainer != null && _members.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  children: [
                    _MemberChip(
                      label: '전체',
                      selected: _memberId == null,
                      onTap: () => _selectMember(null),
                    ),
                    for (final (member, badge) in _memberChips(
                      trainer.uid,
                      now,
                    ))
                      _MemberChip(
                        label: member.name,
                        selected: _memberId == member.uid,
                        todo: badge.todo,
                        fresh: badge.fresh,
                        onTap: () => _selectMember(member.uid),
                      ),
                  ],
                ),
              ),
            Expanded(child: _body(trainer, visible, fresh)),
          ],
        ),
      ),
    );
  }

  Widget _body(
    AppUser? trainer,
    List<MealFeedItem> visible,
    Set<String> fresh,
  ) {
    // 아래 탭 바가 위에 떠 있으므로 그만큼 비운다.
    final bottomPad = AppNavBar.totalHeight(context) + AppSpacing.xl;
    if (_loading && _items.isEmpty) return const AppLoadingView();
    if (_error != null && _items.isEmpty) {
      return Center(
        child: AppErrorCard(message: _error!, onRetry: refresh),
      );
    }
    if (trainer == null) return const SizedBox.shrink();
    if (_members.isEmpty) {
      return const AppEmptyState(
        icon: AppIcons.meal,
        message: '담당 회원이 없어요',
        description: '회원이 배정되면 그 회원의 식단이 여기에 보여요.',
      );
    }
    final footer = Padding(
      padding: const EdgeInsets.only(top: AppSpacing.base),
      child: Center(
        child: AppButton(
          label: '이전 7일 더 보기',
          variant: AppButtonVariant.secondary,
          isLoading: _loadingMore,
          onPressed: _loadMore,
        ),
      ),
    );
    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        color: AppColors.ink,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPad),
          children: [
            const Gap(AppSpacing.xl3),
            Icon(AppIcons.meal, size: 48, color: AppColors.faint),
            const Gap(AppSpacing.md),
            Text(
              '이 기간에 올라온 식단이 없어요',
              textAlign: TextAlign.center,
              style: AppTextStyles.section,
            ),
            const Gap(AppSpacing.sm),
            Text(
              '담당 회원이 식단을 올리면 여기에 보여요.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm,
            ),
            footer,
          ],
        ),
      );
    }
    return MealFeedList(
      items: visible,
      trainerId: trainer.uid,
      freshMealIds: fresh,
      onSend: _send,
      onRefresh: refresh,
      footer: footer,
      padding: EdgeInsets.only(bottom: bottomPad),
    );
  }
}

/// 회원 버튼(높이 36 알약, 터치 44): 고르면 검정 채움 + 흰 500. 피드백할 식단이 있으면
/// 이름 옆 연한 주황 숫자(20), 새 식단이면 오른쪽 위 주황 점(8, newDot).
class _MemberChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int todo;
  final bool fresh;
  final VoidCallback onTap;

  const _MemberChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.todo = 0,
    this.fresh = false,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = [
      label,
      if (todo > 0) '피드백할 식단 $todo개',
      if (fresh) '새 식단 있음',
    ].join(', ');
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        button: true,
        selected: selected,
        label: semantic,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.ink : AppColors.canvasSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: selected ? AppColors.canvas : AppColors.body,
                          fontWeight: selected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                      if (todo > 0) ...[
                        const Gap(6),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.noticeBg,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '$todo',
                            style: AppTextStyles.captionSmall.bold.copyWith(
                              color: selected
                                  ? AppPalette.light.ink
                                  : AppColors.noticeText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (fresh)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.newDot,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.canvas, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
