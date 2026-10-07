import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/pt_info.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_filter_tabs.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_text_field.dart';
import 'admin_member_detail_screen.dart';
import 'admin_requests_screen.dart';

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
        // 0회도 포함 (갱신이 가장 급한 회원)
        return info != null && info.remainingSessions <= 3;
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

  Future<void> _openDetail(AppUser m) async {
    await Navigator.of(context).push<AppUser>(
      MaterialPageRoute(builder: (_) => AdminMemberDetailScreen(member: m)),
    );
    // 상세에서 담당 트레이너·PT권을 바꿨을 수 있다 (뒤로 가기 방식과 관계없이) → 목록과 PT 칩을 다시 불러온다.
    if (mounted) await _load();
  }

  void _openRequests() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminRequestsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final requestsButton = AppIconButton(
      icon: AppIcons.userPlus,
      label: '가입 신청',
      onPressed: _openRequests,
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 탭으로 열리면 AppHero, 메뉴에서 밀어 열리면 뒤로 버튼 앱바.
            if (canPop) ...[
              AppScreenHeader(
                title: '회원 관리',
                subtitle: '${_members.length}명',
                onBack: () => Navigator.of(context).pop(),
                trailing: requestsButton,
              ),
            ] else
              AppHero(title: '회원', actions: [requestsButton]),
            // 검색
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.base,
                AppSpacing.screenH,
                0,
              ),
              child: AppTextField(
                label: '',
                hint: '이름 또는 이메일 검색',
                controller: _searchController,
                prefix: const Icon(AppIcons.search),
                textInputAction: TextInputAction.search,
              ),
            ),
            // 필터 칩
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: AppScrollableChips(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenH,
                ),
                labels: [
                  '전체 ${_members.length}',
                  '미배정 ${_filterCount(_MemberFilter.unassigned)}',
                  '잔여부족 ${_filterCount(_MemberFilter.lowPt)}',
                  '만료예정 ${_filterCount(_MemberFilter.expiring)}',
                ],
                selectedIndex: _selectedFilter.index,
                onSelected: _changeFilter,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppRowDivider(),
            // 목록
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _filtered.isEmpty,
                onRefresh: _load,
                empty: AppEmptyState(
                  icon: AppIcons.members,
                  message: _members.isEmpty ? '등록된 회원이 없습니다.' : '검색 결과가 없습니다.',
                ),
                children: [
                  for (int i = 0; i < _filtered.length; i++) ...[
                    if (i > 0) const AppRowDivider(),
                    _MemberListItem(
                      member: _filtered[i],
                      ptInfo: _ptInfoByMember[_filtered[i].uid],
                      onTap: () => _openDetail(_filtered[i]),
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

// ── _MemberListItem ───────────────────────────────────────────────────────────

/// 회원 한 줄: 아바타 + 이름 + (트레이너 · PT 잔여/전체) + 오른쪽 상태 태그.
/// 태그: 만료 = 만료(흐림, 이름도 흐림) · 미배정 = PT 없음 · 14일 이내 = D-n(흰 채움) · 그 외 D-n(외곽선).
class _MemberListItem extends StatelessWidget {
  final AppUser member;
  final PtInfo? ptInfo;
  final VoidCallback onTap;

  const _MemberListItem({
    required this.member,
    required this.ptInfo,
    required this.onTap,
  });

  int? get _daysLeft {
    final endDate = ptInfo?.endDate;
    if (endDate == null) return null;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    return endDate.difference(day).inDays;
  }

  bool get _unassigned => member.trainerId == null || member.trainerId!.isEmpty;

  @override
  Widget build(BuildContext context) {
    final days = _daysLeft;
    final expired = days != null && days < 0;
    final info = ptInfo;

    final meta = [
      member.trainerName ?? '트레이너 미배정',
      if (expired)
        '만료 ${DateFormat('M월 d일').format(info!.endDate!)}'
      else if (info != null)
        'PT ${info.remainingSessions}/${info.totalSessions}',
    ].join(' · ');

    final Widget? tag = expired
        ? const AppTag('만료', muted: true)
        : _unassigned
        ? const AppTag('PT 없음')
        : days != null
        ? AppTag('D-$days', strong: days <= 14)
        : null;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.listRow),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: AppTextStyles.bodyLg.copyWith(
                          color: expired ? AppColors.mute : AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        meta,
                        style: AppTextStyles.bodySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (tag != null) ...[const SizedBox(width: AppSpacing.sm), tag],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
