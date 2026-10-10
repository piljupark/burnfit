import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../models/notice.dart';
import '../../services/notice_read_store.dart';
import '../../services/notice_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/notice_widgets.dart';
import 'notice_detail_screen.dart';

/// 회원·트레이너 홈 헤더 아래 최신 공지 한 줄 + 중요 공지 시트(공지마다 한 번).
/// 홈의 모든 보기(오늘·캘린더·기록)에서 같은 자리에 보인다.
/// 공지가 없거나 불러오지 못하면 아무것도 그리지 않는다.
class NoticeHomeBanner extends StatefulWidget {
  const NoticeHomeBanner({super.key});

  @override
  State<NoticeHomeBanner> createState() => NoticeHomeBannerState();
}

class NoticeHomeBannerState extends State<NoticeHomeBanner> {
  Notice? _latest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 홈을 다시 불러올 때(당겨서 새로고침·탭 복귀) 최신 공지도 다시 읽는다.
  Future<void> reload() => _load();

  Future<void> _load() async {
    final user = context.read<UserProvider>().user;
    if (user == null || user.isAdmin) return;
    try {
      final items = await NoticeService.getForViewer(user.centerId, user.role);
      if (!mounted) return;
      if (items.isEmpty) {
        // 공지가 모두 지워졌으면 줄도 내린다
        if (_latest != null) setState(() => _latest = null);
        return;
      }
      // 최신 글 (고정 여부와 무관하게 가장 최근 작성)
      final byDate = [...items]
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      setState(() => _latest = byDate.first);
      await _maybeShowImportant(user.uid, user.centerName, byDate);
    } catch (e) {
      AppLogger.debug('[공지 배너 로드 실패] $e');
    }
  }

  Future<void> _maybeShowImportant(
    String uid,
    String centerName,
    List<Notice> byDate,
  ) async {
    Notice? target;
    for (final n in byDate.where((n) => n.important)) {
      if (!await NoticeReadStore.wasSheetShown(uid, n.id)) {
        target = n;
        break;
      }
    }
    if (target == null || !mounted) return;
    // 같은 공지를 다시 띄우지 않도록 먼저 기록한다.
    await NoticeReadStore.markSheetShown(uid, target.id);
    if (!mounted) return;
    final action = await showImportantNoticeSheet(
      context,
      target,
      centerName: centerName,
    );
    if (action == NoticeSheetAction.detail && mounted) _open(target);
  }

  void _open(Notice n) {
    final centerName = context.read<UserProvider>().user?.centerName ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoticeDetailScreen(notice: n, centerName: centerName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    if (latest == null) return const SizedBox.shrink();
    return NoticeBanner(notice: latest, onTap: () => _open(latest));
  }
}
