import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../models/user.dart';
import '../../models/pt_info.dart';
import '../../models/pt_session.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_section.dart';
import '../../widgets/app_text_field.dart';
import 'admin_member_detail_screen.dart';
import '../../widgets/app_kpi_card.dart';

class AdminTrainerListScreen extends StatefulWidget {
  const AdminTrainerListScreen({super.key});

  @override
  State<AdminTrainerListScreen> createState() => AdminTrainerListScreenState();
}

class AdminTrainerListScreenState extends State<AdminTrainerListScreen> {
  /// 탭을 다시 열 때 (관리자 셸이 부른다)
  Future<void> refresh() => _load();

  List<AppUser> _trainers = [];
  List<AppUser> _filtered = [];
  bool _isLoading = false;
  bool _loadedOnce = false;
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
    // 처음에만 화면 전체를 로딩으로 바꾼다 (당겨서 새로고침·돌아와서 다시 불러올 때는 보이던 내용을 그대로 둔다).
    if (!_loadedOnce) setState(() => _isLoading = true);
    try {
      final list = await FirestoreService.getTrainersByCenter(user.centerId);
      if (!mounted) return;
      setState(() {
        _trainers = list;
        _filtered = list;
        _errorMessage = null;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (_loadedOnce) {
        // 이미 보이는 내용은 두고 알리기만 한다
        AppFeedback.showErrorSnackBar(context, e);
      } else {
        setState(() => _errorMessage = AppFeedback.errorMessage(e));
      }
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

  bool _openingDetail = false;

  Future<void> _showTrainerDetail(AppUser trainer) async {
    // 불러오는 동안 여러 번 눌러 시트가 겹쳐 열리지 않게 한다.
    if (_openingDetail) return;
    setState(() => _openingDetail = true);
    try {
      final now = DateTime.now();
      final (members, monthSessions) = await (
        FirestoreService.getMembersByTrainer(trainer.centerId, trainer.uid),
        FirestoreService.getPtSessionsByTrainer(
          trainer.centerId,
          trainer.uid,
          from: DateTime(now.year, now.month),
          // 조회는 끝 시각을 포함(<=)하므로 다음 달 1일 0시 직전까지
          to: DateTime(
            now.year,
            now.month + 1,
          ).subtract(const Duration(milliseconds: 1)),
        ),
      ).wait;
      // 배정 회원만 조회한다 (센터 전체 PT 정보를 읽지 않는다).
      final ptInfos = await Future.wait(
        members.map(
          (m) => FirestoreService.getPtInfo(m.uid, centerId: trainer.centerId),
        ),
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final opened = await showAppBottomSheet<AppUser>(
        context: context,
        child: _TrainerDetailSheet(
          trainer: trainer,
          members: members,
          ptInfos: {
            for (var i = 0; i < members.length; i++)
              if (ptInfos[i] != null) members[i].uid: ptInfos[i]!,
          },
          monthCompleted: monthSessions
              .where((s) => s.status == PtSessionStatus.completed)
              .length,
        ),
      );
      // 회원 줄을 누르면 시트를 닫고 회원 상세로 간다 (담당 변경은 거기서).
      if (opened != null) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => AdminMemberDetailScreen(member: opened),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _openingDetail = false);
    }
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
            const AppHero(title: '트레이너'),
            // 검색 (시안 Ad-Trainers: 48 · 좌우 14) → 위 16 화면 폭 선
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
              ),
              child: AppTextField(
                label: '',
                hint: '이름 또는 이메일 검색',
                controller: _searchController,
                prefix: const Icon(AppIcons.search),
                dense: true,
                textInputAction: TextInputAction.search,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            const AppRowDivider(),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _filtered.isEmpty,
                onRefresh: _load,
                padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
                empty: AppEmptyState(
                  icon: AppIcons.trainers,
                  compact: true,
                  top: 96,
                  message: _trainers.isEmpty
                      ? '등록된 트레이너가 없습니다.'
                      : '검색 결과가 없습니다.',
                ),
                children: [
                  for (int i = 0; i < _filtered.length; i++)
                    // 시안 `fade`: 아래 8에서 .4s, 0.05초 간격
                    AppEntrance(
                      key: ValueKey(_filtered[i].uid),
                      offset: const Offset(0, 8),
                      duration: const Duration(milliseconds: 400),
                      delay: Duration(milliseconds: 50 * (i < 10 ? i : 10)),
                      child: AppListRow(
                        title: _filtered[i].name,
                        subtitle: _filtered[i].email,
                        chevron: true,
                        onTap: () => _showTrainerDetail(_filtered[i]),
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

// ── _TrainerDetailSheet ───────────────────────────────────────────────────────

/// 트레이너 상세 시트 (시안 Ad-TrainerDetailSheet): 이름 22 · 14 mute '이메일 · 2025.03.02 등록' →
/// 2칸 숫자(배정 회원 · 이번 달 PT 완료) → '배정 회원 8명' → 60 회원 줄(13 body 'PT 7 / 20회 남음' ›).
/// 회원 줄을 누르면 시트를 닫고 그 회원을 돌려준다.
class _TrainerDetailSheet extends StatelessWidget {
  final AppUser trainer;
  final List<AppUser> members;
  final Map<String, PtInfo> ptInfos;
  final int monthCompleted;

  const _TrainerDetailSheet({
    required this.trainer,
    required this.members,
    required this.ptInfos,
    required this.monthCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final created = DateFormat('yyyy.MM.dd').format(trainer.createdAt);
    AppKpiCard kpi(String label, int value, String unit) => AppKpiCard(
      label: label,
      value: '$value',
      unit: unit,
      framed: false,
      valueSize: 24,
      labelSize: 14,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(
          title: trainer.name,
          subtitle: '${trainer.email} · $created 등록',
          mutedSubtitle: true,
        ),
        AppStatStrip(
          padded: false,
          // 시안 `rise`: 시트가 올라온 뒤(.35s) 0.08초 간격으로
          entrance: const AppStatEntrance(start: Duration(milliseconds: 350)),
          cells: [
            kpi('배정 회원', members.length, '명'),
            kpi('이번 달 PT 완료', monthCompleted, '회'),
          ],
        ),
        AppMonthHeader(
          label: '배정 회원',
          count: '${members.length}명',
          strongCount: true,
          padding: const EdgeInsets.only(top: 22, bottom: AppSpacing.xs),
        ),
        if (members.isEmpty)
          const AppEmptyLine('배정된 회원이 없습니다.', inset: false)
        else
          for (final member in members)
            Builder(
              builder: (context) {
                final pt = ptInfos[member.uid];
                return AppListRow(
                  title: member.name,
                  subtitle: pt == null
                      ? 'PT 이용권 없음'
                      : 'PT ${pt.remainingSessions} / ${pt.totalSessions}회 남음',
                  subtitleColor: AppColors.body,
                  height: 60,
                  padded: false,
                  chevron: true,
                  onTap: () => Navigator.of(context).pop(member),
                );
              },
            ),
      ],
    );
  }
}
