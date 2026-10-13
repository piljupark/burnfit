import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../models/feedback.dart' as fb;
import '../models/meal.dart';
import '../services/meal_feed_service.dart';
import 'app_bottom_sheet.dart';
import 'app_calendar.dart';
import 'app_confirm_dialog.dart';
import 'app_hero.dart';
import 'app_loader.dart';
import 'app_tag.dart';

/// 트레이너 식단 피드 목록 (식단 탭 · 회원 상세 식단 탭 공용).
/// 날짜 머리말('오늘 · 3건') 아래로 [MealFeedCard]가 이어진다. [footer]는 맨 아래('이전 7일 더 보기').
class MealFeedList extends StatelessWidget {
  final List<MealFeedItem> items;
  final String trainerId;

  /// 새 식단 표시를 붙일 식단 ID.
  final Set<String> freshMealIds;

  /// 카드 머리에 회원 이름을 쓸지 (회원 상세에서는 이미 한 회원이라 끈다).
  final bool showMember;

  /// 피드백 보내기. 성공하면 true (카드가 입력을 비운다).
  final Future<bool> Function(MealFeedItem item, String content) onSend;
  final Future<void> Function() onRefresh;

  /// 카드의 회원 이름을 누르면 (회원 상세). [showMember]일 때만 쓴다.
  final void Function(MealFeedItem item)? onMemberTap;

  /// 그 끼니의 식단 목표 가이드 (사진 아래 한 줄). 없으면 null.
  final String? Function(MealFeedItem item)? guideFor;

  /// 회원에게 식단 목표가 있으면 true → 자주 쓰는 말을 목표 기준으로.
  final bool Function(MealFeedItem item)? hasPlanFor;

  /// 내 피드백 고치기 · 지우기. 성공하면 true. 없으면 말풍선에 ⋯를 두지 않는다.
  final Future<bool> Function(
    MealFeedItem item,
    fb.Feedback feedback,
    String content,
  )?
  onEditFeedback;
  final Future<bool> Function(MealFeedItem item, fb.Feedback feedback)?
  onDeleteFeedback;
  final Widget? footer;
  final Widget? header;
  final EdgeInsetsGeometry padding;

  const MealFeedList({
    super.key,
    required this.items,
    required this.trainerId,
    required this.onSend,
    required this.onRefresh,
    this.freshMealIds = const {},
    this.showMember = true,
    this.onMemberTap,
    this.guideFor,
    this.hasPlanFor,
    this.onEditFeedback,
    this.onDeleteFeedback,
    this.footer,
    this.header,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.xl2),
  });

  static String dayLabel(String mealDate, DateTime now) {
    final date = DateTime.tryParse(mealDate);
    if (date == null) return mealDate;
    final today = DateUtils.dateOnly(now);
    final diff = today.difference(DateUtils.dateOnly(date)).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return appDayLabel(date);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final children = <Widget>[?header];
    String? day;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.meal.mealDate != day) {
        day = item.meal.mealDate;
        final count = items.skip(i).takeWhile((x) => x.meal.mealDate == day);
        if (children.isNotEmpty && i > 0) {
          children.add(
            Container(
              height: AppSpacing.sm,
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              color: AppColors.canvasCard,
            ),
          );
        }
        children.add(
          AppMonthHeader(
            label: dayLabel(day, now),
            count: '${count.length}건',
            bold: true,
          ),
        );
      }
      children.add(
        MealFeedCard(
          key: ValueKey(item.meal.id),
          item: item,
          trainerId: trainerId,
          isNew: freshMealIds.contains(item.meal.id),
          showMember: showMember,
          onMemberTap: onMemberTap == null ? null : () => onMemberTap!(item),
          guide: guideFor?.call(item),
          onEditFeedback: onEditFeedback == null
              ? null
              : (f, content) => onEditFeedback!(item, f, content),
          onDeleteFeedback: onDeleteFeedback == null
              ? null
              : (f) => onDeleteFeedback!(item, f),
          quickPhrases: hasPlanFor?.call(item) == true
              ? MealFeedCard.goalPhrases
              : MealFeedCard.basicPhrases,
          onSend: (content) => onSend(item, content),
        ),
      );
    }
    if (footer != null) children.add(footer!);
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.ink,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: padding,
        children: children,
      ),
    );
  }
}

