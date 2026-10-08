import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../models/notice.dart';
import '../../services/notice_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/notice_widgets.dart';
import 'admin_notice_detail_screen.dart';
import 'admin_notice_edit_screen.dart';

/// 관리자 공지 목록 (고정 → 전체).
class AdminNoticeListScreen extends StatefulWidget {
  const AdminNoticeListScreen({super.key});

  @override
  State<AdminNoticeListScreen> createState() => _AdminNoticeListScreenState();
}

class _AdminNoticeListScreenState extends State<AdminNoticeListScreen> {
  List<Notice> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final centerId = context.read<UserProvider>().user?.centerId;
    if (centerId == null) return;
    setState(() => _isLoading = true);
    try {
      final items = await NoticeService.getForAdmin(centerId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
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
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminNoticeDetailScreen(notice: n)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final pinnedCount = _items.where((n) => n.pinned).length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: '공지사항',
              subtitle: _items.isEmpty
                  ? null
                  : '전체 ${_items.length}개 · 고정 $pinnedCount개',
              onBack: () => Navigator.of(context).pop(),
              trailing: _items.isEmpty
                  ? null
                  : AppButton(
                      label: '공지 작성',
                      size: AppButtonSize.sm,
                      icon: const Icon(AppIcons.add, size: 16),
                      onPressed: _compose,
                    ),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _items.isEmpty,
                onRefresh: _load,
                padding: const EdgeInsets.only(bottom: AppSpacing.xl2),
                empty: AppEmptyState(
                  icon: AppIcons.clipboard,
                  message: '아직 등록한 공지가 없어요',
                  description: '운영 시간, 시설 안내처럼 회원과 트레이너가 알아야 할 소식을 남겨 보세요',
                  actionLabel: '첫 공지 작성',
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
      ),
    );
  }
}
