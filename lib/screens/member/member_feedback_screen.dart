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
import '../../widgets/app_tag.dart';
import '../../widgets/orb_loader.dart';

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
            AppScreenHeader(
              title: '트레이너 피드백',
              onBack: () => Navigator.of(context).pop(),
              trailing: newCount > 0
                  ? Semantics(
                      label: '새 피드백 $newCount개',
                      excludeSemantics: true,
                      child: AppTag('새 글 $newCount', strong: true),
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
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          icon: AppIcons.feedback,
                          message: '등록된 피드백이 없습니다',
                          description: '트레이너가 운동·식단 기록에 남긴 코멘트가 여기에 모입니다.',
                        ),
                      )
                    else ...[
                      SliverToBoxAdapter(
                        child: AppMonthHeader(
                          label: '피드백',
                          count: '${_feedbacks.length}',
                        ),
                      ),
                      SliverList.separated(
                        itemCount: _feedbacks.length,
                        separatorBuilder: (_, _) =>
                            const AppRowDivider(indent: AppSpacing.screenH),
                        itemBuilder: (context, index) {
                          final item = _feedbacks[index];
                          return _FeedbackRow(
                            feedback: item,
                            isNew: _newIds.contains(item.id) || !item.isRead,
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

/// 피드백 한 줄: 안 읽음 점 + 아바타 + 트레이너 이름·시각 + 본문 + 대상 태그.
/// 안 읽음은 색이 아니라 모양(채운 점 + NEW 흰 태그)으로 표시한다.
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

    return Semantics(
      container: true,
      label:
          '${isNew ? '새 피드백, ' : ''}$displayName, '
          '${DateFormat('M월 d일 a h시 mm분', 'ko').format(feedback.createdAt)}, '
          '${feedback.targetType.label} 피드백',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.base,
          AppSpacing.screenH,
          AppSpacing.base,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안 읽음 점 자리 (읽었으면 비워 둔다)
            SizedBox(
              width: AppSpacing.sm,
              height: 36,
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isNew ? AppColors.newDot : Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: ExcludeSemantics(
                          child: Text(
                            displayName,
                            style: AppTextStyles.bodyLg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const ExcludeSemantics(
                          child: AppTag('새 글', strong: true),
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(width: AppSpacing.sm),
                      ExcludeSemantics(
                        child: Text(time, style: AppTextStyles.counter),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    feedback.content,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: isNew ? AppColors.ink : AppColors.body,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        AppTag(feedback.targetType.label),
                        if (targetDate != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            DateFormat('MM.dd').format(targetDate),
                            style: AppTextStyles.counter,
                          ),
                        ],
                      ],
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
