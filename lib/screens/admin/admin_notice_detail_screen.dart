import 'package:flutter/material.dart';

import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../models/notice.dart';
import '../../services/notice_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/notice_widgets.dart';
import 'admin_notice_edit_screen.dart';

/// 관리자 공지 상세: 수정 / 삭제. 바뀌면 true를 돌려준다.
class AdminNoticeDetailScreen extends StatefulWidget {
  final Notice notice;
  const AdminNoticeDetailScreen({super.key, required this.notice});

  @override
  State<AdminNoticeDetailScreen> createState() =>
      _AdminNoticeDetailScreenState();
}

class _AdminNoticeDetailScreenState extends State<AdminNoticeDetailScreen> {
  late Notice _notice = widget.notice;
  bool _changed = false;
  bool _deleting = false;

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminNoticeEditScreen(notice: _notice)),
    );
    if (saved != true) return;
    _changed = true;
    try {
      final fresh = await NoticeService.get(_notice.id);
      if (fresh != null && mounted) setState(() => _notice = fresh);
    } catch (_) {}
  }

  Future<void> _delete() async {
    final ok = await showAppConfirmDialog(
      context,
      title: '공지를 삭제할까요?',
      message: '‘${_notice.title}’ 공지가 회원과 트레이너 화면에서 사라져요. 삭제한 공지는 되돌릴 수 없어요.',
      confirmLabel: '삭제',
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    try {
      await NoticeService.delete(_notice.id);
      if (!mounted) return;
      AppToast.show(context, message: '공지를 삭제했어요');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppScreenHeader(
                title: '공지 상세',
                onBack: () => Navigator.of(context).pop(_changed),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.xl,
                    AppSpacing.screenH,
                    AppSpacing.xl2,
                  ),
                  child: NoticeArticle(notice: _notice, showAudience: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '삭제',
                        variant: AppButtonVariant.secondary,
                        fullWidth: true,
                        size: AppButtonSize.lg,
                        isLoading: _deleting,
                        onPressed: _deleting ? null : _delete,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: '수정',
                        fullWidth: true,
                        size: AppButtonSize.lg,
                        onPressed: _deleting ? null : _edit,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
