import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
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
import '../../models/join_request.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_text_field.dart';

class MemberRegisterScreen extends StatefulWidget {
  const MemberRegisterScreen({super.key});

  @override
  State<MemberRegisterScreen> createState() => _MemberRegisterScreenState();
}

class _MemberRegisterScreenState extends State<MemberRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _searchController = TextEditingController();

  center_model.Center? _selectedCenter;
  List<center_model.Center> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchCenters(String q) async {
    if (q.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await FirestoreService.searchCenters(q.trim());
      if (!mounted) return;
      setState(() => _searchResults = results);
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCenter == null) {
      _showError('센터를 선택해주세요.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await AuthService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      const uuid = Uuid();
      final now = DateTime.now();
      final user = AppUser(
        uid: cred.user!.uid,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        role: UserRole.member,
        status: UserStatus.pending,
        centerId: _selectedCenter!.id,
        centerName: _selectedCenter!.name,
        createdAt: now,
        updatedAt: now,
      );
      final request = JoinRequest(
        id: uuid.v4(),
        userId: user.uid,
        userName: user.name,
        userEmail: user.email,
        centerId: _selectedCenter!.id,
        centerName: _selectedCenter!.name,
        role: 'member',
        status: JoinRequestStatus.pending,
        createdAt: now,
      );
      await FirestoreService.saveUser(user);
      await FirestoreService.createJoinRequest(request);
      if (!mounted) return;
      context.read<UserProvider>().setUser(user);
      Navigator.of(context).pushReplacementNamed(AppRoutes.pendingApproval);
    } on Exception {
      if (!mounted) return;
      _showError('가입 중 오류가 발생했습니다. 다시 시도해주세요.');
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
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textOnAccent,
          ),
        ),
        backgroundColor: AppColors.textNeutral,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.base,
                AppSpacing.screenH,
                0,
              ),
              child: AppScreenHeader(
                title: '회원가입',
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
                      // 섹션 제목 - 기본 정보
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
                        textInputAction: TextInputAction.done,
                        fillColor: AppColors.card,
                        showEnabledBorder: true,
                        labelAbove: true,
                      ).animate().fadeIn(delay: 110.ms, duration: 300.ms),
                      const Gap(AppSpacing.xl),

                      // 섹션 제목 - 센터 선택
                      const Gap(AppSpacing.sm),
                      AppTextField(
                        label: '센터 검색',
                        hint: '센터 이름을 입력해주세요',
                        controller: _searchController,
                        onChanged: _searchCenters,
                        fillColor: AppColors.card,
                        showEnabledBorder: true,
                        labelAbove: true,
                        prefix: const Icon(Iconsax.search_normal_1, size: 18, color: AppColors.textTertiary),
                        suffix: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.only(right: 14),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : null,
                      ).animate().fadeIn(delay: 170.ms, duration: 300.ms),
                      if (_selectedCenter != null) ...[
                        const Gap(AppSpacing.xs),
                        _SelectedCenterChip(
                          name: _selectedCenter!.name,
                          onClear: () => setState(() => _selectedCenter = null),
                        ),
                      ],
                      if (_searchResults.isNotEmpty && _selectedCenter == null) ...[
                        const Gap(AppSpacing.xs),
                        _CenterSearchResults(
                          results: _searchResults,
                          onSelect: (c) => setState(() {
                            _selectedCenter = c;
                            _searchResults = [];
                            _searchController.clear();
                          }),
                        ),
                      ],
                      const Gap(AppSpacing.xl2),
                      AppButton(
                        label: '가입 신청',
                        onPressed: _register,
                        isLoading: _isLoading,
                        fullWidth: true,
                        size: AppButtonSize.lg,
                      ).animate().fadeIn(delay: 220.ms, duration: 300.ms),
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

class _SelectedCenterChip extends StatelessWidget {
  final String name;
  final VoidCallback onClear;

  const _SelectedCenterChip({required this.name, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: AppColors.brand,
          ),
          const Gap(AppSpacing.xs),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.body.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterSearchResults extends StatelessWidget {
  final List<center_model.Center> results;
  final ValueChanged<center_model.Center> onSelect;

  const _CenterSearchResults({required this.results, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: results.length,
        separatorBuilder: (_, __) => const Divider(
          height: 0.5,
          thickness: 0.5,
          color: AppColors.border,
        ),
        itemBuilder: (_, i) {
          final c = results[i];
          final isFirst = i == 0;
          final isLast = i == results.length - 1;
          return InkWell(
            onTap: () => onSelect(c),
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(AppRadius.xs) : Radius.zero,
              bottom: isLast ? const Radius.circular(AppRadius.xs) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (c.address != null) ...[
                    const Gap(2),
                    Text(c.address!, style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
