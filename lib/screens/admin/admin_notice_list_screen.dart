import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../models/notice.dart';
import '../../services/notice_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_highlight.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/notice_widgets.dart';
import 'admin_notice_detail_screen.dart';
import 'admin_notice_edit_screen.dart';

/// 관리자 공지 목록 (시안 Nt-Admin-List): 큰 제목 + 개수 → '상단 고정' / 띠 '전체 공지' → 떠 있는 '공지 작성'.
class AdminNoticeListScreen extends StatefulWidget {
  const AdminNoticeListScreen({super.key});

  @override
  State<AdminNoticeListScreen> createState() => _AdminNoticeListScreenState();
}

class _AdminNoticeListScreenState extends State<AdminNoticeListScreen> {
  List<Notice> _items = [];
  bool _isLoading = false;
  bool _loadedOnce = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final centerId = context.read<UserProvider>().user?.centerId;
    if (centerId == null) return;
    // 처음에만 화면 전체를 로딩으로 바꾼다 (당겨서 새로고침·돌아와서 다시 불러올 때는 보이던 내용을 그대로 둔다).
    if (!_loadedOnce) setState(() => _isLoading = true);
    try {
      final items = await NoticeService.getForAdmin(centerId);
      if (!mounted) return;
      setState(() {
        _items = items;
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _compose() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminNoticeEditScreen()),
    );
    if (saved == true) _load();
  }

  Future<void> _open(Notice n) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminNoticeDetailScreen(notice: n)),
    );
    // 수정·삭제했을 수 있다 (밀어서 뒤로 가면 결과가 없으므로 늘 다시 불러온다)
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final fabBottom = math.max(
      MediaQuery.paddingOf(context).bottom,
      AppSpacing.lg,
    );
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppScreenHeader.large(
                  title: '공지사항',
                  count: _items.isEmpty ? null : '${_items.length}',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: AppAsyncBody(
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                    isEmpty: _items.isEmpty,
                    onRefresh: _load,
                    // 떠 있는 '공지 작성'(56 + 아래 여백)에 마지막 줄이 가리지 않게
                    padding: EdgeInsets.only(bottom: 56 + fabBottom + 24),
                    // 시안 Nt-Admin-Empty: 제목 아래 40 회색 카드, 흔들리는 확성기 56,
                    // 검정 44 '첫 공지 작성'
                    empty: AppEmptyState(
                      icon: AppIcons.megaphone,
                      card: true,
                      margin: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        AppSpacing.base,
                        AppSpacing.screenH,
                        0,
                      ),
                      cardPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: 40,
                      ),
                      artGap: AppSpacing.md,
                      illustration: AppSway(
                        child: Icon(
                          AppIcons.megaphone,
                          size: 56,
                          color: AppColors.faint,
                        ),
                      ),
                      message: '아직 등록한 공지가 없어요',
                      description: '운영 시간, 시설 안내처럼 회원과 트레이너가 알아야 할 소식을 남겨 보세요',
                      actionLabel: '첫 공지 작성',
                      actionVariant: AppButtonVariant.dark,
                      actionSize: AppButtonSize.row,
                      onAction: _compose,
                    ),
                    children: buildNoticeListChildren(
                      items: _items,
                      onTap: _open,
                      showAudience: true,
                    ),
                  ),
                ),
              ],
            ),
            // 시안 Nt-Admin-List: 오른쪽 아래 검정 '공지 작성' (튀어나오며 나타남 .55s, .2s 뒤)
            if (_items.isNotEmpty)
              Positioned(
                right: AppSpacing.screenH,
                bottom: fabBottom,
                child: AppPop(
                  onMount: true,
                  from: 0.6,
                  delay: const Duration(milliseconds: 200),
                  child: AppFloatingAction(
                    label: '공지 작성',
                    bold: false,
                    onPressed: _compose,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
