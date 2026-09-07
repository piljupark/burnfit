import 'package:flutter/material.dart';
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
        const SnackBar(
          content: Text('가입 중 오류가 발생했습니다. 다시 시도해주세요.'),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.lg,
                    AppSpacing.screenH,
                    0,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: AppColors.border,
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Gap(AppSpacing.md),
                      Text('관리자 등록', style: AppTextStyles.h3),
                    ],
                  ),
                ),
                const Gap(AppSpacing.xl),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                      vertical: AppSpacing.md,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('관리자 정보', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                          const Gap(AppSpacing.xs),
                          AppTextField(
                            label: '이름',
                            controller: _nameController,
                            validator: Validators.name,
                            textInputAction: TextInputAction.next,
                          ),
                          const Gap(AppSpacing.md),
                          AppTextField(
                            label: '이메일',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.email,
                            textInputAction: TextInputAction.next,
                          ),
                          const Gap(AppSpacing.md),
                          AppTextField(
                            label: '비밀번호',
                            controller: _passwordController,
                            obscureText: true,
                            validator: Validators.password,
                            textInputAction: TextInputAction.next,
                          ),
                          const Gap(AppSpacing.md),
                          AppTextField(
                            label: '설정 코드',
                            controller: _codeController,
                            validator: (v) => Validators.adminCode(
                              v,
                              AppConstants.adminSetupCode,
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const Gap(AppSpacing.xl),
                          Text('센터 정보', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                          const Gap(AppSpacing.xs),
                          AppTextField(
                            label: '센터 이름',
                            controller: _centerNameController,
                            validator: (v) => Validators.required(v, '센터 이름'),
                            textInputAction: TextInputAction.next,
                          ),
                          const Gap(AppSpacing.md),
                          AppTextField(
                            label: '주소 (선택)',
                            controller: _centerAddressController,
                            textInputAction: TextInputAction.done,
                          ),
                          const Gap(AppSpacing.xl),
                          AppButton(
                            label: '등록',
                            onPressed: _register,
                            isLoading: _isLoading,
                            fullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
