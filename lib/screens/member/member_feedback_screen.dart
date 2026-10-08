import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/feedback.dart' as fb;
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_loader.dart';

/// 트레이너 피드백 (시안 MemB-Feedback · FeedbackEmpty): 가운데 17 머리(오른쪽 '새 글 n') →
/// '피드백  n' → 줄(이름 16/500 · 시각 13 오른쪽 끝 / 본문 15 / '새 글 · 식단 · 10.08').
class MemberFeedbackScreen extends StatefulWidget {
  const MemberFeedbackScreen({super.key});

  @override
  State<MemberFeedbackScreen> createState() => _MemberFeedbackScreenState();
}

class _MemberFeedbackScreenState extends State<MemberFeedbackScreen> {
  List<fb.Feedback> _feedbacks = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  /// 이번에 화면을 열 때 안 읽음이었던 피드백. 읽음 처리 뒤에도 이 화면에서는 NEW로 강조한다.
  Set<String> _newIds = {};

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
      final feedbacks = await FirestoreService.getFeedbacksForMember(
        user.uid,
        centerId: user.centerId,
        limit: 100,
      );
      final unreadIds = feedbacks
          .where((feedback) => !feedback.isRead)
          .map((feedback) => feedback.id)
          .toList();
      if (!mounted) return;
      setState(() {
        _feedbacks = feedbacks;
        _unreadCount = unreadIds.length;
        _newIds = unreadIds.toSet();
      });
      try {
        await FirestoreService.markFeedbacksRead(
          centerId: user.centerId,
          memberId: user.uid,
          feedbackIds: unreadIds,
        );
        if (!mounted || unreadIds.isEmpty) return;
        final now = DateTime.now();
        final unreadIdSet = unreadIds.toSet();
        setState(() {
          _feedbacks = _feedbacks
              .map(
                (feedback) => unreadIdSet.contains(feedback.id)
                    ? feedback.copyWith(readAt: now, updatedAt: now)
                    : feedback,
              )
              .toList();
          _unreadCount = 0;
        });
      } catch (e) {
        AppLogger.debug('[피드백 읽음 처리 오류] $e');
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final newCount = _newIds.isNotEmpty ? _newIds.length : _unreadCount;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.centered(
              title: '트레이너 피드백',
              onBack: () => Navigator.of(context).pop(),
              trailing: newCount > 0
                  // 오른쪽 칸(44, 가운데 정렬) 안에서 글자 끝을 화면 오른쪽 20에 맞춘다
                  ? SizedBox(
                      width: 120,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 50),
                          child: Semantics(
                            label: '새 피드백 $newCount개',
                            excludeSemantics: true,
                            child: Text(
                              '새 글 $newCount',
                              maxLines: 1,
                              style: AppTextStyles.bodySmall.medium.copyWith(
                                color: AppColors.noticeText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.ink,
                backgroundColor: AppColors.canvasCard,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_isLoading)
                      const SliverFillRemaining(child: AppLoadingView())
                    else if (_feedbacks.isEmpty)
                      const SliverToBoxAdapter(
                        child: AppEmptyState(
                          icon: AppIcons.feedback,
                          card: true,
                          // 시안: 화면 위 220 (머리 56 아래 164)
                          margin: EdgeInsets.fromLTRB(
                            AppSpacing.screenH,
                            164,
                            AppSpacing.screenH,
                            0,
                          ),
                          illustration: _BobbingIcon(),
                          cardPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: 36,
                          ),
                          artGap: 14,
                          message: '등록된 피드백이 없습니다',
                          description: '트레이너가 운동·식단 기록에 남긴 코멘트가 여기에 모입니다.',
                        ),
                      )
                    else ...[
                      SliverToBoxAdapter(
                        child: AppMonthHeader(
                          label: '피드백',
                          count: '${_feedbacks.length}',
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenH,
                            AppSpacing.base,
                            AppSpacing.screenH,
                            AppSpacing.xs,
                          ),
                        ),
                      ),
                      SliverList.separated(
                        itemCount: _feedbacks.length,
                        separatorBuilder: (_, _) => const AppRowDivider.inset(),
                        itemBuilder: (context, index) {
                          final item = _feedbacks[index];
                          // 시안 `slide`: .4s, 0.05초 간격 (화면 밖 줄은 늦게 기다리지 않게 8번째까지만)
                          return AppEntrance.slide(
                            delay: Duration(
                              milliseconds: 50 * (index < 8 ? index : 8),
                            ),
                            child: _FeedbackRow(
                              feedback: item,
                              isNew: _newIds.contains(item.id) || !item.isRead,
                            ),
                          );
                        },
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.xl3),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 피드백 한 줄 (위아래 16, 좌우 20): 안 읽음 점은 글자 왼쪽 바깥(x 8, y 24)에 따로 둬서
/// 이름·본문의 시작이 머리말과 같은 20에 오게 한다.
/// 이름 16/500 + 시각 13 mute(오른쪽 끝, 글자 바닥선 맞춤) → 본문 15 · 줄 높이 1.55 →
/// 보조 줄 13 mute ('새 글'만 500 noticeText).
class _FeedbackRow extends StatelessWidget {
  final fb.Feedback feedback;
  final bool isNew;

  const _FeedbackRow({required this.feedback, required this.isNew});

  @override
  Widget build(BuildContext context) {
    final name = feedback.trainerName.trim();
    final displayName = name.isEmpty ? '트레이너' : '$name 트레이너';
    final targetDate = DateTime.tryParse(feedback.targetDate ?? '');
    final time = DateFormat('MM.dd HH:mm').format(feedback.createdAt);
    final meta = [
      feedback.targetType.label,
      if (targetDate != null) DateFormat('MM.dd').format(targetDate),
    ].join(' · ');

    return Semantics(
      container: true,
      label:
          '${isNew ? '새 피드백, ' : ''}$displayName, '
          '${DateFormat('M월 d일 a h시 mm분', 'ko').format(feedback.createdAt)}, '
          '${feedback.targetType.label} 피드백',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.base,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isNew)
              Positioned(
                left: -12,
                top: 8,
                child: AppPulse(
                  scale: 1.4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: AppTextStyles.listTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(time, style: AppTextStyles.counter),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  feedback.content,
                  style: AppTextStyles.bodyMd.copyWith(
                    height: 1.55,
                    color: isNew ? AppColors.ink : AppColors.body,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ExcludeSemantics(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (isNew) ...[
                          TextSpan(
                            text: '새 글',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppColors.noticeText,
                            ),
                          ),
                          const TextSpan(text: ' · '),
                        ],
                        TextSpan(text: meta),
                      ],
                    ),
                    style: AppTextStyles.counter,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 빈 화면 그림: 말풍선 44 (faint, 선 1.5)가 위아래로 천천히 흔들림 (시안 `bob`: 2.4s, -5px).
class _BobbingIcon extends StatefulWidget {
  const _BobbingIcon();

  @override
  State<_BobbingIcon> createState() => _BobbingIconState();
}

class _BobbingIconState extends State<_BobbingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Icon(AppIcons.feedback, size: 44, color: AppColors.faint),
      builder: (context, child) {
        final v = _controller.value;
        final tri = v < 0.5 ? v * 2 : (1 - v) * 2;
        return Transform.translate(
          offset: Offset(0, -5 * Curves.easeInOut.transform(tri)),
          child: child,
        );
      },
    );
  }
}
