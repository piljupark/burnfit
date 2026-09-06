import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_info.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_filter_tabs.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import 'admin_member_detail_screen.dart';

enum _MemberFilter { all, unassigned, lowPt, expiring }

class AdminMemberListScreen extends StatefulWidget {
  const AdminMemberListScreen({super.key});

  @override
  State<AdminMemberListScreen> createState() => _AdminMemberListScreenState();
}

class _AdminMemberListScreenState extends State<AdminMemberListScreen> {
  List<AppUser> _members = [];
  List<AppUser> _filtered = [];
  Map<String, PtInfo> _ptInfoByMember = {};
  _MemberFilter _selectedFilter = _MemberFilter.all;
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
      final results = await Future.wait([
        FirestoreService.getUsersByCenter(user.centerId),
        FirestoreService.getPtInfosByCenter(user.centerId),
      ]);
      if (!mounted) return;
      final list = results[0] as List<AppUser>;
      final ptInfos = results[1] as List<PtInfo>;
      final members = list.where((u) => u.role == UserRole.member).toList();
      setState(() {
        _members = members;
        _ptInfoByMember = {for (final info in ptInfos) info.memberId: info};
        _errorMessage = null;
      });
      _filter();
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
      _filtered = _members.where((m) {
        final matchesQuery =
            q.isEmpty ||
            m.name.toLowerCase().contains(q) ||
            m.email.toLowerCase().contains(q) ||
            (m.trainerName?.toLowerCase().contains(q) ?? false);
        return matchesQuery && _matchesFilter(m);
      }).toList();
    });
  }

  bool _matchesFilter(AppUser member) {
    return _matchesFilterFor(_selectedFilter, member);
  }

  bool _matchesFilterFor(_MemberFilter filter, AppUser member) {
    final info = _ptInfoByMember[member.uid];
    switch (filter) {
      case _MemberFilter.all:
        return true;
      case _MemberFilter.unassigned:
        return member.trainerId == null || member.trainerId!.isEmpty;
      case _MemberFilter.lowPt:
        return info != null &&
            info.remainingSessions > 0 &&
            info.remainingSessions <= 3;
      case _MemberFilter.expiring:
        final endDate = info?.endDate;
        if (endDate == null) return false;
        final today = DateTime.now();
        final day = DateTime(today.year, today.month, today.day);
        final diff = endDate.difference(day).inDays;
        return diff >= 0 && diff <= 14;
    }
  }

  void _changeFilter(int index) {
    setState(() => _selectedFilter = _MemberFilter.values[index]);
    _filter();
  }

  int _filterCount(_MemberFilter filter) {
    return _members.where((m) => _matchesFilterFor(filter, m)).length;
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
                title: '회원 관리',
                subtitle: '${_members.length}명',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                0,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AppFilterTabs(
                  tabs: [
                    '전체 ${_members.length}',
                    '미배정 ${_filterCount(_MemberFilter.unassigned)}',
                    '잔여부족 ${_filterCount(_MemberFilter.lowPt)}',
                    '만료예정 ${_filterCount(_MemberFilter.expiring)}',
                  ],
                  selectedIndex: _selectedFilter.index,
                  onChanged: _changeFilter,
                  icons: const [
                    Icons.people_outline_rounded,
                    Icons.person_off_outlined,
                    Icons.warning_amber_rounded,
                    Icons.event_busy_outlined,
                  ],
                ),
              ),
            ),
            const Gap(AppSpacing.sm),
            // 리스트
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
                          : _members.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.screenH),
                                child: AppEmptyState(
                                  icon: Icons.people_outline_rounded,
                                  message: '등록된 회원이 없습니다.',
                                ),
                              ),
                            )
                          : _filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.screenH),
                                child: AppEmptyState(
                                  icon: Icons.search_off_rounded,
                                  message: '검색 결과가 없습니다.',
                                ),
                              ),
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
                                  const SizedBox(height: 1),
                              itemBuilder: (_, i) {
                                final m = _filtered[i];
                                final ptInfo = _ptInfoByMember[m.uid];
                                final initial = m.name.isNotEmpty
                                    ? m.name[0]
                                    : '?';
                                return Material(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  child: InkWell(
                                    onTap: () async {
                                      final updated =
                                          await Navigator.of(
                                            context,
                                          ).push<AppUser>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AdminMemberDetailScreen(
                                                    member: m,
                                                  ),
                                            ),
                                          );
                                      if (updated == null || !context.mounted) {
                                        return;
                                      }
                                      setState(() {
                                        final idx = _members.indexWhere(
                                          (item) => item.uid == updated.uid,
                                        );
                                        if (idx != -1) {
                                          _members[idx] = updated;
                                        }
                                      });
                                      _filter();
                                    },
                                    splashColor: AppColors.brand
                                        .withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm + 2,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppColors.brand
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.sm,
                                                  ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              initial,
                                              style: AppTextStyles.body
                                                  .copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors
                                                        .brand,
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
                                                  m.name,
                                                  style: AppTextStyles.body
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                                const Gap(AppSpacing.xxs),
                                                Text(
                                                  m.trainerName != null
                                                      ? '담당: ${m.trainerName}'
                                                      : '트레이너 미배정',
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                ),
                                                if (ptInfo != null) ...[
                                                  const Gap(2),
                                                  Text(
                                                    'PT ${ptInfo.remainingSessions}/${ptInfo.totalSessions}회${_expiryLabel(ptInfo)}',
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                          color: _ptInfoTone(
                                                            ptInfo,
                                                          ),
                                                        ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            size: 16,
                                            color: AppColors.textDisabled,
                                          ),
                                        ],
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

  String _expiryLabel(PtInfo info) {
    final endDate = info.endDate;
    if (endDate == null) return '';
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final diff = endDate.difference(day).inDays;
    if (diff < 0) return ' · 만료';
    if (diff <= 14) return ' · D-$diff';
    return '';
  }

  Color _ptInfoTone(PtInfo info) {
    final label = _expiryLabel(info);
    if (label.contains('만료')) return AppColors.destructive;
    if (info.remainingSessions > 0 && info.remainingSessions <= 3) {
      return AppColors.diet;
    }
    if (label.isNotEmpty) return AppColors.diet;
    return AppColors.textSecondary;
  }
}
