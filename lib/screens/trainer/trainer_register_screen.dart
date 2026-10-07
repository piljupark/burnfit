import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../models/center.dart' as center_model;
import '../../models/user.dart';
import '../../services/registration_service.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/orb_loader.dart';

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
      final user = await RegistrationService.register(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        role: UserRole.trainer,
        center: _selectedCenter!,
      );
      if (!mounted) return;
      context.read<UserProvider>().setUser(user);
      Navigator.of(context).pushReplacementNamed(AppRoutes.pendingApproval);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String msg) => AppFeedback.showWarning(context, msg);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: '트레이너 등록',
              onBack: () => Navigator.of(context).pop(),
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
                      const AppSectionHeader(title: '계정 정보'),
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
                        hint: '비밀번호를 입력해주세요',
                        controller: _passwordController,
                        obscureText: true,
                        validator: Validators.password,
                        textInputAction: TextInputAction.done,
                      ),
                      const Gap(AppSpacing.xl2),
                      const AppSectionHeader(title: '소속 센터'),
                      const Gap(AppSpacing.base),
                      AppTextField(
                        label: '센터 검색',
                        hint: '센터 이름을 입력해주세요',
                        controller: _searchController,
                        onChanged: _searchCenters,
                        prefix: const Icon(AppIcons.search),
                        suffix: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.only(right: AppSpacing.md),
                                child: OrbLoader.inline(
                                  semanticLabel: '센터 검색 중',
                                ),
                              )
                            : null,
                      ),
                      if (_selectedCenter != null) ...[
                        const Gap(AppSpacing.sm),
                        _SelectedCenter(
                          name: _selectedCenter!.name,
                          onClear: () => setState(() => _selectedCenter = null),
                        ),
                      ],
                      if (_searchResults.isNotEmpty &&
                          _selectedCenter == null) ...[
                        const Gap(AppSpacing.sm),
                        _CenterSearchResults(
                          results: _searchResults,
                          onSelect: (c) => setState(() {
                            _selectedCenter = c;
                            _searchResults = [];
                            _searchController.clear();
                          }),
                        ),
                      ],
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
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: AppButton(
                label: '가입 신청',
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

/// 선택된 센터: 입력창 모양(canvasSoft + hairline) + 체크 + 이름 + 해제 버튼.
class _SelectedCenter extends StatelessWidget {
  final String name;
  final VoidCallback onClear;

  const _SelectedCenter({required this.name, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.canvasSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Icon(AppIcons.checkCircle, size: AppSize.icon, color: AppColors.ink),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMd,
            ),
          ),
          AppIconButton(
            icon: AppIcons.close,
            label: '센터 선택 해제',
            color: AppColors.body,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

/// 센터 검색 결과: 화면 폭 목록 (hairline으로 나눔).
class _CenterSearchResults extends StatelessWidget {
  final List<center_model.Center> results;
  final ValueChanged<center_model.Center> onSelect;

  const _CenterSearchResults({required this.results, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in results) ...[
          Semantics(
            button: true,
            child: InkWell(
              onTap: () => onSelect(c),
              highlightColor: AppColors.canvasSoft,
              splashFactory: NoSplash.splashFactory,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.listRow),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: AppTextStyles.bodyLg),
                            if ((c.address ?? '').isNotEmpty)
                              Text(c.address!, style: AppTextStyles.bodySm),
                          ],
                        ),
                      ),
                      Icon(
                        AppIcons.forward,
                        size: AppSize.icon,
                        color: AppColors.mute,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const AppRowDivider(),
        ],
      ],
    );
  }
}
