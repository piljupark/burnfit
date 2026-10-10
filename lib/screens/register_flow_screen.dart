import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_feedback.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/constants.dart';
import '../core/validators.dart';
import '../models/center.dart' as center_model;
import '../models/user.dart';
import '../services/admin_setup_service.dart';
import '../services/center_search.dart';
import '../services/registration_service.dart';
import '../services/saved_account_store.dart';
import '../services/user_provider.dart';
import '../widgets/app_action_row.dart';
import '../widgets/app_button.dart';
import '../widgets/app_highlight.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/app_inputs.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_motion.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_parts.dart';
import '../widgets/center_list_row.dart';

enum _Step { role, center, account, confirm, openCenter }

/// 가입 (회원·트레이너·관리자 공통): 한 화면에 한 가지만 묻는 단계형.
///
/// - 회원·트레이너: 역할 → 센터 → 계정 → 확인 → (가입 신청) 승인 대기 화면
/// - 관리자: 역할 → 계정 → 센터 열기 → 관리자 홈
///
/// 단계를 오가도 넣은 값은 이 화면이 들고 있다. 뒤로(단추·제스처)는 앞 단계로,
/// 첫 단계에서만 로그인 화면으로 나간다. 가입 처리는 [RegistrationService]·[AdminSetupService]가 한다.
class RegisterFlowScreen extends StatefulWidget {
  const RegisterFlowScreen({super.key});

  @override
  State<RegisterFlowScreen> createState() => _RegisterFlowScreenState();
}

class _RegisterFlowScreenState extends State<RegisterFlowScreen> {
  _Step _step = _Step.role;
  UserRole? _role;

  final _accountFormKey = GlobalKey<FormState>();
  final _openFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _centerNameController = TextEditingController();
  final _centerAddressController = TextEditingController();
  final _searchController = TextEditingController();

  final _centerSearch = CenterSearch();
  List<center_model.Center> _centers = [];
  bool _centersLoading = false;
  bool _centersFailed = false;
  bool _centersLoaded = false;
  center_model.Center? _selectedCenter;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _centerNameController.dispose();
    _centerAddressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isAdmin => _role == UserRole.admin;

  /// 역할 다음 단계들 (진행 막대가 센다).
  List<_Step> get _flow => _isAdmin
      ? const [_Step.account, _Step.openCenter]
      : const [_Step.center, _Step.account, _Step.confirm];

  void _goTo(_Step step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    if (step == _Step.center && !_centersLoaded) _searchCenters('');
  }

  void _back() {
    if (_isLoading) return;
    if (_step == _Step.role) {
      Navigator.of(context).pop();
      return;
    }
    final index = _flow.indexOf(_step);
    _goTo(index <= 0 ? _Step.role : _flow[index - 1]);
  }

  void _pickRole(UserRole role) {
    _role = role;
    _goTo(_flow.first);
  }

  Future<void> _searchCenters(String query) async {
    setState(() => _centersLoading = true);
    try {
      final centers = await _centerSearch.search(query);
      // 입력이 그새 바뀌었으면 이 결과는 버린다 (최신 입력의 검색이 곧 반영된다).
      if (!mounted || query != _searchController.text) return;
      setState(() {
        _centers = centers;
        _centersFailed = false;
        _centersLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _centers = [];
        _centersFailed = true;
      });
    } finally {
      if (mounted) setState(() => _centersLoading = false);
    }
  }

  void _submitAccount() {
    if (!_accountFormKey.currentState!.validate()) return;
    _goTo(_isAdmin ? _Step.openCenter : _Step.confirm);
  }

