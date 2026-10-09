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
import '../../widgets/app_calendar.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_text_field.dart';
import 'admin_member_detail_screen.dart';

/// 회원 목록 필터 (기준 시안 AdminMembers)
enum _MemberFilter { all, active, endingSoon, unassigned }

/// 회원 탭 (기준 시안 AdminMembers): '회원 128' 제목 → 48 검색창 → 칩(전체·PT 진행 중·곧 끝남·담당 없음)
/// → 68 줄(이름 · '이트레이너 · 12월 20일까지' · 오른쪽 'N회 남음').
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
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _members.where((m) {
        final matchesQuery =
            q.isEmpty ||
            m.name.toLowerCase().contains(q) ||
            m.email.toLowerCase().contains(q);
        return matchesQuery && _matchesFilterFor(_selectedFilter, m);
      }).toList();
    });
  }

  bool _matchesFilterFor(_MemberFilter filter, AppUser member) {
    final pt = _PtState.of(_ptInfoByMember[member.uid]);
    switch (filter) {
      case _MemberFilter.all:
        return true;
      case _MemberFilter.active:
        return pt.active;
      case _MemberFilter.endingSoon:
        return pt.endingSoon;
      case _MemberFilter.unassigned:
        return member.trainerId == null || member.trainerId!.isEmpty;
    }
  }

  void _changeFilter(int index) {
    setState(() => _selectedFilter = _MemberFilter.values[index]);
    _filter();
  }

  Future<void> _openDetail(AppUser m) async {
    await Navigator.of(context).push<AppUser>(
      MaterialPageRoute(builder: (_) => AdminMemberDetailScreen(member: m)),
    );
    // 상세에서 담당 트레이너·PT권을 바꿨을 수 있다 (뒤로 가기 방식과 관계없이) → 목록을 다시 불러온다.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppHero(
              title: '회원',
              count: _isLoading && _members.isEmpty
                  ? null
                  : '${_members.length}',
            ),
            // 검색 (시안: 48 · 반경 14 · 좌우 14 · 아이콘 20 mute)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
              ),
              child: AppTextField(
                label: '',
                hint: '이름으로 찾기',
                controller: _searchController,
                prefix: const Icon(AppIcons.search),
                dense: true,
                textInputAction: TextInputAction.search,
              ),
            ),
            // 필터 칩 (시안: 위 14 · 38 · 좌우 16 · 14)
            AppViewTabs(
              labels: const ['전체', 'PT 진행 중', '곧 끝남', '담당 없음'],
              selectedIndex: _selectedFilter.index,
              compact: true,
              scrollable: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                14 - 3, // pill 위 누름 자리(3)만큼 줄인다
                AppSpacing.screenH,
                0,
              ),
              onSelect: _changeFilter,
            ),
            // 목록
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _filtered.isEmpty,
                onRefresh: _load,
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm - 3,
                  bottom: AppSpacing.xl2,
                ),
                // 시안 Ad-Members-NoResult: 칩 아래 약 130 (본문 위 24 + 106)
                empty: AppEmptyState(
                  icon: AppIcons.members,
                  compact: true,
                  top: 106,
                  message: _members.isEmpty ? '등록된 회원이 없습니다.' : '검색 결과가 없습니다.',
                ),
                children: [
                  for (int i = 0; i < _filtered.length; i++)
                    // 시안 `fade`: 아래 8에서 .4s, 0.05초 간격 (화면 밖 줄은 늦게 기다리지 않게 10번째까지만)
                    AppEntrance(
                      key: ValueKey(_filtered[i].uid),
                      offset: const Offset(0, 8),
                      duration: const Duration(milliseconds: 400),
                      delay: Duration(milliseconds: 50 * (i < 10 ? i : 10)),
                      child: _MemberListItem(
                        member: _filtered[i],
                        ptInfo: _ptInfoByMember[_filtered[i].uid],
                        onTap: () => _openDetail(_filtered[i]),
                      ),
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

/// PT권 상태 (목록 필터·표시 공용). 날짜는 하루 단위로 비교한다.
class _PtState {
  final PtInfo? info;

  /// 종료일까지 남은 날 (종료일이 없으면 null)
  final int? daysLeft;

  const _PtState._(this.info, this.daysLeft);

  factory _PtState.of(PtInfo? info) {
    final end = info?.endDate;
    final today = DateUtils.dateOnly(DateTime.now());
    return _PtState._(
      info,
      end == null ? null : DateUtils.dateOnly(end).difference(today).inDays,
    );
  }

  bool get hasPt => info != null;

  /// 횟수를 다 썼거나 종료일이 지났다
  bool get finished =>
      info != null &&
      (info!.remainingSessions <= 0 || (daysLeft != null && daysLeft! < 0));

  bool get active => hasPt && !finished;

  /// 진행 중이면서 3회 이하 남았거나 14일 안에 끝난다
  bool get endingSoon =>
      active &&
      (info!.remainingSessions <= 3 || (daysLeft != null && daysLeft! <= 14));
}

// ── _MemberListItem ───────────────────────────────────────────────────────────

/// 회원 한 줄 (기준 시안 AdminMembers): 68 · 이름 16 Bold · '이트레이너 · 12월 20일까지' 13 mute ·
/// 오른쪽 15 Bold 'N회 남음'(1회 이하 noticeText) / 'PT 없음'(dots) / '기간 만료'(dots, 이름 faint).
class _MemberListItem extends StatelessWidget {
  final AppUser member;
  final PtInfo? ptInfo;
  final VoidCallback onTap;

  const _MemberListItem({
    required this.member,
    required this.ptInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pt = _PtState.of(ptInfo);
    final info = ptInfo;
    final expired = pt.daysLeft != null && pt.daysLeft! < 0;
    final hasTrainer = (member.trainerName ?? '').isNotEmpty;

    final meta = [
      hasTrainer ? member.trainerName! : '담당 없음',
      if (info?.endDate != null)
        '${DateFormat('M월 d일').format(info!.endDate!)}까지',
    ].join(' · ');

    final String status;
    final Color statusColor;
    if (info == null) {
      status = 'PT 없음';
      statusColor = AppColors.dots;
    } else if (expired) {
      status = '기간 만료';
      statusColor = AppColors.dots;
    } else {
      status = '${info.remainingSessions}회 남음';
      statusColor = info.remainingSessions <= 1
          ? AppColors.noticeText
          : AppColors.ink;
    }

    return AppListRow(
      title: member.name,
      subtitle: meta,
      bold: true,
      dimmed: expired,
      onTap: onTap,
      trailing: Text(
        status,
        style: AppTextStyles.bodyMd.bold.copyWith(color: statusColor),
      ),
    );
  }
}
