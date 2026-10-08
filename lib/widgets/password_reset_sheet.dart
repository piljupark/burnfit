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
import 'brand_marks.dart';

/// 비밀번호 재설정 메일 발송 시트. 로그인 화면과 탈퇴 확인 시트에서 함께 쓴다.
Future<void> showPasswordResetSheet(
  BuildContext context, {
  String? initialEmail,
}) {
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
  late final _emailController = TextEditingController(
    text: widget.initialEmail?.trim(),
  );
  bool _isSending = false;

  // 가입 여부를 알려주지 않도록 성공·미가입 모두 같은 문구를 쓴다.
  static const _sentMessage = '가입된 이메일이라면 재설정 메일이 발송됩니다. 메일함을 확인해주세요.';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// 시트를 닫고 로그인 화면 위에 체크 토스트를 띄운다 (시안 Com-Login-ResetSent).
  void _closeWithToast() {
    final navigator = Navigator.of(context);
    final overlayContext = navigator.context;
    navigator.pop();
    AppFeedback.showSuccessSnackBar(overlayContext, _sentMessage);
  }

  Future<void> _send() async {
    if (_isSending || !_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);
    try {
      await AuthService.sendPasswordReset(_emailController.text);
      if (!mounted) return;
      _closeWithToast();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'user-not-found') {
        _closeWithToast();
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
          const AppBottomSheetHeader(
            title: '비밀번호 재설정',
            subtitle: '가입한 이메일로 비밀번호 재설정 링크를 보내드려요.',
            gap: 20,
          ),
          // 시안: 회색 상자 안 봉투가 날아갔다 돌아온다
          const ExcludeSemantics(child: EnvelopeMark()),
          const Gap(20),
          AppTextField(
            label: '이메일',
            hint: 'name@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            autofocus:
                widget.initialEmail == null || widget.initialEmail!.isEmpty,
          ),
          const Gap(AppSpacing.xl),
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

/// '비밀번호를 잊으셨나요?' 글자 링크 (시안 Com-Login·Com-DeleteAccount):
/// 오른쪽 끝에 붙은 44 높이, 14/400 mute. 누를 수 없으면 faint.
class ForgotPasswordLink extends StatelessWidget {
  final VoidCallback? onPressed;

  const ForgotPasswordLink({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          onTap: onPressed,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: AppSize.touchMin,
            child: Center(
              widthFactor: 1,
              child: Text(
                '비밀번호를 잊으셨나요?',
                style: AppTextStyles.fieldLabel.copyWith(
                  color: enabled ? AppColors.mute : AppColors.faint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
