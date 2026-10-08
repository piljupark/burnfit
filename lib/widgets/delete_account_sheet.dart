import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_feedback.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/constants.dart';
import '../core/validators.dart';
import '../models/user.dart';
import '../services/account_service.dart';
import '../services/user_provider.dart';
import 'app_bottom_sheet.dart';
import 'app_confirm_dialog.dart';
import 'app_toast.dart';
import 'app_button.dart';
import 'app_motion.dart';
import 'app_text_field.dart';
import 'password_reset_sheet.dart';

/// 탈퇴 흐름 전체: 안내 → 비밀번호 확인 → 서버 삭제 → 로그인 화면.
/// 회원·트레이너 마이 탭이 이 함수 하나만 호출한다.
Future<void> startDeleteAccountFlow(BuildContext context) async {
  final user = context.read<UserProvider>().user;
  if (user == null || user.role == UserRole.admin) return;

  final navigator = Navigator.of(context);

  final deleted = await showAppBottomSheet<bool>(
    context: context,
    memberStyle: true,
    child: _DeleteAccountSheet(user: user),
  );
  if (deleted != true) return;

  navigator.pushNamedAndRemoveUntil(AppRoutes.memberLogin, (_) => false);
  AppToast.show(
    null,
    message: '탈퇴가 완료되었습니다. 그동안 이용해주셔서 감사합니다.',
    kind: AppToastKind.success,
  );
}

