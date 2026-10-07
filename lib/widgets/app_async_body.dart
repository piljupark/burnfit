import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_feedback.dart';
import '../core/app_spacing.dart';
import 'orb_loader.dart';

/// 목록 화면 본문의 공통 상태 처리: 로딩 → 오류 → 빈 상태 → 내용.
/// 모든 상태에서 당겨서 새로고침이 된다.
class AppAsyncBody extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final bool isEmpty;
  final Future<void> Function() onRefresh;
  final Widget empty;
  final List<Widget> children;

  /// 목록 여백. 화면 폭 hairline 목록은 EdgeInsets.zero를 준다.
  final EdgeInsetsGeometry padding;

  const AppAsyncBody({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.isEmpty,
    required this.onRefresh,
    required this.empty,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.xl2),
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AppLoadingView();
    }

    final List<Widget> content;
    if (errorMessage != null) {
      content = [
        const SizedBox(height: 120),
        AppErrorCard(message: errorMessage!, onRetry: onRefresh),
      ];
    } else if (isEmpty) {
      content = [const SizedBox(height: AppSpacing.xl), empty];
    } else {
      content = children;
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.brand,
      backgroundColor: AppColors.card,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: content,
      ),
    );
  }
}