  /// 회원·트레이너 가입 신청 → 승인 대기 화면.
  Future<void> _register() async {
    final center = _selectedCenter;
    final role = _role;
    if (_isLoading || center == null || role == null) return;
    setState(() => _isLoading = true);
    try {
      final user = await RegistrationService.register(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        role: role,
        center: center,
      );
      await SavedAccountStore.save(user);
      if (!mounted) return;
      context.read<UserProvider>().setUser(user);
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.pendingApproval, (_) => false);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 관리자: 계정과 센터를 서버 함수로 만든 뒤 관리자 홈으로.
  Future<void> _openCenter() async {
    if (_isLoading) return;
    if (!_openFormKey.currentState!.validate()) return;
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

      final user = userProvider.user;
      if (user == null || user.role != UserRole.admin) {
        // 서버 문서가 아직 보이지 않는 등 예외 상황: 로그인부터 다시 시작한다.
        await userProvider.signOut();
        if (!mounted) return;
        _returnToLogin('가입이 완료되었습니다. 로그인해주세요.');
        return;
      }
      await SavedAccountStore.save(user);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.adminHome, (_) => false);
    } on AdminRegisteredButSignInFailed {
      if (!mounted) return;
      _returnToLogin('가입이 완료되었습니다. 로그인해주세요.');
    } on Exception catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _returnToLogin(String message) {
    AppFeedback.showSuccessSnackBar(context, message);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final index = _flow.indexOf(_step);
    return PopScope(
      // 첫 단계에서만 화면을 닫는다. 나머지는 앞 단계로 (가입 처리 중에는 막는다).
      canPop: _step == _Step.role && !_isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(
                onBack: _back,
                current: _step == _Step.role ? null : index,
                total: _flow.length,
              ),
              Expanded(
                child: AppEntrance(
                  key: ValueKey(_step),
                  offset: const Offset(0, 12),
                  child: _body(),
                ),
              ),
              ?_bottom(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case _Step.role:
        return _RoleStep(
          onPick: _pickRole,
          onLogin: () => Navigator.of(context).pop(),
        );
      case _Step.center:
        return _centerStep();
      case _Step.account:
        return _scrollStep(
          title: '계정을 만들어요',
          subtitle: _isAdmin ? '센터를 열 관리자 계정이에요.' : '로그인할 때 쓸 이메일과 비밀번호예요.',
          child: Form(
            key: _accountFormKey,
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
                const Gap(AppSpacing.base),
                AppTextField(
                  label: '이메일',
                  hint: 'name@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  textInputAction: TextInputAction.next,
                ),
                const Gap(AppSpacing.base),
                AppTextField(
                  label: '비밀번호',
                  hint: '비밀번호',
                  controller: _passwordController,
                  obscureText: true,
                  showVisibilityToggle: true,
                  validator: Validators.password,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitAccount(),
                ),
                const Gap(6),
                _PasswordRule(controller: _passwordController),
              ],
            ),
          ),
        );
      case _Step.confirm:
        return _confirmStep();
      case _Step.openCenter:
        return _scrollStep(
          title: '센터를 열어요',
          subtitle: '받은 관리자 설정 코드가 있어야 열 수 있어요.',
          child: Form(
            key: _openFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: '관리자 설정 코드',
                  hint: '받은 코드를 입력해주세요',
                  controller: _codeController,
                  obscureText: true,
                  showVisibilityToggle: true,
                  validator: (v) => Validators.required(v, '설정 코드'),
                  textInputAction: TextInputAction.next,
                ),
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
                  label: '주소',
                  labelHint: '(선택)',
                  hint: '주소를 입력해주세요',
                  controller: _centerAddressController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _openCenter(),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget? _bottom() {
    switch (_step) {
      case _Step.role:
        return null;
      case _Step.center:
        return AppBottomActionBar(
          primaryLabel: '다음',
          onPrimary: _selectedCenter == null
              ? null
              : () => _goTo(_Step.account),
        );
      case _Step.account:
        return AppBottomActionBar(
          primaryLabel: '다음',
          onPrimary: _submitAccount,
        );
      case _Step.confirm:
        return AppBottomActionBar(
          primaryLabel: '가입 신청',
          onPrimary: _register,
          loading: _isLoading,
        );
      case _Step.openCenter:
        return AppBottomActionBar(
          primaryLabel: '센터 열기',
          onPrimary: _openCenter,
          loading: _isLoading,
        );
    }
  }

  /// 가운데 제목 + 입력 묶음, 스크롤 (계정·센터 열기)
  Widget _scrollStep({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xl2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(title: title, subtitle: subtitle),
          const Gap(AppSpacing.xl),
          child,
        ],
      ),
    );
  }

