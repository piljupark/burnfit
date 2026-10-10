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
import 'app_calendar.dart';
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

  const MealFeedCard({
    super.key,
    required this.item,
    required this.trainerId,
    required this.onSend,
    this.isNew = false,
    this.showMember = true,
  });

  /// 비어 있는 카드에서 한 번에 채우는 말.
  static const quickPhrases = ['단백질 좋아요', '채소를 조금 더', '양 적당해요'];

  @override
  State<MealFeedCard> createState() => _MealFeedCardState();
}

class _MealFeedCardState extends State<MealFeedCard> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

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
    setState(() => _sending = true);
    final ok = await widget.onSend(content);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _controller.clear();
      _focus.unfocus();
    }
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
                            child: Text(
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
          // 칼로리 · 메모
          if (meal.calories != null || memo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                10,
                AppSpacing.screenH,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meal.calories != null)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: NumberFormat('#,##0').format(meal.calories),
                          ),
                          TextSpan(
                            text: 'kcal',
                            style: TextStyle(
                              color: AppColors.mute,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      style: AppTextStyles.bodyMd.bold,
                    ),
                  if (memo.isNotEmpty) ...[
                    const Gap(AppSpacing.xs),
                    Text(memo, style: AppTextStyles.bodyMd),
                  ],
                ],
              ),
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
                    ),
                  ],
                ],
              ),
            ),
          // 자주 쓰는 말 (아직 내 피드백이 없을 때)
          if (!sent)
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
                  for (final phrase in MealFeedCard.quickPhrases)
                    _QuickChip(label: phrase, onTap: () => _quick(phrase)),
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
                  label:
                      '${item.member.name} ${meal.mealType.label} 식단에 피드백 보내기',
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

  const _FeedbackComment({required this.feedback, required this.mine});

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
        border: mine ? null : Border.all(color: AppColors.hairline),
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
