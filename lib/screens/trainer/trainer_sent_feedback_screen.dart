import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/feedback.dart' as fb;
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/feedback_sheet.dart';

/// 보낸 피드백 (시안 09 '보낸 피드백'): 회원 상세 ⋯ → '보낸 피드백'.
///
/// 이 회원에게 **내가** 보낸 피드백(식단 · 운동 · 유산소 · 전체 피드백)을 최신순으로 모은다.
/// 이전 담당 트레이너 것은 빼고, 종류 알약으로 거르고, ⋯로 고치기 · 지우기.
/// '전체 피드백'(특정 기록에 달리지 않은 것)은 여기서만 다시 볼 수 있다.
class TrainerSentFeedbackScreen extends StatefulWidget {
  final AppUser member;

  const TrainerSentFeedbackScreen({super.key, required this.member});

  /// 최근 몇 개까지 읽을지 (회원 기준으로 읽은 뒤 내 것만 거른다).
  static const int fetchLimit = 100;

  @override
  State<TrainerSentFeedbackScreen> createState() =>
      _TrainerSentFeedbackScreenState();
}

/// 종류 알약: 전체 · 식단 · 운동 · 유산소 · 전체 피드백. null이면 '전체'.
const List<fb.FeedbackTargetType?> _filters = [
  null,
  fb.FeedbackTargetType.meal,
  fb.FeedbackTargetType.workout,
  fb.FeedbackTargetType.cardio,
  fb.FeedbackTargetType.general,
];

String _filterLabel(fb.FeedbackTargetType? type) =>
    type == null ? '전체' : _typeLabel(type, long: true);

/// 줄 앞 종류 글자. 일반 피드백은 '전체 피드백'(알약) / '전체'(줄).
String _typeLabel(fb.FeedbackTargetType type, {bool long = false}) =>
    type == fb.FeedbackTargetType.general
    ? (long ? '전체 피드백' : '전체')
    : type.label;

class _TrainerSentFeedbackScreenState extends State<TrainerSentFeedbackScreen> {
  List<fb.Feedback> _all = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _filter = 0;