  Widget _centerStep() {
    final Widget list;
    if (_centersLoading && _centers.isEmpty) {
      list = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl2),
        child: Center(child: AppLoader.screen()),
      );
    } else if (_centersFailed) {
      list = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            Text(
              '센터 목록을 불러오지 못했어요.\n네트워크를 확인해주세요.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
            ),
            const Gap(AppSpacing.md),
            AppButton(
              label: '다시 시도',
              variant: AppButtonVariant.secondary,
              onPressed: () => _searchCenters(_searchController.text),
            ),
          ],
        ),
      );
    } else if (_centers.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl2),
        child: Text(
          '검색된 센터가 없습니다.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
        ),
      );
    } else {
      list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final center in _centers)
            CenterListRow(
              key: ValueKey(center.id),
              center: center,
              minHeight: 68,
              selected: center.id == _selectedCenter?.id,
              onTap: () => setState(() => _selectedCenter = center),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeading(
                title: _role == UserRole.trainer
                    ? '어느 센터에서 일하나요?'
                    : '어느 센터에 다니나요?',
                subtitle: '고른 센터의 관리자가 가입을 승인해요.',
              ),
              const Gap(AppSpacing.lg),
              AppTextField(
                label: '',
                hint: '센터 이름을 입력해주세요',
                controller: _searchController,
                onChanged: _searchCenters,
                textInputAction: TextInputAction.search,
                prefix: const Icon(AppIcons.search),
                suffix: _centersLoading && _centers.isNotEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(right: AppSpacing.md),
                        child: AppLoader.inline(semanticLabel: '센터 검색 중'),
                      )
                    : null,
              ),
            ],
          ),
        ),
        const Gap(AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.xl,
            ),
            child: Semantics(label: '센터 목록', container: true, child: list),
          ),
        ),
      ],
    );
  }

  Widget _confirmStep() {
    final center = _selectedCenter;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xl2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeading(title: '이대로 신청할까요?', subtitle: '줄을 누르면 고칠 수 있어요.'),
          const Gap(AppSpacing.xl),
          Container(
            decoration: BoxDecoration(
              color: AppColors.canvasCard,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SummaryRow(
                  label: '센터',
                  value: center?.name ?? '',
                  onTap: () => _goTo(_Step.center),
                ),
                _SummaryRow(
                  label: '역할',
                  value: _role?.label ?? '',
                  onTap: () => _goTo(_Step.role),
                  divider: true,
                ),
                _SummaryRow(
                  label: '이름',
                  value: _nameController.text.trim(),
                  onTap: () => _goTo(_Step.account),
                  divider: true,
                ),
                _SummaryRow(
                  label: '이메일',
                  value: _emailController.text.trim(),
                  onTap: () => _goTo(_Step.account),
                  divider: true,
                ),
              ],
            ),
          ),
          if (center != null) ...[
            const Gap(AppSpacing.base),
            AppInlineNotice(
              '${center.name} 관리자가 승인하면 바로 쓸 수 있어요.',
              warning: false,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 머리: 뒤로 44 + 진행 막대(단계 수만큼 4 높이 칸, 지난·지금 칸 주황) + 오른쪽 '1/3' 13 mute
// ─────────────────────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final VoidCallback onBack;

  /// 지금 단계 (0부터). null이면 막대를 그리지 않는다 (역할 고르기).
  final int? current;
  final int total;

  const _StepHeader({
    required this.onBack,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const Gap(AppSpacing.xs),
          AppIconButton(icon: AppIcons.back, label: '뒤로', onPressed: onBack),
          if (current != null) ...[
            const Gap(AppSpacing.xs),
            Expanded(
              child: Semantics(
                label: '$total단계 중 ${current + 1}단계',
                excludeSemantics: true,
                child: Row(
                  children: [
                    for (var i = 0; i < total; i++) ...[
                      if (i > 0) const Gap(AppSpacing.xs),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= current
                                ? AppColors.primary
                                : AppColors.track,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 52,
              child: ExcludeSemantics(
                child: Text(
                  '${current + 1}/$total',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.counter,
                ),
              ),
            ),
            const Gap(AppSpacing.screenH),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 역할 고르기: 가운데 제목 → 역할 줄 세 개(아이콘 상자 + 이름 + 하는 일) → 아래 '이미 계정이 있어요 · 로그인'
// ─────────────────────────────────────────────────────────────────────────────

class _RoleStep extends StatelessWidget {
  final ValueChanged<UserRole> onPick;
  final VoidCallback onLogin;

  const _RoleStep({required this.onPick, required this.onLogin});

  static const _roles = [
    (
      role: UserRole.member,
      icon: AppIcons.profile,
      desc: '센터에 다니며 운동·식단을 기록해요',
    ),
    (role: UserRole.trainer, icon: AppIcons.workout, desc: '센터에서 회원 PT를 맡아요'),
    (role: UserRole.admin, icon: AppIcons.center, desc: '센터를 새로 열고 관리해요'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                  child: AuthHeading(
                    title: '어떤 계정을 만들까요?',
                    subtitle: '역할마다 가입하는 순서가 조금 달라요.',
                  ),
                ),
                const Gap(AppSpacing.lg),
                for (var i = 0; i < _roles.length; i++) ...[
                  if (i > 0) const AppRowDivider.inset(),
                  AppEntrance(
                    offset: const Offset(0, 8),
                    duration: const Duration(milliseconds: 400),
                    delay: Duration(milliseconds: 50 * (i + 1)),
                    child: AppActionRow(
                      icon: _roles[i].icon,
                      label: _roles[i].role.label,
                      subtitle: _roles[i].desc,
                      onTap: () => onPick(_roles[i].role),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        AuthTextLink(lead: '이미 계정이 있어요', action: '로그인', onTap: onLogin),
        Gap(bottomInset > AppSpacing.sm ? bottomInset : AppSpacing.sm),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 확인 카드 한 줄: 56 · 라벨 15 body(폭 52) · 값 16/500 · 화살표 18 chevron, 위 줄과 사이 선
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool divider;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.divider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $value. 고치기',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            border: divider
                ? Border(top: BorderSide(color: AppColors.line))
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  label,
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.listTitle,
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

// ─────────────────────────────────────────────────────────────────────────────
// 비밀번호 규칙 줄: 치는 대로 '8자 이상 · 지금 5자' → 넘으면 검정 체크 + '8자 이상'
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordRule extends StatelessWidget {
  final TextEditingController controller;

  const _PasswordRule({required this.controller});

  @override
  Widget build(BuildContext context) {
    const min = Validators.passwordMinLength;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final length = value.text.length;
        final ok = length >= min;
        final color = ok ? AppColors.ink : AppColors.mute;
        return Row(
          children: [
            SizedBox.square(
              dimension: 14,
              child: ok
                  ? Icon(AppIcons.checkBold, size: 14, color: color)
                  : Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            ),
            const Gap(6),
            Text(
              ok ? '$min자 이상' : '$min자 이상 · 지금 $length자',
              style: AppTextStyles.bodySm.copyWith(color: color),
            ),
          ],
        );
      },
    );
  }
}
