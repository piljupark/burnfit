import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../models/user.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  factory StatusBadge.fromStatus(UserStatus status) {
    switch (status) {
      case UserStatus.pending:
        return StatusBadge(label: '승인 대기', color: AppColors.statusPending);
      case UserStatus.approved:
        return StatusBadge(label: '승인', color: AppColors.statusApproved);
      case UserStatus.rejected:
        return StatusBadge(label: '거절', color: AppColors.statusRejected);
    }
  }

  factory StatusBadge.fromString(String label, Color color) {
    return StatusBadge(label: label, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: AppTextStyles.label.copyWith(color: color)),
    );
  }
}