/// 식단 카드: 머리(회원 · 끼니 · 시각 · '피드백 전'/'보냄') → 정사각 사진(넘겨 보기, '1/3') →
/// 칼로리 · 메모 → 피드백(댓글처럼 쌓임, 읽음) → 자주 쓰는 말 → 입력 줄.
/// 테두리·그림자 없이 아래 hairline으로 나눈다.
class MealFeedCard extends StatefulWidget {
  final MealFeedItem item;
  final String trainerId;
  final bool isNew;
  final bool showMember;
  final Future<bool> Function(String content) onSend;

  /// 회원 이름을 누르면 (회원 상세)
  final VoidCallback? onMemberTap;

  /// 그 끼니의 식단 목표 가이드 — 사진 아래 회색 한 줄 ('점심 가이드  단백질 손바닥 1개 + …').
  final String? guide;

  /// 아직 내 피드백이 없을 때 한 번에 채우는 말.
  final List<String> quickPhrases;

  /// 내 피드백 고치기 · 지우기 (성공하면 true). 둘 다 없으면 ⋯를 두지 않는다.
  final Future<bool> Function(fb.Feedback feedback, String content)?
  onEditFeedback;
  final Future<bool> Function(fb.Feedback feedback)? onDeleteFeedback;

  const MealFeedCard({
    super.key,
    required this.item,
    required this.trainerId,
    required this.onSend,
    this.isNew = false,
    this.showMember = true,
    this.onMemberTap,
    this.guide,
    this.quickPhrases = basicPhrases,
    this.onEditFeedback,
    this.onDeleteFeedback,
  });

  /// 자주 쓰는 말 — 식단 목표가 없는 회원.
  static const basicPhrases = ['단백질 좋아요', '채소를 조금 더', '양 적당해요'];

  /// 자주 쓰는 말 — 식단 목표가 있는 회원 (칼로리 대신 목표에 맞게 먹었는지로).
  static const goalPhrases = [
    '가이드대로 잘 드셨어요',
    '단백질을 조금 더',
    '탄수화물이 많아요',
    '양 적당해요',
  ];

  @override
  State<MealFeedCard> createState() => _MealFeedCardState();
}

