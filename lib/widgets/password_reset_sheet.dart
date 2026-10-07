import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../core/app_colors.dart';
import '../core/app_feedback.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/validators.dart';
import '../services/auth_service.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'app_text_field.dart';

/// 비밀번호 재설정 메일 발송 시트. 로그인 화면과 탈퇴 확인 시트에서 함께 쓴다.
Future<void> showPasswordResetSheet(BuildContext context, {String? initialEmail}) {
  return showAppBottomSheet<void>(
    context: context,
    memberStyle: true,
    child: _PasswordResetSheet(initialEmail: initialEmail),
  );
}

class _PasswordResetSheet extends StatefulWidget {
  final String? initialEmail;

  const _PasswordResetSheet({this.initialEmail});

  @override
  State<_PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<_PasswordResetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.initialEmail?.trim());
  bool _isSending = false;

  // 가입 여부를 알려주지 않도록 성공·미가입 모두 같은 문구를 쓴다.
  static const _sentMessage = '가입된 이메일이라면 재설정 메일이 발송됩니다. 메일함을 확인해주세요.';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending || !_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.sendPasswordReset(_emailController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(
        content: Text(_sentMessage),
        behavior: SnackBarBehavior.floating,
      ));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'user-not-found') {
        Navigator.of(context).pop();
        messenger.showSnackBar(const SnackBar(
          content: Text(_sentMessage),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      AppFeedback.showErrorSnackBar(context, e);
    } on Exception catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('비밀번호 재설정', style: AppTextStyles.h3),
          const Gap(AppSpacing.xs),
          Text(
            '가입한 이메일로 비밀번호 재설정 링크를 보내드려요.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const Gap(AppSpacing.lg),
          AppTextField(
            label: '이메일',
            hint: 'example@email.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            autofocus: widget.initialEmail == null || widget.initialEmail!.isEmpty,
            fillColor: AppColors.card,
            showEnabledBorder: true,
            labelAbove: true,
          ),
          const Gap(AppSpacing.lg),
          AppButton(
            label: '재설정 메일 보내기',
            onPressed: _send,
            isLoading: _isSending,
            fullWidth: true,
            size: AppButtonSize.lg,
          ),
        ],
      ),
    );
  }
}
