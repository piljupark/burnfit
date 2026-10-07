import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';

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
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TrainerDetailSheet(trainer: trainer, members: members),
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                0,
              ),
              child: AppScreenHeader(
                title: '트레이너 관리',
                subtitle: '${_trainers.length}명',
                onBack: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).pop()
                    : null,
              ),
            ),
            // 검색바
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                0,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.textDisabled,
                    ),
                    const Gap(AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: AppTextStyles.body,
                        decoration: InputDecoration.collapsed(
                          hintText: '이름 또는 이메일 검색',
                          hintStyle: AppTextStyles.body.copyWith(
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(AppSpacing.sm),
            // 바디
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.brand,
                      backgroundColor: AppColors.card,
                      child: _errorMessage != null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 120),
                                AppErrorCard(
                                  message: _errorMessage!,
                                  onRetry: _load,
                                ),
                              ],
                            )
                          : _trainers.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(top: AppSpacing.xl),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.screenH,
                                  ),
                                  child: AppEmptyState(
                                    icon: Icons.fitness_center_outlined,
                                    message: '등록된 트레이너가 없습니다.',
                                  ),
                                ),
                              ],
                            )
                          : _filtered.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(top: AppSpacing.xl),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.screenH,
                                  ),
                                  child: AppEmptyState(
                                    icon: Icons.search_off_rounded,
                                    message: '검색 결과가 없습니다.',
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.screenH,
                                0,
                                AppSpacing.screenH,
                                AppSpacing.xl2,
                              ),
                              children: [
                                // 전체 리스트를 하나의 흰 카드로 감싸기
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(AppRadius.xs),
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadius.xs),
                                    child: Column(
                                      children: [
                                        for (int i = 0; i < _filtered.length; i++) ...[
                                          _TrainerListItem(
                                            trainer: _filtered[i],
                                            onTap: () => _showTrainerDetail(_filtered[i]),
                                          ),
                                          if (i < _filtered.length - 1)
                                            const Divider(
                                              height: 1,
                                              color: AppColors.border,
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _TrainerListItem ──────────────────────────────────────────────────────────

class _TrainerListItem extends StatelessWidget {
  final AppUser trainer;
  final VoidCallback onTap;

  const _TrainerListItem({
    required this.trainer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = trainer.name.isNotEmpty ? trainer.name[0] : '?';

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.trainer.withValues(alpha: 0.05),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // 48x48 원형 아바타
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.trainer.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: AppTextStyles.headline.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.trainer,
                ),
              ),
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름 (headline)
                  Text(
                    trainer.name,
                    style: AppTextStyles.headline,
                  ),
                  const Gap(3),
                  // 이메일 (caption, textSecondary)
                  Text(
                    trainer.email,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 우측 화살표
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _TrainerDetailSheet ───────────────────────────────────────────────────────

class _TrainerDetailSheet extends StatelessWidget {
  final AppUser trainer;
  final List<AppUser> members;

  const _TrainerDetailSheet({required this.trainer, required this.members});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final initial = trainer.name.isNotEmpty ? trainer.name[0] : '?';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              // 트레이너 프로필 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.trainer.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: AppTextStyles.headline.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.trainer,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trainer.name,
                            style: AppTextStyles.headline,
                          ),
                          const Gap(2),
                          Text(
                            trainer.email,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textSecondary,
                      tooltip: '닫기',
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.sm,
                    AppSpacing.screenH,
                    AppSpacing.xl2,
                  ),
                  children: [
                    // KPI 타일 행
                    Row(
                      children: [
                        Expanded(
                          child: _TrainerMetricTile(
                            label: '배정 회원',
                            value: '${members.length}',
                            suffix: '명',
                          ),
                        ),
                        const Gap(AppSpacing.sm),
                        Expanded(
                          child: _TrainerMetricTile(
                            label: '상태',
                            value: trainer.isApproved ? '승인' : '대기',
                          ),
                        ),
                      ],
                    ),
                    const Gap(AppSpacing.sm),
                    // 기본 정보 카드
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Column(
                        children: [
                          _TrainerInfoRow(
                            label: '센터',
                            value: trainer.centerName,
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          _TrainerInfoRow(
                            label: '등록일',
                            value:
                                '${trainer.createdAt.year}.${trainer.createdAt.month.toString().padLeft(2, '0')}.${trainer.createdAt.day.toString().padLeft(2, '0')}',
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppSpacing.lg),
                    Text(
                      '배정 회원',
                      style: AppTextStyles.h3,
                    ),
                    const Gap(AppSpacing.sm),
                    if (members.isEmpty)
                      AppEmptyState(
                        icon: Icons.people_outline_rounded,
                        message: '배정된 회원이 없습니다.',
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          child: Column(
                            children: [
                              for (int i = 0; i < members.length; i++) ...[
                                _MemberRowItem(member: members[i]),
                                if (i < members.length - 1)
                                  const Divider(
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _MemberRowItem ────────────────────────────────────────────────────────────

class _MemberRowItem extends StatelessWidget {
  final AppUser member;

  const _MemberRowItem({required this.member});

  @override
  Widget build(BuildContext context) {
    final initial = member.name.isNotEmpty ? member.name[0] : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(2),
                Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _TrainerMetricTile ────────────────────────────────────────────────────────

class _TrainerMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;

  const _TrainerMetricTile({
    required this.label,
    required this.value,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(AppSpacing.xs),
          RichText(
            text: TextSpan(
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(text: value),
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _TrainerInfoRow ───────────────────────────────────────────────────────────

class _TrainerInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _TrainerInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
