import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../models/user.dart';
import '../../services/admin_setup_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_text_field.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _centerNameController = TextEditingController();
  final _centerAddressController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _centerNameController.dispose();
    _centerAddressController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final address = _centerAddressController.text.trim();
      await AdminSetupService.registerCenterAdmin(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        centerName: _centerNameController.text.trim(),
        centerAddress: address.isEmpty ? null : address,
        setupCode: _codeController.text.trim(),
      );
      if (!mounted) return;

      final userProvider = context.read<UserProvider>();
      await userProvider.loadUser();
      if (!mounted) return;

      if (userProvider.user?.role != UserRole.admin) {
        // 서버 문서가 아직 보이지 않는 등 예외 상황: 로그인부터 다시 시작한다.
        await userProvider.signOut();
        if (!mounted) return;
        _returnToLogin('가입이 완료되었습니다. 로그인해주세요.');
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.adminHome,
        (_) => false,
      );
    } on AdminRegisteredButSignInFailed {
      if (!mounted) return;
      _returnToLogin('가입이 완료되었습니다. 로그인해주세요.');
    } on Exception catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _returnToLogin(String message) {
    AppFeedback.showSuccessSnackBar(context, message);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: AppScreenHeader(
                title: '관리자 등록',
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            const AppRowDivider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xl,
                  AppSpacing.screenH,
                  AppSpacing.xl2,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionHeader(title: '관리자 정보'),
                      const Gap(AppSpacing.base),
                      AppTextField(
                        label: '이름',
                        hint: '이름을 입력해주세요',
                        controller: _nameController,
                        validator: Validators.name,
                        textInputAction: TextInputAction.next,
                      ),
                      const Gap(AppSpacing.base),
                      AppTextField(
                        label: '이메일',
                        hint: 'example@email.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                        textInputAction: TextInputAction.next,
                      ),
                      const Gap(AppSpacing.base),
                      AppTextField(
                        label: '비밀번호',
                        hint: '8자 이상 입력해주세요',
                        controller: _passwordController,
                        obscureText: true,
                        validator: (v) => Validators.password(
                          v,
                          minLength: AdminSetupService.passwordMinLength,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const Gap(AppSpacing.base),
                      AppTextField(
                        label: '설정 코드',
                        hint: '관리자 설정 코드를 입력해주세요',
                        controller: _codeController,
                        obscureText: true,
                        validator: (v) => Validators.required(v, '설정 코드'),
                        textInputAction: TextInputAction.next,
                      ),
                      const Gap(AppSpacing.xl2),
                      const AppSectionHeader(title: '센터 정보'),
                      const Gap(AppSpacing.base),
                      AppTextField(
                        label: '센터 이름',
                        hint: '센터 이름을 입력해주세요',
                        controller: _centerNameController,
                        validator: (v) => Validators.required(v, '센터 이름'),
                        textInputAction: TextInputAction.next,
                      ),
                      const Gap(AppSpacing.base),
                      AppTextField(
                        label: '주소 (선택)',
                        hint: '주소를 입력해주세요',
                        controller: _centerAddressController,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 주 행동: 아래 고정 pill 하나
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.base,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: AppButton(
                label: '등록',
                onPressed: _register,
                isLoading: _isLoading,
                fullWidth: true,
                size: AppButtonSize.lg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