/// 역할별로 탈퇴하면 무엇이 어떻게 되는지. functions/account_deletion.js의 계획과 맞춘다.
List<String> _consequencesFor(UserRole role) {
  switch (role) {
    case UserRole.member:
      return const [
        '프로필과 계정 정보',
        '운동·식단·유산소 기록과 식단 사진, InBody 기록',
        '트레이너에게 받은 피드백',
      ];
    case UserRole.trainer:
      return const [
        '담당 회원은 모두 \'트레이너 미배정\'으로 바뀝니다',
        '예정된 PT는 취소되고 회원에게 취소 알림이 갑니다',
        '회원의 운동 기록과 남긴 피드백은 회원 쪽에 남습니다',
      ];
    case UserRole.admin:
      return const [];
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  final AppUser user;

  const _DeleteAccountSheet({required this.user});

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_isDeleting || !_formKey.currentState!.validate()) return;
    setState(() => _isDeleting = true);
    try {
      await context.read<UserProvider>().deleteAccount(
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTrainer = widget.user.role == UserRole.trainer;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBottomSheetHeader(
            title: '회원 탈퇴',
            subtitle: isTrainer
                ? '탈퇴하면 계정이 삭제되고 다음과 같이 처리됩니다.'
                : '탈퇴하면 아래 정보가 모두 삭제됩니다.',
            gap: 14,
          ),
          // 무엇이 어떻게 되는지: 회색 상자 안 점 목록, 줄 사이 1px line
          _ConsequenceList(
            lines: _consequencesFor(widget.user.role),
            multiline: isTrainer,
          ),
          if (widget.user.role == UserRole.member) ...[
            const Gap(AppSpacing.sm),
            _RetentionNotice(
              'PT 이용 내역(횟수·기간·수업 일시)은 환불 등 분쟁 대응을 위해 이름 등 회원을 알 수 있는 정보를 지운 뒤 '
              'PT 종료일(또는 탈퇴일) 중 늦은 날로부터 ${AccountService.ptRecordRetentionYears}년간 보관하고 파기합니다.',
            ),
          ],
          const Gap(AppSpacing.sm),
          const AppWarningCallout('삭제된 정보는 복구할 수 없습니다.'),
          const Gap(18),
          AppTextField(
            label: '비밀번호 확인',
            hint: '본인 확인을 위해 비밀번호를 입력해주세요',
            controller: _passwordController,
            obscureText: true,
            enabled: !_isDeleting,
            validator: Validators.existingPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _delete(),
          ),
          ForgotPasswordLink(
            onPressed: _isDeleting
                ? null
                : () => showPasswordResetSheet(
                    context,
                    initialEmail: widget.user.email,
                  ),
          ),
          const Gap(AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '취소',
                  variant: AppButtonVariant.secondary,
                  onPressed: _isDeleting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  fullWidth: true,
                  size: AppButtonSize.lg,
                  labelSize: 16,
                ),
              ),
              const Gap(AppSpacing.sm),
              Expanded(
                child: _isDeleting
                    ? const _DeletingButton()
                    : AppButton(
                        label: '탈퇴하기',
                        variant: AppButtonVariant.dark,
                        onPressed: _delete,
                        fullWidth: true,
                        size: AppButtonSize.lg,
                        labelSize: 16,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 결과 목록 (시안 Com-DeleteAccount-*): 회색 카드(반경 18, 안쪽 6 16) 안
/// 점(5, faint) + 15 ink 글자, 줄 사이 1px line. 회원은 한 줄 44, 트레이너는 위아래 12 · 줄 높이 1.45.
class _ConsequenceList extends StatelessWidget {
  final List<String> lines;
  final bool multiline;

  const _ConsequenceList({required this.lines, required this.multiline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++)
            Container(
              constraints: const BoxConstraints(minHeight: AppSize.touchMin),
              padding: EdgeInsets.symmetric(vertical: multiline ? 12 : 10),
              decoration: BoxDecoration(
                border: i < lines.length - 1
                    ? Border(bottom: BorderSide(color: AppColors.line))
                    : null,
              ),
              child: Row(
                crossAxisAlignment: multiline
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: multiline ? 9 : 0),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.faint,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      lines[i],
                      style: AppTextStyles.bodyMd.copyWith(
                        height: multiline ? 1.45 : null,
                      ),
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

/// PT 기록 보관 안내: 1px hairline 테두리 상자(반경 14, 안쪽 12 14) + 정보 아이콘 18 mute + 13 body(줄 높이 1.55).
class _RetentionNotice extends StatelessWidget {
  final String message;

  const _RetentionNotice(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(AppIcons.info, size: 18, color: AppColors.mute),
          ),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.body,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 탈퇴 중 버튼 (시안 Com-DeleteAccount-Trainer): 검정 56 · 반경 18 안 회전 원 22
/// (선 2.6, 바탕 흰색 25% + 흰 호, .8s에 한 바퀴).
class _DeletingButton extends StatefulWidget {
  const _DeletingButton();

  @override
  State<_DeletingButton> createState() => _DeletingButtonState();
}

class _DeletingButtonState extends State<_DeletingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '탈퇴하는 중',
      button: true,
      enabled: false,
      excludeSemantics: true,
      child: Container(
        height: AppSize.buttonHeightLg,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: RotationTransition(
          turns: _spin,
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              value: 0.25,
              strokeWidth: 2.6,
              strokeCap: StrokeCap.round,
              color: AppColors.canvas,
              backgroundColor: AppColors.canvas.withValues(alpha: 0.25),
            ),
          ),
        ),
      ),
    );
  }
}

/// 마이 탭 맨 아래의 탈퇴 링크. 실수로 누르지 않게 눈에 덜 띄는 글자 버튼으로 둔다.
/// [leading]이면 왼쪽 정렬 — 글자 시작을 화면 좌우 여백(20)에 맞춘다 (회원 마이, 시안 My).
class DeleteAccountLink extends StatelessWidget {
  final bool leading;

  const DeleteAccountLink({super.key, this.leading = false});

  @override
  Widget build(BuildContext context) {
    final link = TextButton(
      onPressed: () => startDeleteAccountFlow(context),
      style: leading
          ? TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
              ),
              alignment: Alignment.centerLeft,
            )
          : null,
      child: Text(
        '회원 탈퇴',
        // 시안: 탈퇴는 로그아웃 아래 작은 밑줄 글자 (빨강은 확인 시트에서만)
        style: AppTextStyles.bodySm.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: AppColors.mute,
        ),
      ),
    );
    if (leading) return Align(alignment: Alignment.centerLeft, child: link);
    return Center(child: link);
  }
}
