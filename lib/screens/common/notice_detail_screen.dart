import 'package:flutter/material.dart';

import '../../core/app_spacing.dart';
import '../../models/notice.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/notice_widgets.dart';

/// 공지 상세 (회원·트레이너 공용, 읽기 전용).
class NoticeDetailScreen extends StatelessWidget {
  final Notice notice;
  final String centerName;
  const NoticeDetailScreen({
    super.key,
    required this.notice,
    this.centerName = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader(
              title: '공지사항',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xl,
                  AppSpacing.screenH,
                  AppSpacing.xl2,
                ),
                child: NoticeArticle(notice: notice, centerName: centerName),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