  /// 고치기 창을 여는 중 (두 번 눌림 막기)
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = context.read<UserProvider>().user;
    if (me == null) return;
    setState(() {
      _isLoading = _all.isEmpty;
      _errorMessage = null;
    });
    try {
      final list = await FirestoreService.getFeedbacksForMember(
        widget.member.uid,
        centerId: widget.member.centerId,
        limit: TrainerSentFeedbackScreen.fetchLimit,
      );
      if (!mounted) return;
      setState(() {
        _all = list.where((f) => f.trainerId == me.uid).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = AppFeedback.errorMessage(e);
      });
    }
  }

  List<fb.Feedback> get _visible {
    final type = _filters[_filter];
    return type == null
        ? _all
        : _all.where((f) => f.targetType == type).toList();
  }

  Future<void> _showMenu(fb.Feedback feedback) async {
    final action = await showAppBottomSheet<String>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppBottomSheetHeader(title: '내 피드백', gap: AppSpacing.md),
            AppSheetAction(
              icon: AppIcons.edit,
              label: '고치기',
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
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
      await _edit(feedback);
    } else {
      await _delete(feedback);
    }
  }

  /// 피드백 창을 '고치는 중'으로 연다 (창 안에 '피드백 지우기'도 있다).
  Future<void> _edit(fb.Feedback feedback) async {
    final me = context.read<UserProvider>().user;
    if (me == null || _busy) return;
    _busy = true;
    try {
      final changed = await FeedbackSheet.show(
        context,
        centerId: feedback.centerId,
        trainerId: me.uid,
        trainerName: me.name,
        memberId: feedback.memberId,
        memberName: widget.member.name,
        targetType: feedback.targetType,
        targetId: feedback.targetId,
        targetDate: feedback.targetDate,
        existing: feedback,
        targetLinked: true,
      );
      if (changed == true && mounted) await _load();
    } finally {
      _busy = false;
    }
  }

  Future<void> _delete(fb.Feedback feedback) async {
    final ok = await showAppConfirmDialog(
      context,
      title: '피드백 지우기',
      message: '회원 화면에서도 이 피드백이 사라집니다. 되돌릴 수 없습니다.',
      confirmLabel: '지우기',
    );
    if (!ok || !mounted) return;
    try {
      await FirestoreService.deleteFeedback(feedback);
      if (!mounted) return;
      setState(() => _all = _all.where((f) => f.id != feedback.id).toList());
      AppFeedback.showSuccessSnackBar(context, '피드백을 지웠어요');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final type = _filters[_filter];
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.centered(
              title: '보낸 피드백',
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.xs,
                AppSpacing.screenH,
                0,
              ),
              child: Text(
                '${widget.member.name}님에게',
                style: AppTextStyles.title,
              ),
            ),
            AppViewTabs(
              labels: [for (final t in _filters) _filterLabel(t)],
              counts: [
                for (final t in _filters)
                  '${t == null ? _all.length : _all.where((f) => f.targetType == t).length}',
              ],
              selectedIndex: _filter,
              compact: true,
              scrollable: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                0,
              ),
              onSelect: (i) => setState(() => _filter = i),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: visible.isEmpty,
                onRefresh: _load,
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.xl3,
                ),
                empty: AppEmptyState(
                  icon: AppIcons.feedback,
                  compact: true,
                  message: type == null
                      ? '아직 보낸 피드백이 없어요.'
                      : '보낸 ${_typeLabel(type)} 피드백이 없어요.',
                ),
                children: [
                  for (int i = 0; i < visible.length; i++) ...[
                    if (i > 0) const AppRowDivider.inset(),
                    SentFeedbackRow(
                      key: ValueKey(visible[i].id),
                      feedback: visible[i],
                      onMore: () => _showMenu(visible[i]),
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

/// 보낸 피드백 한 줄 (위아래 16, 좌우 20): 종류 13/500 ink · 대상 날짜 14/500 →
/// 오른쪽 '수정됨 · 읽음/안 읽음' 13 mute(안 읽음은 noticeText) · ⋯ → 본문 15 · 줄 높이 1.55.
class SentFeedbackRow extends StatelessWidget {
  final fb.Feedback feedback;
  final VoidCallback onMore;

  const SentFeedbackRow({
    super.key,
    required this.feedback,
    required this.onMore,
  });

  /// 대상 날짜 ('10월 13일'). 기록 날짜가 없으면(전체 피드백) 보낸 날.
  String get _dateLabel {
    final target = DateTime.tryParse(feedback.targetDate ?? '');
    return DateFormat('M월 d일', 'ko').format(target ?? feedback.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final read = feedback.isRead;
    final type = _typeLabel(feedback.targetType);
    final date = _dateLabel;
    return Semantics(
      container: true,
      label:
          '$type 피드백, $date, ${feedback.isEdited ? '수정됨, ' : ''}'
          '${read ? '회원이 읽음' : '회원이 아직 안 읽음'}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.base,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ExcludeSemantics(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$type  ',
                            style: AppTextStyles.counter.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: date,
                            style: AppTextStyles.bodySmall.medium.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ExcludeSemantics(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (feedback.isEdited) const TextSpan(text: '수정됨 · '),
                        TextSpan(
                          text: read ? '읽음' : '안 읽음',
                          style: read
                              ? null
                              : TextStyle(
                                  color: AppColors.noticeText,
                                  fontWeight: FontWeight.w500,
                                ),
                        ),
                      ],
                    ),
                    style: AppTextStyles.counter,
                  ),
                ),
                AppIconButton(
                  icon: AppIcons.more,
                  label: '내 피드백 고치기 · 지우기',
                  onPressed: onMore,
                  color: AppColors.mute,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Text(
                feedback.content,
                style: AppTextStyles.bodyMd.copyWith(
                  height: 1.55,
                  color: AppColors.body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