class _MealFeedCardState extends State<MealFeedCard> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

  /// 고치는 중인 내 피드백 (입력 줄이 '수정' 모드가 된다).
  fb.Feedback? _editing;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;
    final editing = _editing;
    if (editing != null && content == editing.content.trim()) {
      _cancelEdit();
      return;
    }
    setState(() => _sending = true);
    final ok = editing != null
        ? await widget.onEditFeedback!(editing, content)
        : await widget.onSend(content);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) _editing = null;
    });
    if (ok) {
      _controller.clear();
      _focus.unfocus();
    }
  }

  void _startEdit(fb.Feedback feedback) {
    setState(() => _editing = feedback);
    _controller.text = feedback.content;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _focus.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editing = null);
    _controller.clear();
    _focus.unfocus();
  }

  /// 내 말풍선의 ⋯: 고치기 · 지우기.
  Future<void> _showFeedbackMenu(fb.Feedback feedback) async {
    final action = await showAppBottomSheet<String>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppBottomSheetHeader(title: '내 피드백', gap: AppSpacing.md),
            if (widget.onEditFeedback != null)
              AppSheetAction(
                icon: AppIcons.edit,
                label: '고치기',
                onTap: () => Navigator.of(sheetContext).pop('edit'),
              ),
            if (widget.onDeleteFeedback != null)
              AppSheetAction(
                icon: AppIcons.trash,
                label: '지우기',
                destructive: true,
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      _startEdit(feedback);
      return;
    }
    final ok = await showAppConfirmDialog(
      context,
      title: '피드백 지우기',
      message: '회원 화면에서도 이 피드백이 사라집니다. 되돌릴 수 없습니다.',
      confirmLabel: '지우기',
    );
    if (!ok || !mounted) return;
    if (_editing?.id == feedback.id) _cancelEdit();
    await widget.onDeleteFeedback!(feedback);
  }

  void _quick(String phrase) {
    final current = _controller.text.trim();
    _controller.text = current.isEmpty ? phrase : '$current $phrase';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final meal = item.meal;
    final sent = item.hasFeedbackFrom(widget.trainerId);
    final title = widget.showMember ? item.member.name : meal.mealType.label;
    final sub = [
      if (widget.showMember) meal.mealType.label,
      if (meal.mealTime != null && meal.mealTime!.isNotEmpty) meal.mealTime!,
    ].join(' · ');
    final memo = meal.description?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.base,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 머리
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child:
                                widget.showMember && widget.onMemberTap != null
                                ? Semantics(
                                    button: true,
                                    hint: '회원 상세 보기',
                                    child: GestureDetector(
                                      onTap: widget.onMemberTap,
                                      behavior: HitTestBehavior.opaque,
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.listTitle,
                                      ),
                                    ),
                                  )
                                : Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.listTitle,
                                  ),
                          ),
                          if (widget.isNew) ...[
                            const Gap(6),
                            Semantics(
                              label: '새 식단',
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.newDot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (sub.isNotEmpty)
                        Text(sub, style: AppTextStyles.bodySm),
                    ],
                  ),
                ),
                Text(
                  sent ? '보냄' : '피드백 전',
                  style: sent
                      ? AppTextStyles.bodySm
                      : AppTextStyles.bodySm.medium.copyWith(
                          color: AppColors.noticeText,
                        ),
                ),
              ],
            ),
          ),
          if (meal.imageUrls.isNotEmpty) ...[
            const Gap(AppSpacing.sm),
            _MealPhotos(urls: meal.imageUrls),
          ],
          // 그 끼니의 식단 목표 가이드
          if ((widget.guide ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                10,
                AppSpacing.screenH,
                0,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.canvasCard,
                  borderRadius: BorderRadius.circular(AppRadius.iconBox),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${meal.mealType.label} 가이드  ',
                        style: TextStyle(color: AppColors.mute),
                      ),
                      TextSpan(text: widget.guide!.trim()),
                    ],
                  ),
                  style: AppTextStyles.caption,
                ),
              ),
            ),
          // 메모 (칼로리는 보이지 않는다 — 예전 기록의 값은 저장만 돼 있다)
          if (memo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                10,
                AppSpacing.screenH,
                0,
              ),
              child: Text(memo, style: AppTextStyles.bodyMd),
            ),
          // 피드백 (댓글처럼)
          if (item.feedbacks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                10,
                AppSpacing.screenH,
                0,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < item.feedbacks.length; i++) ...[
                    if (i > 0) const Gap(AppSpacing.sm),
                    _FeedbackComment(
                      feedback: item.feedbacks[i],
                      mine: item.feedbacks[i].trainerId == widget.trainerId,
                      editing: _editing?.id == item.feedbacks[i].id,
                      onMore:
                          item.feedbacks[i].trainerId == widget.trainerId &&
                              (widget.onEditFeedback != null ||
                                  widget.onDeleteFeedback != null)
                          ? () => _showFeedbackMenu(item.feedbacks[i])
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          // 자주 쓰는 말 (아직 내 피드백이 없을 때)
          if (!sent && _editing == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                10,
                AppSpacing.screenH,
                0,
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final phrase in widget.quickPhrases)
                    _QuickChip(label: phrase, onTap: () => _quick(phrase)),
                ],
              ),
            ),
          // 고치는 중 안내 (입력 줄 바로 위)
          if (_editing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                10,
                AppSpacing.screenH,
                0,
              ),
              child: Row(
                children: [
                  Icon(AppIcons.edit, size: 14, color: AppColors.noticeText),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      '피드백 고치는 중',
                      style: AppTextStyles.bodySm.medium.copyWith(
                        color: AppColors.noticeText,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '고치기 취소',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: _cancelEdit,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        height: 32,
                        child: Center(
                          child: Text(
                            '취소',
                            style: AppTextStyles.bodySm.medium.copyWith(
                              color: AppColors.body,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 입력 줄
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              10,
              AppSpacing.screenH,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    decoration: BoxDecoration(
                      color: AppColors.canvasSoft,
                      borderRadius: BorderRadius.circular(22),
                      border: _focus.hasFocus
                          ? Border.all(color: AppColors.ink, width: 2)
                          : Border.all(color: Colors.transparent, width: 2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      enabled: !_sending,
                      textInputAction: TextInputAction.newline,
                      style: AppTextStyles.bodyMd,
                      cursorColor: AppColors.ink,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        hintText: '피드백 남기기…',
                        hintStyle: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.mute,
                        ),
                      ),
                    ),
                  ),
                ),
                const Gap(AppSpacing.sm),
                _SendButton(
                  enabled: _controller.text.trim().isNotEmpty && !_sending,
                  sending: _sending,
                  label: _editing != null
                      ? '고친 피드백 저장'
                      : '${item.member.name} ${meal.mealType.label} 식단에 피드백 보내기',
                  onTap: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 정사각 사진(반경 20), 여러 장이면 넘겨 보기 + 오른쪽 위 '1/3' + 아래 점.
class _MealPhotos extends StatefulWidget {
  final List<String> urls;

  const _MealPhotos({required this.urls});

  @override
  State<_MealPhotos> createState() => _MealPhotosState();
}

class _MealPhotosState extends State<_MealPhotos> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final media = MediaQuery.of(context);
    // 작은 크기로 먼저 받아 그린다 (화면 폭 × 화면 배율)
    final cacheWidth = (media.size.width * media.devicePixelRatio).round();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: urls.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => Semantics(
                      image: true,
                      label: '식단 사진 ${i + 1}/${urls.length}',
                      child: Image.network(
                        urls[i],
                        fit: BoxFit.cover,
                        cacheWidth: cacheWidth,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : ColoredBox(color: AppColors.canvasCard),
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: AppColors.canvasSoft,
                          child: Icon(
                            AppIcons.image,
                            color: AppColors.faint,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (urls.length > 1)
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: AppCountBadge('${_index + 1}/${urls.length}'),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (urls.length > 1) ...[
          const Gap(10),
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < urls.length; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.ink : AppColors.canvasMid,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 피드백 한 개: 회색 상자(반경 14) · 이름 14/500 · 시각 12 mute(내 것이면 '읽음'/'안 읽음') · 본문 14/21 body.
/// 지금 담당이 아닌 트레이너의 피드백은 '이전 담당' + 테두리만.
class _FeedbackComment extends StatelessWidget {
  final fb.Feedback feedback;
  final bool mine;

  /// 이 피드백을 고치는 중 (말풍선 테두리 강조)
  final bool editing;

  /// 내 피드백의 ⋯ (고치기 · 지우기). null이면 두지 않는다.
  final VoidCallback? onMore;

  const _FeedbackComment({
    required this.feedback,
    required this.mine,
    this.editing = false,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final name = feedback.trainerName.trim().isEmpty
        ? '트레이너'
        : feedback.trainerName.trim();
    final created = feedback.createdAt;
    final when = DateUtils.isSameDay(created, DateTime.now())
        ? DateFormat('HH:mm').format(created)
        : '${appDayLabel(created)} ${DateFormat('HH:mm').format(created)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? AppColors.canvasCard : null,
        border: editing
            ? Border.all(color: AppColors.ink, width: 1.5)
            : mine
            ? null
            : Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: name),
                      if (!mine)
                        TextSpan(
                          text: ' · 이전 담당',
                          style: TextStyle(
                            color: AppColors.mute,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.medium.copyWith(
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Gap(AppSpacing.sm),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: when),
                    if (feedback.isEdited) const TextSpan(text: ' · 수정됨'),
                    if (mine)
                      feedback.isRead
                          ? const TextSpan(text: ' · 읽음')
                          : TextSpan(
                              text: ' · 안 읽음',
                              style: TextStyle(color: AppColors.noticeText),
                            ),
                  ],
                ),
                style: AppTextStyles.captionSmall,
              ),
              if (onMore != null)
                Semantics(
                  button: true,
                  label: '내 피드백 고치기 · 지우기',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onMore,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: Icon(
                        AppIcons.moreBold,
                        size: 18,
                        color: AppColors.dots,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Gap(2),
          Text(feedback.content, style: AppTextStyles.note),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label 넣기',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        splashFactory: NoSplash.splashFactory,
        highlightColor: AppColors.canvasSoft,
        // 글자 폭만큼만 (Wrap 안에서 한 줄을 다 차지하지 않게)
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
            ),
          ),
        ),
      ),
    );
  }
}

/// 보내기 원 44: 글자가 있으면 주황 채움 + 검정 화살표, 없으면 회색 + faint.
class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool sending;
  final String label;
  final VoidCallback onTap;

  const _SendButton({
    required this.enabled,
    required this.sending,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: AppSize.touchMin,
          height: AppSize.touchMin,
          decoration: BoxDecoration(
            color: enabled ? AppColors.primary : AppColors.canvasSoft,
            shape: BoxShape.circle,
          ),
          child: sending
              ? const Center(child: AppLoader.inline(semanticLabel: '보내는 중'))
              : Icon(
                  AppIcons.sendBold,
                  size: 20,
                  color: enabled ? AppColors.onPrimary : AppColors.faint,
                ),
        ),
      ),
    );
  }
}
