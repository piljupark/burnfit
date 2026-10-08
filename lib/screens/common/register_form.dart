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
import '../../widgets/app_motion.dart';

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
            AppScreenHeader.large(
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
                      const Gap(AppSpacing.sm),
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
                            const Gap(14),
                            AppTextField(
                              label: '이메일',
                              hint: 'example@email.com',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                              textInputAction: TextInputAction.next,
                            ),
                            const Gap(14),
                            AppTextField(
                              label: '비밀번호',
                              hint:
                                  '${Validators.passwordMinLength}자 이상 입력해주세요',
                              controller: _passwordController,
                              obscureText: true,
                              validator: Validators.password,
                              textInputAction: TextInputAction.done,
                            ),
                          ],
                        ),
                      ),

                      // 묶음 사이 회색 띠 (8, #F6F6F7)
                      const AppSectionBand(top: AppSpacing.xl),

                      // ── 소속 센터 ─────────────────────────────────────
                      const AppMonthHeader(
                        label: '소속 센터',
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.screenH,
                          AppSpacing.lg,
                          AppSpacing.screenH,
                          AppSpacing.sm,
                        ),
                      ),
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

/// 선택된 센터 (시안 Com-Register-Trainer): 56 높이 · 반경 14 · 회색 카드 면,
/// 22 검정 원 안 흰 체크(튀어나옴 `pop`) + 이름 16/500 + 해제(X 18 mute).
class _SelectedCenter extends StatelessWidget {
  final String name;
  final VoidCallback onClear;

  const _SelectedCenter({required this.name, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: [
          // 시안 `pop`: .45s, cubic-bezier(.3,1.3,.5,1), 0.4배·투명 → 1.15배 → 제자리
          TweenAnimationBuilder<double>(
            key: ValueKey(name),
            tween: Tween(begin: reduced ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: AppMotion.knob,
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
            ),
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.checkBold,
                size: 12,
                color: AppColors.canvas,
              ),
            ),
          ),
          const Gap(10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.listTitle,
            ),
          ),
          AppIconButton(
            icon: AppIcons.closeBold,
            label: '센터 선택 해제',
            iconSize: 18,
            color: AppColors.mute,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

/// 센터 검색 결과 (시안 Com-Register-Member): 이름 16/500 + 주소 13 mute(위 3) + 화살표 18,
/// 줄마다 아래 hairline, 최소 높이 64. 줄은 차례로 아래 8에서 올라온다 (`row`).
class _CenterSearchResults extends StatelessWidget {
  final List<center_model.Center> results;
  final ValueChanged<center_model.Center> onSelect;

  const _CenterSearchResults({required this.results, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < results.length; i++)
          AppEntrance(
            key: ValueKey(results[i].id),
            offset: const Offset(0, 8),
            duration: const Duration(milliseconds: 400),
            delay: Duration(milliseconds: 50 + 70 * i),
            child: _CenterResultRow(
              center: results[i],
              onTap: () => onSelect(results[i]),
            ),
          ),
      ],
    );
  }
}

class _CenterResultRow extends StatelessWidget {
  final center_model.Center center;
  final VoidCallback onTap;

  const _CenterResultRow({required this.center, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final address = center.address ?? '';
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(center.name, style: AppTextStyles.listTitle),
                    if (address.isNotEmpty) ...[
                      const Gap(3),
                      Text(address, style: AppTextStyles.bodySm),
                    ],
                  ],
                ),
              ),
              Icon(
                AppIcons.chevronRightBold,
                size: 18,
                color: AppColors.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
