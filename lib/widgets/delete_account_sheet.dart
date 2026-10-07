import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_feedback.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/constants.dart';
import '../models/user.dart';
import '../services/account_service.dart';
import '../services/user_provider.dart';
import 'app_bottom_sheet.dart';
import 'app_toast.dart';
import 'app_button.dart';
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
  AppToast.show(null, message: '탈퇴가 완료되었습니다. 그동안 이용해주셔서 감사합니다.');
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
          ),
          for (final line in _consequencesFor(widget.user.role))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '·  ',
                    style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (widget.user.role == UserRole.member) ...[
            const Gap(AppSpacing.xs),
            Text(
              'PT 이용 내역(횟수·기간·수업 일시)은 환불 등 분쟁 대응을 위해 이름 등 회원을 알 수 있는 정보를 지운 뒤 '
              'PT 종료일(또는 탈퇴일) 중 늦은 날로부터 ${AccountService.ptRecordRetentionYears}년간 보관하고 파기합니다.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
            ),
          ],
          const Gap(AppSpacing.xs),
          Text(
            '삭제된 정보는 복구할 수 없습니다.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.danger),
          ),
          const Gap(AppSpacing.lg),
          AppTextField(
            label: '비밀번호 확인',
            hint: '본인 확인을 위해 비밀번호를 입력해주세요',
            controller: _passwordController,
            obscureText: true,
            validator: (v) => (v == null || v.isEmpty) ? '비밀번호를 입력해주세요.' : null,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _delete(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: '비밀번호를 잊으셨나요?',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              onPressed: _isDeleting
                  ? null
                  : () => showPasswordResetSheet(
                      context,
                      initialEmail: widget.user.email,
                    ),
            ),
          ),
          const Gap(AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '취소',
                  variant: AppButtonVariant.ghost,
                  onPressed: _isDeleting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  fullWidth: true,
                  size: AppButtonSize.lg,
                ),
              ),
              const Gap(AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: '탈퇴하기',
                  variant: AppButtonVariant.danger,
                  onPressed: _delete,
                  isLoading: _isDeleting,
                  fullWidth: true,
                  size: AppButtonSize.lg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 마이 탭 맨 아래의 탈퇴 링크. 실수로 누르지 않게 눈에 덜 띄는 글자 버튼으로 둔다.
class DeleteAccountLink extends StatelessWidget {
  const DeleteAccountLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => startDeleteAccountFlow(context),
        child: Text(
          '회원 탈퇴',
          // 시안: 탈퇴는 로그아웃 아래 작은 밑줄 글자 (빨강은 확인 시트에서만)
          style: AppTextStyles.bodySm.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: AppColors.mute,
          ),
        ),
      ),
    );
  }
}
