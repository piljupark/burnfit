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
import '../../models/join_request.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class TrainerRegisterScreen extends StatefulWidget {
  const TrainerRegisterScreen({super.key});

  @override
  State<TrainerRegisterScreen> createState() => _TrainerRegisterScreenState();
}

class _TrainerRegisterScreenState extends State<TrainerRegisterScreen> {
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
        email: _emailController.text,
        password: _passwordController.text,
      );

      const uuid = Uuid();
      final now = DateTime.now();

      final user = AppUser(
        uid: cred.user!.uid,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        role: UserRole.trainer,
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
        role: 'trainer',
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
        content: Text(msg),
        backgroundColor: AppColors.destructive,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                      Text('트레이너 가입', style: AppTextStyles.h3),
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
                          Text('계정 정보', style: AppTextStyles.overline),
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
                          ),
                          const Gap(AppSpacing.xl),
                          Text('소속 센터', style: AppTextStyles.overline),
                          const Gap(AppSpacing.xs),
                          AppTextField(
                            label: '센터 검색',
                            hint: '센터 이름을 입력하세요 (2자 이상)',
                            controller: _searchController,
                            onChanged: _searchCenters,
                            suffix: _isSearching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                          ),
                          if (_selectedCenter != null) ...[
                            const Gap(AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm + 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color: AppColors.brand,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color: AppColors.brand,
                                  ),
                                  const Gap(AppSpacing.xxs),
                                  Expanded(
                                    child: Text(
                                      _selectedCenter!.name,
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.brand,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedCenter = null),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_searchResults.isNotEmpty &&
                              _selectedCenter == null) ...[
                            const Gap(AppSpacing.xs),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 0.5,
                                ),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),
                                itemBuilder: (_, i) {
                                  final c = _searchResults[i];
                                  return InkWell(
                                    onTap: () => setState(() {
                                      _selectedCenter = c;
                                      _searchResults = [];
                                      _searchController.clear();
                                    }),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm + 2,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: AppTextStyles.body.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (c.address != null)
                                            Text(
                                              c.address!,
                                              style: AppTextStyles.caption,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          const Gap(AppSpacing.xl),
                          AppButton(
                            label: '가입 신청',
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
