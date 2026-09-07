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
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
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
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                                  child: AppEmptyState(
                                    icon: Icons.search_off_rounded,
                                    message: '검색 결과가 없습니다.',
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.screenH,
                                0,
                                AppSpacing.screenH,
                                AppSpacing.xl2,
                              ),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (_, i) {
                                final t = _filtered[i];
                                final initial = t.name.isNotEmpty
                                    ? t.name[0]
                                    : '?';
                                return Material(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  child: InkWell(
                                    onTap: () => _showTrainerDetail(t),
                                    splashColor: AppColors.brand
                                        .withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.card,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.lg,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0A000000),
                                            blurRadius: 8,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md,
                                          vertical: AppSpacing.sm + 2,
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
                                                style: AppTextStyles.label
                                                    .copyWith(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 15,
                                                      color: AppColors.trainer,
                                                    ),
                                              ),
                                            ),
                                            const Gap(AppSpacing.md),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    t.name,
                                                    style: AppTextStyles.label
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 15,
                                                        ),
                                                  ),
                                                  const Gap(AppSpacing.xxs),
                                                  Text(
                                                    t.email,
                                                    style: AppTextStyles.captionSmall
                                                        .copyWith(
                                                          color: AppColors
                                                              .textTertiary,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.trainer.withValues(
                          alpha: 0.16,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.trainer,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trainer.name, style: AppTextStyles.h3),
                          const Gap(AppSpacing.xxs),
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
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          _TrainerInfoRow(
                            label: '센터',
                            value: trainer.centerName,
                          ),
                          const Gap(AppSpacing.sm),
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
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    if (members.isEmpty)
                      AppEmptyState(
                        icon: Icons.people_outline_rounded,
                        message: '배정된 회원이 없습니다.',
                      )
                    else
                      ...members.map((member) {
                        final memberInitial = member.name.isNotEmpty
                            ? member.name[0]
                            : '?';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: AppColors.border,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.brand
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    memberInitial,
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.brand,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Gap(AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.name,
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Gap(AppSpacing.xxs),
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
                          ),
                        );
                      }),
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
        borderRadius: BorderRadius.circular(AppRadius.md),
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

class _TrainerInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _TrainerInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}
