import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/join_request.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_tag.dart';

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
      AppFeedback.showSuccessSnackBar(context, '${req.userName}님의 가입을 승인했습니다.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(req.id));
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  Future<void> _reject(JoinRequest req) async {
    if (_processingIds.contains(req.id)) return;
    final confirm = await showAppConfirmDialog(
      context,
      title: '가입 거절',
      message:
          '${req.userName}님의 가입 신청을 거절합니다. 거절된 계정은 로그인할 수 없고, 이 결정은 되돌릴 수 없어요.',
      confirmLabel: '거절',
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
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: '가입 신청',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _requests.isEmpty,
                onRefresh: _load,
                empty: const AppEmptyState(
                  icon: AppIcons.userPlus,
                  message: '대기 중인 신청이 없습니다.',
                ),
                children: [
                  AppMonthHeader(
                    label: '승인 대기',
                    count: '${_requests.length}',
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xl,
                      bottom: AppSpacing.sm,
                    ),
                  ),
                  for (int i = 0; i < _requests.length; i++) ...[
                    if (i > 0) const AppRowDivider(),
                    _RequestRow(
                      req: _requests[i],
                      isProcessing: _processingIds.contains(_requests[i].id),
                      onApprove: () => _approve(_requests[i]),
                      onReject: () => _reject(_requests[i]),
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

// ── _RequestRow ───────────────────────────────────────────────────────────────

/// 신청 한 줄: 아바타 + 이름 + 역할 태그 + (이메일 · 신청일) + 오른쪽 정렬 거절(글자)·승인(외곽선).
class _RequestRow extends StatelessWidget {
  final JoinRequest req;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestRow({
    required this.req,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isTrainer = req.role == 'trainer';
    final date = DateFormat('M월 d일').format(req.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            req.userName,
                            style: AppTextStyles.bodyLg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppTag(isTrainer ? '트레이너' : '회원'),
                      ],
                    ),
                    Text(
                      '${req.userEmail} · $date',
                      style: AppTextStyles.bodySm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: '거절',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                onPressed: isProcessing ? null : onReject,
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                label: '승인',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onPressed: isProcessing ? null : onApprove,
                isLoading: isProcessing,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
