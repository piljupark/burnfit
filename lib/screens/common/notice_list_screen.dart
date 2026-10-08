import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../models/notice.dart';
import '../../services/notice_read_store.dart';
import '../../services/notice_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_section.dart';
import '../../widgets/notice_widgets.dart';
import 'notice_detail_screen.dart';

/// 공지사항 목록 (회원·트레이너 공용). 열면 새 글 표시 후 모두 본 것으로 기록한다.
class NoticeListScreen extends StatefulWidget {
  /// 테스트용 데이터 공급자. 없으면 Firestore에서 읽는다.
  final Future<List<Notice>> Function()? loader;

  const NoticeListScreen({super.key, this.loader});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  List<Notice> _items = [];
  Set<String> _newIds = {};
  bool _isLoading = false;
  String? _errorMessage;

  String get _centerName => widget.loader != null
      ? ''
      : context.read<UserProvider>().user?.centerName ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<Notice>> _fetch() async {
    final loader = widget.loader;
    if (loader != null) return loader();
    final user = context.read<UserProvider>().user;
    if (user == null) return [];
    return NoticeService.getForViewer(user.centerId, user.role);
  }

  Future<void> _load() async {
    final uid = widget.loader != null
        ? null
        : context.read<UserProvider>().user?.uid;
    setState(() => _isLoading = true);
    try {
      final items = await _fetch();
      final lastSeen = uid == null ? null : await NoticeReadStore.lastSeen(uid);
      if (!mounted) return;
      final fresh = items
          .where(
            (n) =>
                n.createdAt != null &&
                (lastSeen == null || n.createdAt!.isAfter(lastSeen)),
          )
          .map((n) => n.id)
          .toSet();
      setState(() {
        _items = items;
        _newIds = {..._newIds, ...fresh};
        _errorMessage = null;
      });
      if (uid != null) await NoticeReadStore.markSeen(uid, items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = AppFeedback.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _open(Notice n) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: n)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: '공지사항',
              subtitle: _centerName.isEmpty ? null : '$_centerName에서 알려 드려요',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AppAsyncBody(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: _items.isEmpty,
                onRefresh: _load,
                padding: EdgeInsets.zero,
                empty: const AppEmptyState(
                  icon: AppIcons.clipboard,
                  message: '아직 공지가 없어요',
                  description: '센터 소식이 올라오면 여기에 모여요.',
                ),
                children: buildNoticeListChildren(
                  items: _items,
                  newIds: _newIds,
                  onTap: _open,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
