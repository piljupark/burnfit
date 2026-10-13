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
import '../../models/roster_entry.dart';
import '../../services/roster_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import 'admin_roster_upload_screen.dart';

/// 회원 명단 (시안 09 '미가입 목록'): 관리자 홈 '관리' → '회원 명단'.
///
/// 엑셀로 올렸지만 아직 가입하지 않은 사람. 큰 제목 + 개수 · 오른쪽 올리기 →
/// 구분 알약(전체 · 회원 · 트레이너) → 줄(이름 · 가린 번호 · 담당 · PT · 올린 날).
/// 줄을 누르면 '명단에서 지우기'. 가입하면 가입 요청에 '명단과 일치'로 뜨고,
/// 승인하며 담당 · PT를 붙이면 이 목록에서 빠진다.
class AdminRosterScreen extends StatefulWidget {
  const AdminRosterScreen({super.key});

  @override
  State<AdminRosterScreen> createState() => _AdminRosterScreenState();
}

class _AdminRosterScreenState extends State<AdminRosterScreen> {
  List<RosterEntry> _rows = const [];
  bool _isLoading = true;
  String? _errorMessage;

  /// 0 전체 · 1 회원 · 2 트레이너
  int _filter = 0;

  String get _centerId => context.read<UserProvider>().user?.centerId ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _errorMessage = null);
    try {
      final rows = await RosterService.list(_centerId);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = AppFeedback.errorMessage(e);
      });
    }
  }

  bool _matches(RosterEntry e, int f) => switch (f) {
    1 => !e.isTrainer,
    2 => e.isTrainer,
    _ => true,
  };

  Future<void> _upload() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminRosterUploadScreen()),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _showRow(RosterEntry e) async {
    final remove = await showAppBottomSheet<bool>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBottomSheetHeader(
              title: e.name,
              subtitle:
                  '${Validators.maskPhone(e.phone)} · ${RosterImport.summary(e)}',
              mutedSubtitle: true,
              gap: AppSpacing.md,
            ),
            AppSheetAction(
              icon: AppIcons.trash,
              label: '명단에서 지우기',
              destructive: true,
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ),
      ),
    );
    if (remove != true || !mounted) return;
    final ok = await showAppConfirmDialog(
      context,
      title: '명단에서 지우기',
      message: '${e.name}님 줄을 지웁니다. 가입해도 가입 요청에 명단 정보가 뜨지 않아요.',
      confirmLabel: '지우기',
    );
    if (!ok || !mounted) return;
    try {
      await RosterService.delete(_centerId, e.id);
      if (!mounted) return;
      setState(() => _rows = _rows.where((r) => r.id != e.id).toList());
      AppFeedback.showSuccessSnackBar(context, '명단에서 지웠어요');
    } catch (err) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _rows.where((e) => _matches(e, _filter)).toList();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.large(
              title: '회원 명단',
              bold: true,
              count: _isLoading ? null : '${_rows.length}',
              onBack: () => Navigator.of(context).pop(),
              trailing: AppIconButton(
                icon: AppIcons.upload,
                label: '명단 올리기',
                onPressed: _upload,
              ),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _rows.isEmpty,
                onRefresh: _load,
                padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
                empty: AppEmptyState(
                  icon: AppIcons.list,
                  compact: true,
                  top: 96,
                  message: '아직 가입하지 않은 명단이 없어요.',
                  description: '엑셀로 회원 · 트레이너 명단을 올리면\n가입할 때 담당 · PT를 함께 붙일 수 있어요.',
                  actionLabel: '명단 올리기',
                  onAction: _upload,
                ),
                children: [
                  AppViewTabs(
                    labels: const ['전체', '회원', '트레이너'],
                    counts: [
                      for (var f = 0; f < 3; f++)
                        '${_rows.where((e) => _matches(e, f)).length}',
                    ],
                    selectedIndex: _filter,
                    compact: true,
                    scrollable: true,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.base,
                      AppSpacing.screenH,
                      AppSpacing.sm,
                    ),
                    onSelect: (i) => setState(() => _filter = i),
                  ),
                  if (visible.isEmpty)
                    const AppEmptyLine('이 구분의 명단이 없어요.')
                  else
                    for (final e in visible)
                      _RosterRow(entry: e, onTap: () => _showRow(e)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.lg,
                      AppSpacing.screenH,
                      0,
                    ),
                    child: Text(
                      "가입하면 '가입 요청'에 '명단과 일치'로 떠요. 승인하면 담당 · PT가 붙고 이 목록에서 빠져요.",
                      style: AppTextStyles.captionSmall.copyWith(height: 1.5),
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

/// 명단 한 줄 (좌우 20 · 위아래 14 · 아래 hairline): 이름 16/500 + '트레이너' 13 mute →
/// '010-****-5678 · 박코치 · PT 10회 (기간)' 13 mute → '10월 13일 올림' 12 mute.
class _RosterRow extends StatelessWidget {
  final RosterEntry entry;
  final VoidCallback onTap;

  const _RosterRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final detail = e.isTrainer
        ? Validators.maskPhone(e.phone)
        : '${Validators.maskPhone(e.phone)} · ${RosterImport.summary(e)}';
    return Semantics(
      button: true,
      label: '${e.name}, ${e.isTrainer ? '트레이너' : '회원'}, $detail',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: e.name),
                            if (e.isTrainer)
                              TextSpan(
                                text: '  트레이너',
                                style: AppTextStyles.counter,
                              ),
                          ],
                        ),
                        style: AppTextStyles.listTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(detail, style: AppTextStyles.counter),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('M월 d일').format(e.updatedAt)} 올림',
                        style: AppTextStyles.captionSmall,
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.forward, size: 18, color: AppColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
