import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/constants.dart';
import '../core/validators.dart';
import '../models/center.dart' as center_model;
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/user_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import 'member/member_register_screen.dart';
import 'trainer/trainer_register_screen.dart';
import 'admin/admin_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _roleIndex = 0; // 0=회원 1=트레이너 2=관리자
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _centerSearchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  center_model.Center? _selectedCenter;
  bool _isLoading = false;

  static const _roles = [
    (label: '회원', role: 'member', icon: Icons.person_outline_rounded),
    (label: '트레이너', role: 'trainer', icon: Icons.fitness_center_rounded),
    (label: '관리자', role: 'admin', icon: Icons.manage_accounts_outlined),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _centerSearchController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCenter == null) {
      _showError('센터를 선택해주세요.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = await FirestoreService.getUser(cred.user!.uid);
      if (!mounted) return;

      if (user == null) {
        _showError('계정 정보를 찾을 수 없습니다.');
        await AuthService.signOut();
        return;
      }

      if (user.centerId != _selectedCenter!.id) {
        _showError('선택한 센터와 계정 정보가 일치하지 않습니다.');
        await AuthService.signOut();
        return;
      }

      if (user.role.name != _roles[_roleIndex].role) {
        _showError('올바른 로그인 경로를 선택해주세요.');
        await AuthService.signOut();
        return;
      }

      context.read<UserProvider>().setUser(user);

      if (user.status == UserStatus.pending) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.pendingApproval);
        return;
      }
      if (user.status == UserStatus.rejected) {
        _showError('가입이 거절된 계정입니다.');
        await AuthService.signOut();
        return;
      }

      switch (user.role) {
        case UserRole.admin:
          Navigator.of(context).pushReplacementNamed(AppRoutes.adminHome);
        case UserRole.trainer:
          Navigator.of(context).pushReplacementNamed(AppRoutes.trainerHome);
        case UserRole.member:
          if (user.birthDate == null) {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRoutes.onboardingBasic);
          } else {
            Navigator.of(context).pushReplacementNamed(AppRoutes.memberHome);
          }
      }
    } on Exception {
      if (!mounted) return;
      _showError('이메일 또는 비밀번호가 올바르지 않습니다.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textOnAccent),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          0,
          AppSpacing.screenH,
          AppSpacing.md,
        ),
      ),
    );
  }

  void _goRegister() {
    final screen = switch (_roleIndex) {
      0 => const MemberRegisterScreen(),
      1 => const TrainerRegisterScreen(),
      _ => const AdminRegisterScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openCenterPicker() async {
    _centerSearchController.clear();
    final selected = await showModalBottomSheet<center_model.Center>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CenterPickerSheet(controller: _centerSearchController),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedCenter = selected);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xl2,
            AppSpacing.screenH,
            AppSpacing.xl2 + bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 브랜드 영역
                Center(
                  child: const _BrandMark()
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: 0.08, curve: Curves.easeOut),
                ),
                const Gap(AppSpacing.xl2),

                // 역할 선택 타일
                Text(
                  '로그인 유형',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
                const Gap(AppSpacing.sm),
                Row(
                  children: List.generate(_roles.length, (i) {
                    final active = i == _roleIndex;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < _roles.length - 1 ? 8 : 0),
                        child: _RoleTile(
                          label: _roles[i].label,
                          icon: _roles[i].icon,
                          selected: active,
                          onTap: () => setState(() => _roleIndex = i),
                        ),
                      ),
                    );
                  }),
                ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
                const Gap(AppSpacing.base),

                // 센터 선택
                _CenterSelector(
                  centerName: _selectedCenter?.name,
                  onTap: _openCenterPicker,
                ).animate().fadeIn(delay: 160.ms, duration: 400.ms),
                const Gap(AppSpacing.sm),

                // 이메일
                AppTextField(
                  label: '이메일',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  textInputAction: TextInputAction.next,
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                const Gap(AppSpacing.sm),

                // 비밀번호
                AppTextField(
                  label: '비밀번호',
                  controller: _passwordController,
                  obscureText: true,
                  validator: Validators.password,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                ).animate().fadeIn(delay: 240.ms, duration: 400.ms),
                const Gap(AppSpacing.xl),

                // 로그인 버튼
                AppButton(
                  label: '로그인',
                  onPressed: _login,
                  isLoading: _isLoading,
                  fullWidth: true,
                  size: AppButtonSize.lg,
                ).animate().fadeIn(delay: 280.ms, duration: 400.ms),
                const Gap(AppSpacing.base),

                // 가입 링크
                Center(
                  child: GestureDetector(
                    onTap: _goRegister,
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.caption,
                        children: [
                          TextSpan(
                            text: '계정이 없으신가요?  ',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          TextSpan(
                            text: '가입하기',
                            style: TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 320.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 브랜드 마크
// ─────────────────────────────────────────────────────────────────────────────

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.local_fire_department_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const Gap(AppSpacing.md),
        Text(
          'BurnFit',
          style: AppTextStyles.h1,
        ),
        const Gap(AppSpacing.xxs),
        Text(
          '운동과 식단을 한 곳에서 기록하세요',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 역할 선택 타일
// ─────────────────────────────────────────────────────────────────────────────

class _RoleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppColors.brand : AppColors.textSecondary,
            ),
            const Gap(AppSpacing.xxs),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.brand : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 센터 선택
// ─────────────────────────────────────────────────────────────────────────────

class _CenterSelector extends StatelessWidget {
  final String? centerName;
  final VoidCallback onTap;

  const _CenterSelector({required this.centerName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                centerName ?? '센터 선택',
                style: AppTextStyles.body.copyWith(
                  color: centerName == null
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 센터 선택 바텀시트
// ─────────────────────────────────────────────────────────────────────────────

class _CenterPickerSheet extends StatefulWidget {
  final TextEditingController controller;

  const _CenterPickerSheet({required this.controller});

  @override
  State<_CenterPickerSheet> createState() => _CenterPickerSheetState();
}

class _CenterPickerSheetState extends State<_CenterPickerSheet> {
  List<center_model.Center> _centers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final centers = await FirestoreService.searchCenters(query.trim());
      if (!mounted) return;
      setState(() => _centers = centers);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xl + bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textDisabled,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const Gap(AppSpacing.base),
            Text('센터 선택', style: AppTextStyles.h3),
            const Gap(AppSpacing.md),
            AppTextField(
              label: '센터 검색',
              controller: widget.controller,
              onChanged: _search,
              textInputAction: TextInputAction.search,
            ),
            const Gap(AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _centers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          '검색된 센터가 없습니다.',
                          style: AppTextStyles.caption,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _centers.length,
                      separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final center = _centers[index];
                        return GestureDetector(
                          onTap: () => Navigator.of(context).pop(center),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.base),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x08000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  center.name,
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if ((center.address ?? '').isNotEmpty) ...[
                                  const Gap(AppSpacing.xxs),
                                  Text(
                                    center.address!,
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
