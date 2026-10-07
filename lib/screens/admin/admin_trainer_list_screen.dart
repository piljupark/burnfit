import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_text_field.dart';

class AdminTrainerListScreen extends StatefulWidget {
  const AdminTrainerListScreen({super.key});

  @override
  State<AdminTrainerListScreen> createState() => _AdminTrainerListScreenState();
}

class _AdminTrainerListScreenState extends State<AdminTrainerListScreen> {
  List<AppUser> _trainers = [];
  List<AppUser> _filtered = [];
  bool _isLoading = false;
  String? _errorMessage;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final list = await FirestoreService.getTrainersByCenter(user.centerId);
      if (!mounted) return;
      setState(() {
        _trainers = list;
        _filtered = list;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _trainers
          : _trainers
                .where(
                  (t) =>
                      t.name.toLowerCase().contains(q) ||
                      t.email.toLowerCase().contains(q),
                )
                .toList();
    });
  }

  Future<void> _showTrainerDetail(AppUser trainer) async {
    try {
      final members = await FirestoreService.getMembersByTrainer(
        trainer.centerId,
        trainer.uid,
      );
      if (!mounted) return;
      await showAppBottomSheet<void>(
        context: context,
        child: _TrainerDetailSheet(trainer: trainer, members: members),
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 탭으로 열리면 AppHero, 메뉴에서 밀어 열리면 뒤로 버튼 앱바.
            if (canPop) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                child: AppScreenHeader(
                  title: '트레이너 관리',
                  subtitle: '${_trainers.length}명',
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              const AppRowDivider(),
            ] else
              const AppHero(title: '트레이너'),
            // 검색
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.base,
                AppSpacing.screenH,
                AppSpacing.base,
              ),
              child: AppTextField(
                label: '',
                hint: '이름 또는 이메일 검색',
                controller: _searchController,
                prefix: const Icon(AppIcons.search),
                textInputAction: TextInputAction.search,
              ),
            ),
            const AppRowDivider(),
            // 목록
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _filtered.isEmpty,
                onRefresh: _load,
                empty: AppEmptyState(
                  icon: AppIcons.trainers,
                  message: _trainers.isEmpty ? '등록된 트레이너가 없습니다.' : '검색 결과가 없습니다.',
                ),
                children: [
                  for (int i = 0; i < _filtered.length; i++) ...[
                    if (i > 0) const AppRowDivider(),
                    _TrainerListItem(
                      trainer: _filtered[i],
                      onTap: () => _showTrainerDetail(_filtered[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _TrainerListItem ──────────────────────────────────────────────────────────

/// 트레이너 한 줄: 아바타 + 이름 + 이메일 + (승인 대기면 "승인 대기" 태그) + 화살표.
class _TrainerListItem extends StatelessWidget {
  final AppUser trainer;
  final VoidCallback onTap;

  const _TrainerListItem({required this.trainer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                AppAvatar(name: trainer.name, seed: trainer.uid),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trainer.name, style: AppTextStyles.bodyLg, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(trainer.email, style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (!trainer.isApproved) ...[
                  const AppTag('승인 대기'),
                  const SizedBox(width: AppSpacing.sm),
                ],
                const Icon(AppIcons.forward, size: AppSize.icon, color: AppColors.mute),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── _TrainerDetailSheet ───────────────────────────────────────────────────────

/// 트레이너 상세 시트: 프로필 머리 + 키/값 줄 + 배정 회원 목록 (읽기 전용).
class _TrainerDetailSheet extends StatelessWidget {
  final AppUser trainer;
  final List<AppUser> members;

  const _TrainerDetailSheet({required this.trainer, required this.members});

  @override
  Widget build(BuildContext context) {
    final created = trainer.createdAt;
    final createdLabel =
        '${created.year}.${created.month.toString().padLeft(2, '0')}.${created.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 프로필 머리
        Row(
          children: [
            AppAvatar(name: trainer.name, seed: trainer.uid, size: 56),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(trainer.name, style: AppTextStyles.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const AppTag('트레이너'),
                    ],
                  ),
                  Text(
                    trainer.email,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(12, 0),
              child: AppIconButton(
                icon: AppIcons.close,
                label: '닫기',
                color: AppColors.body,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        const AppRowDivider(),
        _SheetInfoRow(label: '배정 회원', value: '${members.length}명'),
        const AppRowDivider(),
        _SheetInfoRow(label: '상태', value: trainer.isApproved ? '승인' : '승인 대기'),
        const AppRowDivider(),
        _SheetInfoRow(label: '센터', value: trainer.centerName),
        const AppRowDivider(),
        _SheetInfoRow(label: '등록일', value: createdLabel),
        const AppRowDivider(),
        // 배정 회원
        AppMonthHeader(
          label: '배정 회원',
          count: '${members.length}',
          padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
        ),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text('배정된 회원이 없습니다.', style: AppTextStyles.bodyMd.copyWith(color: AppColors.body)),
          )
        else
          for (int i = 0; i < members.length; i++) ...[
            if (i > 0) const AppRowDivider(),
            _MemberRowItem(member: members[i]),
          ],
      ],
    );
  }
}

// ── _MemberRowItem ────────────────────────────────────────────────────────────

class _MemberRowItem extends StatelessWidget {
  final AppUser member;

  const _MemberRowItem({required this.member});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            AppAvatar(name: member.name, seed: member.uid, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name, style: AppTextStyles.bodyMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    member.email,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SheetInfoRow ─────────────────────────────────────────────────────────────

/// 시트 안 키/값 줄 (높이 52). 카드 면 위이므로 라벨은 body 색.
class _SheetInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _SheetInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.body))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
