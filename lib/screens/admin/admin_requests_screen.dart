import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/join_request.dart';
import '../../services/firestore_service.dart';
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
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final list = await FirestoreService.getPendingRequests(user.centerId);
      // 최근 신청부터
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _requests = list;
        _leavingIds.clear();
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
    setState(() => _processingIds.add(req.id));
    try {
      await FirestoreService.approveJoinRequest(req.id, req.userId);
      if (!mounted) return;
      setState(() {
        _processingIds.remove(req.id);
        _leavingIds.add(req.id);
      });
      AppFeedback.showSuccessSnackBar(context, '${req.userName} 님을 승인했어요');
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingIds.remove(req.id));
      AppFeedback.showErrorSnackBar(context, e);
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
                          ].join(' · '),
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
  final bool isProcessing;

  /// 승인돼 사라지는 중 — 다시 누를 수 없다
  final bool locked;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestRow({
    required this.name,
    required this.meta,
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
