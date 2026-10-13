import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/roster_import.dart';
import '../../core/validators.dart';
import '../../models/join_request.dart';
import '../../services/firestore_service.dart';
import '../../services/roster_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';

/// 가입 요청 (기준 시안 AdminRequests): 큰 제목 → 역할 칩(전체·회원·트레이너 + 개수) →
/// 요청 줄(17 이름 · 14 '회원 · 10월 8일 신청 · 이메일' · 2칸 거절/승인 44).
/// 승인한 줄은 오른쪽으로 밀리며 흐려지고 접힌다 (시안 `leave`).
class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

enum _RoleFilter { all, member, trainer }

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  List<JoinRequest> _requests = [];
  final Set<String> _processingIds = {};

  /// 승인돼 사라지는 중인 줄 (움직임이 끝나면 목록에서 뺀다)
  final Set<String> _leavingIds = {};
  _RoleFilter _filter = _RoleFilter.all;

  /// 요청 id → 신청자 번호 · 명단과 맞춘 결과 (요청 목록 뒤에 따로 읽는다)
  final Map<String, ({String? phone, RosterMatch? match})> _roster = {};
  bool _isLoading = false;
  bool _loadedOnce = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    // 처음에만 화면 전체를 로딩으로 바꾼다 (당겨서 새로고침·돌아와서 다시 불러올 때는 보이던 내용을 그대로 둔다).
    if (!_loadedOnce) setState(() => _isLoading = true);
    try {
      final list = await FirestoreService.getPendingRequests(user.centerId);
      // 최근 신청부터
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _requests = list;
        _leavingIds.clear();
        _errorMessage = null;
        _loadedOnce = true;
      });
      _loadRoster(list);
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

  /// 신청자 번호와 명단을 맞춰 본다. 실패해도 요청 목록은 그대로 쓴다.
  Future<void> _loadRoster(List<JoinRequest> list) async {
    await Future.wait(
      list.map((req) async {
        try {
          final result = await RosterService.lookup(req);
          if (mounted) setState(() => _roster[req.id] = result);
        } catch (_) {
          // 번호 · 명단을 읽지 못하면 표시하지 않는다
        }
      }),
    );
  }

  bool _matches(JoinRequest r, _RoleFilter f) => switch (f) {
    _RoleFilter.all => true,
    _RoleFilter.member => r.role != 'trainer',
    _RoleFilter.trainer => r.role == 'trainer',
  };

  int _count(_RoleFilter f) => _requests
      .where((r) => !_leavingIds.contains(r.id) && _matches(r, f))
      .length;

  Future<void> _approve(JoinRequest req) async {
    if (_processingIds.contains(req.id)) return;
    final admin = context.read<UserProvider>().user;
    // 이름까지 같을 때만 명단의 담당 · PT를 붙인다
    final match = _roster[req.id]?.match;
    final apply = match != null && match.sameName ? match.entry : null;
    setState(() => _processingIds.add(req.id));
    try {
      await FirestoreService.approveJoinRequest(req.id, req.userId);
      String? warning;
      if (apply != null && admin != null) {
        warning = await RosterService.applyAfterApproval(
          req: req,
          entry: apply,
          admin: admin,
        );
      }
      if (!mounted) return;
      setState(() {
        _processingIds.remove(req.id);
        _leavingIds.add(req.id);
      });
      if (warning != null) {
        AppFeedback.showWarning(context, '${req.userName} 님을 승인했어요. $warning');
      } else {
        AppFeedback.showSuccessSnackBar(
          context,
          apply != null && apply.role == 'member'
              ? '${req.userName} 님을 승인하고 명단 정보를 붙였어요'
              : '${req.userName} 님을 승인했어요',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(req.id));
      AppFeedback.showErrorSnackBar(context, e);
      // 그 사이 다른 관리자가 처리했거나 신청자가 탈퇴했을 수 있다 → 목록을 다시 맞춘다
      _load();
    }
  }

  Future<void> _reject(JoinRequest req) async {
    if (_processingIds.contains(req.id)) return;
    final confirm = await showAppConfirmDialog(
      context,
      title: '가입 거절',
      message:
          '${req.userName}님의 가입 요청을 거절합니다. 거절된 계정은 로그인할 수 없고, 이 결정은 되돌릴 수 없어요.',
      confirmLabel: '거절',
    );
    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _processingIds.add(req.id));
    try {
      await FirestoreService.rejectJoinRequest(req.id, req.userId);
      if (!mounted) return;
      setState(() {
        _requests.removeWhere((r) => r.id == req.id);
        _processingIds.remove(req.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(req.id));
      AppFeedback.showErrorSnackBar(context, e);
      // 그 사이 다른 관리자가 처리했거나 신청자가 탈퇴했을 수 있다 → 목록을 다시 맞춘다
      _load();
    }
  }

  void _removeLeft(String id) {
    if (!mounted) return;
    setState(() {
      _requests.removeWhere((r) => r.id == id);
      _leavingIds.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _requests.where((r) => _matches(r, _filter)).toList();
    final hasAny = _requests.any((r) => !_leavingIds.contains(r.id));
    final date = DateFormat('M월 d일');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.large(
              title: '가입 요청',
              bold: true,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: !hasAny && _leavingIds.isEmpty,
                onRefresh: _load,
                padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
                // 시안 Ad-Requests-Empty: 제목 아래 160 (본문 위 24 + 136)
                empty: const AppEmptyState(
                  icon: AppIcons.userPlus,
                  message: '대기 중인 요청이 없습니다.',
                  compact: true,
                  top: 136,
                ),
                children: [
                  // 역할 칩 (시안: 위 16 · 40 높이 · 좌우 16 · 15)
                  AppViewTabs(
                    labels: const ['전체', '회원', '트레이너'],
                    counts: [
                      for (final f in _RoleFilter.values) '${_count(f)}',
                    ],
                    selectedIndex: _filter.index,
                    chipPadding: AppSpacing.base,
                    scrollable: true,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.base,
                      AppSpacing.screenH,
                      0,
                    ),
                    onSelect: (i) =>
                        setState(() => _filter = _RoleFilter.values[i]),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (visible.isEmpty)
                    const AppEmptyLine('이 역할의 요청이 없습니다.')
                  else
                    for (final req in visible)
                      _LeaveTransition(
                        key: ValueKey(req.id),
                        leaving: _leavingIds.contains(req.id),
                        onEnd: () => _removeLeft(req.id),
                        child: _RequestRow(
                          name: req.userName,
                          meta: [
                            req.role == 'trainer' ? '트레이너' : '회원',
                            '${date.format(req.createdAt)} 신청',
                            req.userEmail,
                            if (_roster[req.id]?.phone case final phone?)
                              Validators.maskPhone(phone),
                          ].join(' · '),
                          match: _roster[req.id]?.match,
                          isProcessing: _processingIds.contains(req.id),
                          locked: _leavingIds.contains(req.id),
                          onApprove: () => _approve(req),
                          onReject: () => _reject(req),
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

// ── _RequestRow ───────────────────────────────────────────────────────────────

/// 요청 한 줄 (기준 시안 AdminRequests): 위아래 18 · 아래 hairline, 이름 17 Bold ·
/// (4) 보조 줄 14 mute · (14) 2칸 버튼 44(반경 14, 15 Bold) — 거절 회색 · 승인 주황.
class _RequestRow extends StatelessWidget {
  final String name;
  final String meta;

  /// 신청자 번호가 명단과 같으면 주황 상자
  final RosterMatch? match;
  final bool isProcessing;

  /// 승인돼 사라지는 중 — 다시 누를 수 없다
  final bool locked;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestRow({
    required this.name,
    required this.meta,
    this.match,
    required this.isProcessing,
    required this.locked,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final busy = isProcessing || locked;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              style: AppTextStyles.bodyLg.bold.natural,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              meta,
              style: AppTextStyles.fieldLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (match case final m?) ...[
              const SizedBox(height: AppSpacing.md),
              _RosterMatchBox(match: m),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '거절',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.row,
                    fullWidth: true,
                    bold: true,
                    onPressed: busy ? null : onReject,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: '승인',
                    size: AppButtonSize.row,
                    fullWidth: true,
                    bold: true,
                    loadingOnly: true,
                    isLoading: isProcessing,
                    onPressed: busy ? null : onApprove,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 승인한 줄이 사라지는 움직임 (시안 `leave`): 오른쪽으로 40 밀리며 흐려지고(0~45%) 높이가 접힌다(45~100%).
/// 동작 줄이기면 바로 사라진다.
class _LeaveTransition extends StatefulWidget {
  final bool leaving;
  final VoidCallback onEnd;
  final Widget child;

  const _LeaveTransition({
    super.key,
    required this.leaving,
    required this.onEnd,
    required this.child,
  });

  @override
  State<_LeaveTransition> createState() => _LeaveTransitionState();
}

class _LeaveTransitionState extends State<_LeaveTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onEnd();
    });
    if (widget.leaving) _start();
  }

  @override
  void didUpdateWidget(_LeaveTransition old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) _start();
  }

  void _start() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppMotion.reduced(context)) {
        widget.onEnd();
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.45, curve: Curves.easeInOut),
    );
    final fold = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1, curve: Curves.easeInOut),
    );
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1 - fold.value,
          child: Opacity(
            opacity: 1 - fade.value,
            child: Transform.translate(
              offset: Offset(40 * fade.value, 0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// '명단과 일치' 상자 (시안 09 '가입 요청'): 주황 옅은 바탕 반경 14.
/// '✓ 명단과 일치' 14/700 noticeText · 명단 요약 → 승인하면 무엇이 붙는지 13.
/// 이름이 다르면 붙이지 않는다고 알린다.
class _RosterMatchBox extends StatelessWidget {
  final RosterMatch match;

  const _RosterMatchBox({required this.match});

  @override
  Widget build(BuildContext context) {
    final e = match.entry;
    final String note;
    if (!match.sameName) {
      note = "명단 이름이 '${e.name}'(으)로 달라 승인해도 명단 정보는 붙이지 않아요. 확인 뒤 회원 상세에서 넣어 주세요.";
    } else if (e.isTrainer) {
      note = '승인하면 명단에서 빠져요.';
    } else if (e.trainerId == null && e.ptTotal == null) {
      note = '명단에 담당 · PT가 없어 승인만 해요.';
    } else {
      note = '승인하면 담당 트레이너와 PT 정보가 함께 붙어요.';
    }
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: match.sameName ? '✓ 명단과 일치' : '번호만 명단과 일치',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.noticeText,
                    ),
                  ),
                  TextSpan(text: ' · ${RosterImport.summary(e)}'),
                ],
              ),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(note, style: AppTextStyles.counter),
          ],
        ),
      ),
    );
  }
}
