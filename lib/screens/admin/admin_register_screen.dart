import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../models/center.dart' as center_model;
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_screen_header.dart';
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
      final cred = await AuthService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      const uuid = Uuid();
      final centerId = uuid.v4();
      final now = DateTime.now();

      final center = center_model.Center(
        id: centerId,
        name: _centerNameController.text.trim(),
        address: _centerAddressController.text.trim().isEmpty
            ? null
            : _centerAddressController.text.trim(),
        adminId: cred.user!.uid,
        status: 'active',
        createdAt: now,
      );

      final admin = AppUser(
        uid: cred.user!.uid,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        role: UserRole.admin,
        status: UserStatus.approved,
        centerId: centerId,
        centerName: center.name,
        createdAt: now,
        updatedAt: now,
      );

      await FirestoreService.createAdmin(admin: admin, center: center);

      if (!mounted) return;
      context.read<UserProvider>().setUser(admin);
      Navigator.of(context).pushReplacementNamed(AppRoutes.adminHome);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '가입 중 오류가 발생했습니다. 다시 시도해주세요.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textOnAccent,
            ),
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            0,
            AppSpacing.screenH,
            AppSpacing.md,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.base,
                AppSpacing.screenH,
                0,
              ),
              child: AppScreenHeader(
                title: '관리자 등록',
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
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
                      Text(
                        '관리자 정보',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                      const Gap(AppSpacing.sm),
                      AppTextField(
                        label: '이름',
                        hint: '이름을 입력해주세요',
                        controller: _nameController,
                        validator: Validators.name,
                        textInputAction: TextInputAction.next,
                        fillColor: AppColors.card,
                        showEnabledBorder: true,
                        labelAbove: true,
                      ).animate().fadeIn(delay: 50.ms, duration: 300.ms),
                      const Gap(AppSpacing.sm),
                      AppTextField(
                        label: '이메일',
                        hint: 'example@email.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                        textInputAction: TextInputAction.next,
                        fillColor: AppColors.card,
                        showEnabledBorder: true,
                        labelAbove: true,
                      ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
                      const Gap(AppSpacing.sm),
                      AppTextField(
                        label: '비밀번호',
                        hint: '비밀번호를 입력해주세요',
                        controller: _passwordController,
                        obscureText: true,
                        validator: Validators.password,
                        textInputAction: TextInputAction.next,
                        fillColor: AppColors.card,
                        showEnabledBorder: true,
                        labelAbove: true,
                      ).animate().fadeIn(delay: 110.ms, duration: 300.ms),
                      const Gap(AppSpacing.sm),
                      AppTextField(
                        label: '설정 코드',
                        hint: '관리자 설정 코드를 입력해주세요',
                        controller: _codeController,
                        validator: (v) => Validators.adminCode(
                          v,
                          AppConstants.adminSetupCode,
                        ),
                        textInputAction: TextInputAction.next,
                        fillColor: AppColors.card,
                        showEnabledBorder: true,
                        labelAbove: true,
                      ).animate().fadeIn(delay: 140.ms, duration: 300.ms),
                      const Gap(AppSpacing.xl),

                      Text(
                        '센터 정보',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ).animate().fadeIn(delay: 170.ms, duration: 300.ms),
                      const Gap(AppSpacing.sm),
                      AppTextField(
                        label: '센터 이름',
                        hint: '센터 이름을 입력해주세요',
                        controller: _centerNameController,
                        validator: (v) => Validators.required(v, '센터 이름'),
                        textInputAction: TextInputAction.next,
                        fillColor: AppColors.card,
                        showEnabledBorder: true,
                        labelAbove: true,
                      ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                      const Gap(AppSpacing.sm),
                      AppTextField(
                        label: '주소 (선택)',
                        hint: '주소를 입력해주세요',
                        controller: _centerAddressController,
                        textInputAction: TextInputAction.done,
                        fillColor: AppColors.card,
                        showEnabledBorder: true,
                        labelAbove: true,
                      ).animate().fadeIn(delay: 230.ms, duration: 300.ms),
                      const Gap(AppSpacing.xl2),
                      AppButton(
                        label: '등록',
                        onPressed: _register,
                        isLoading: _isLoading,
                        fullWidth: true,
                        size: AppButtonSize.lg,
                      ).animate().fadeIn(delay: 260.ms, duration: 300.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
