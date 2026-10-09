import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../models/notice.dart';
import '../../services/notice_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/notice_widgets.dart';
import 'admin_notice_edit_screen.dart';

/// 관리자 공지 상세 (시안 Nt-Admin-Detail): 제목 · 등록 시각 → 요약 카드 → 내용 → 아래 삭제 · 수정.
/// 바뀌면 true를 돌려준다.
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
      // 시안 Nt-Admin-DeleteConfirm
      message:
          '${noticeAudienceLabel(_notice.audience)} 화면에서 바로 사라져요. '
          '${_notice.notify ? '이미 보낸 푸시 알림은 알림함에 남아요.' : '삭제한 공지는 되돌릴 수 없어요.'}',
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
    // 밀어서 뒤로 가기도 막지 않는다 (목록은 돌아오면 늘 다시 불러온다).
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.large(
              title: '',
              onBack: () => Navigator.of(context).pop(_changed),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.xl2,
                ),
                child: NoticeArticle(notice: _notice, admin: true),
              ),
            ),
            // 시안: 2칸 56 — 삭제 회색 · 수정 검정 (16/500)
            AppBottomActionBar(
              secondaryLabel: '삭제',
              onSecondary: _deleting ? null : _delete,
              primaryLabel: '수정',
              primaryVariant: AppButtonVariant.dark,
              onPrimary: _deleting ? null : _edit,
            ),
          ],
        ),
      ),
    );
  }
}
