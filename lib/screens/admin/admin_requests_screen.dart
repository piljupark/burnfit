import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/join_request.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  List<JoinRequest> _requests = [];
  final Set<String> _processingIds = {};
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
      final list = await FirestoreService.getPendingRequests(user.centerId);
      if (!mounted) return;
      setState(() {
        _requests = list;
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

  Future<void> _approve(JoinRequest req) async {
    if (_processingIds.contains(req.id)) return;
    setState(() => _processingIds.add(req.id));
    try {
      await FirestoreService.approveJoinRequest(req.id, req.userId);
      if (!mounted) return;
      setState(() {
        _requests.removeWhere((r) => r.id == req.id);
        _processingIds.remove(req.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${req.userName}님의 가입을 승인했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(req.id));
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  Future<void> _reject(JoinRequest req) async {
    if (_processingIds.contains(req.id)) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text('가입 거절', style: AppTextStyles.h3),
        content: Text(
          '${req.userName}님의 가입 신청을 거절하시겠습니까?',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              '취소',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '거절',
              style: AppTextStyles.body.copyWith(
                color: AppColors.destructive,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processingIds.add(req.id));
    try {
      await FirestoreService.rejectJoinRequest(req.id, req.userId);
      if (!mounted) return;
      setState(() {
        _requests.removeWhere((r) => r.id == req.id);
        _processingIds.remove(req.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(req.id));
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                0,
              ),
              child: AppScreenHeader(
                title: '가입 신청',
                subtitle: _requests.isNotEmpty ? '${_requests.length}건 대기중' : null,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            const Gap(AppSpacing.md),
            // 바디
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.brand,
                      backgroundColor: AppColors.card,
                      child: _errorMessage != null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 120),
                                AppErrorCard(
                                  message: _errorMessage!,
                                  onRetry: _load,
                                ),
                              ],
                            )
                          : _requests.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(top: AppSpacing.xl),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.screenH,
                                  ),
                                  child: AppEmptyState(
                                    icon: Icons.person_add_outlined,
                                    message: '대기 중인 신청이 없습니다.',
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.screenH,
                                0,
                                AppSpacing.screenH,
                                AppSpacing.xl2,
                              ),
                              children: _requests.map((req) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: _RequestCard(
                                    req: req,
                                    isProcessing: _processingIds.contains(req.id),
                                    onApprove: () => _approve(req),
                                    onReject: () => _reject(req),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _RequestCard ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final JoinRequest req;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.req,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final initial = req.userName.isNotEmpty ? req.userName[0] : '?';
    final isTrainer = req.role == 'trainer';
    final accentColor = isTrainer ? AppColors.trainer : AppColors.brand;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 아바타 + 이름/이메일 + 역할 뱃지
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base,
              AppSpacing.base,
              AppSpacing.base,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                // 48x48 원형 아바타
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: AppTextStyles.headline.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ),
                const Gap(AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이름 (headline)
                      Text(
                        req.userName,
                        style: AppTextStyles.headline,
                      ),
                      const Gap(2),
                      // 이메일 (caption, textSecondary)
                      Text(
                        req.userEmail,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 역할 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    isTrainer ? '트레이너' : '회원',
                    style: AppTextStyles.caption.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 신청 일시
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base,
              0,
              AppSpacing.base,
              AppSpacing.sm,
            ),
            child: Text(
              DateFormat('yyyy.MM.dd HH:mm').format(req.createdAt),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          // 구분선
          const Divider(height: 1, color: AppColors.border),
          // 버튼 Row
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '거절',
                    variant: AppButtonVariant.secondary,
                    onPressed: isProcessing ? null : onReject,
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: '승인',
                    onPressed: isProcessing ? null : onApprove,
                    isLoading: isProcessing,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
