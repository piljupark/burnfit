import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/feedback.dart' as fb;
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';

class MemberFeedbackScreen extends StatefulWidget {
  const MemberFeedbackScreen({super.key});

  @override
  State<MemberFeedbackScreen> createState() => _MemberFeedbackScreenState();
}

class _MemberFeedbackScreenState extends State<MemberFeedbackScreen> {
  List<fb.Feedback> _feedbacks = [];
  int _unreadCount = 0;
  bool _isLoading = false;

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.brand,
          backgroundColor: AppColors.card,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.md,
                    AppSpacing.screenH,
                    0,
                  ),
                  child: AppScreenHeader(
                    title: '트레이너 피드백',
                    onBack: () => Navigator.of(context).pop(),
                    trailing: _unreadCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              '새 $_unreadCount',
                              style: AppTextStyles.captionSmall.copyWith(
                                color: AppColors.textOnAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_feedbacks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                    ),
                    child: AppEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      message: '등록된 피드백이 없습니다.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  sliver: SliverList.separated(
                    itemCount: _feedbacks.length,
                    separatorBuilder: (_, __) => const Gap(12),
                    itemBuilder: (context, index) {
                      return _FeedbackCard(feedback: _feedbacks[index]);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final fb.Feedback feedback;

  const _FeedbackCard({required this.feedback});

  @override
  Widget build(BuildContext context) {
    final initial = feedback.trainerName.trim().isNotEmpty
        ? feedback.trainerName.trim()[0]
        : 'T';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              color: AppColors.trainer,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!feedback.isRead) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Gap(8),
                        ],
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.trainer.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.trainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feedback.trainerName,
                                style: AppTextStyles.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const Gap(2),
                              Text(
                                DateFormat('M월 d일', 'ko').format(feedback.createdAt),
                                style: AppTextStyles.captionSmall.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(12),
                    Text(
                      feedback.content,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textNeutral,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
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
