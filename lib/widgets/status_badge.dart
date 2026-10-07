import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/user.dart';
import 'app_tag.dart';

/// 상태 배지 — Galloway 태그 모양. 상태는 색이 아니라 모양으로 구분한다.
/// - [strong]: 흰 채움 (완료·승인처럼 끝난 상태)
/// - 기본: 외곽선 (진행·대기)
/// - [color]가 AppColors.danger면 빨간 글자 (거절·만료처럼 되돌릴 수 없는 상태),
///   AppColors.mute면 흐린 글자 (취소). 그 밖의 색은 무시한다.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final bool strong;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.strong = false,
  });

  /// 승인 상태: 승인 = 흰 채움, 대기 = 외곽선, 거절 = 빨간 글자.
  factory StatusBadge.fromStatus(UserStatus status) {
    switch (status) {
      case UserStatus.pending:
        return const StatusBadge(label: '승인 대기');
      case UserStatus.approved:
        return const StatusBadge(label: '승인', strong: true);
      case UserStatus.rejected:
        return StatusBadge(label: '거절', color: AppColors.danger);
    }
  }

  factory StatusBadge.fromString(String label, Color? color) =>
      StatusBadge(label: label, color: color);

  @override
  Widget build(BuildContext context) {
    return AppTag(
      label,
      strong: strong,
      danger: color == AppColors.danger,
      muted: color == AppColors.mute,
    );
  }
}
