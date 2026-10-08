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
import '../../services/firestore_service.dart';
import '../../services/registration_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_loader.dart';

/// 가입 화면 공통 몸체 (회원가입·트레이너 등록).
/// 다른 점은 화면 제목과 가입 역할뿐이다.
///
/// 구성: 앱바 → '계정 정보' 묶음(이름·이메일·비밀번호) → 회색 띠 →
/// '소속 센터' 묶음(검색 + 결과/선택) → 아래 고정 '가입 신청' 버튼.
class RegisterForm extends StatefulWidget {
  final String title;
  final UserRole role;

  const RegisterForm({super.key, required this.title, required this.role});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
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
        role: widget.role,
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
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: widget.title,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 계정 정보 ─────────────────────────────────────
                      const AppMonthHeader(
                        label: '계정 정보',
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.screenH,
                          AppSpacing.base,
                          AppSpacing.screenH,
                          AppSpacing.sm,
                        ),
                      ),
                      _Inset(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              label: '이름',
                              hint: '이름을 입력해주세요',
                              controller: _nameController,
                              validator: Validators.name,
                              textInputAction: TextInputAction.next,
                            ),
                            const Gap(AppSpacing.md),
                            AppTextField(
                              label: '이메일',
                              hint: 'example@email.com',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                              textInputAction: TextInputAction.next,
                            ),
                            const Gap(AppSpacing.md),
                            AppTextField(
                              label: '비밀번호',
                              hint: '비밀번호를 입력해주세요',
                              controller: _passwordController,
                              obscureText: true,
                              validator: Validators.password,
                              textInputAction: TextInputAction.done,
                            ),
                          ],
                        ),
                      ),

                      // 묶음 사이 회색 띠
                      const Gap(AppSpacing.xl),
                      Container(
                        height: AppSpacing.sm,
                        color: AppColors.canvasSoft,
                      ),

                      // ── 소속 센터 ─────────────────────────────────────
                      const AppMonthHeader(label: '소속 센터'),
                      _Inset(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              label: '센터 검색',
                              hint: '센터 이름을 입력해주세요',
                              controller: _searchController,
                              onChanged: _searchCenters,
                              prefix: const Icon(AppIcons.search),
                              suffix: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.only(
                                        right: AppSpacing.md,
                                      ),
                                      child: AppLoader.inline(
                                        semanticLabel: '센터 검색 중',
                                      ),
                                    )
                                  : null,
                            ),
                            if (_selectedCenter != null) ...[
                              const Gap(AppSpacing.sm),
                              _SelectedCenter(
                                name: _selectedCenter!.name,
                                onClear: () =>
                                    setState(() => _selectedCenter = null),
                              ),
                            ],
                            if (_searchResults.isNotEmpty &&
                                _selectedCenter == null) ...[
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 주 행동: 아래 고정 버튼 하나 (키보드 위로 따라 올라온다.
            // 안전 영역 여백은 바가 스스로 둔다)
            AppBottomActionBar(
              primaryLabel: '가입 신청',
              onPrimary: _register,
              loading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

/// 화면 좌우 여백(20)만 두는 감싸개.
class _Inset extends StatelessWidget {
  final Widget child;

  const _Inset({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: child,
    );
  }
}

/// 선택된 센터: 회색 입력칸 모양 + 체크 + 이름 + 해제 버튼.
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
        borderRadius: BorderRadius.circular(AppRadius.field),
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
              style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w500),
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

/// 센터 검색 결과: 이름(500) + 주소 + 화살표, 줄 사이 hairline. 최소 높이 64.
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
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: AppTextStyles.bodyLg.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if ((c.address ?? '').isNotEmpty)
                              Text(c.address!, style: AppTextStyles.bodySm),
                          ],
                        ),
                      ),
                      Icon(AppIcons.forward, size: 18, color: AppColors.mute),
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
