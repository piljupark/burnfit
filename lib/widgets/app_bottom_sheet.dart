import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_icon_button.dart';

/// 하단 시트: 흰 면(canvas), 위 모서리 28, 테두리 없음, 손잡이 36×4.
/// 뒤는 검정 60%로 덮는다. 모든 하단 시트는 이 함수로 연다.
///
/// - 기본: 내용 높이만큼, 넘치면 시트 전체가 스크롤된다.
/// - [heightFactor]: 화면 높이의 비율로 고정한다. 내용은 남은 높이를 채우므로
///   목록(ListView/Expanded)이 있는 시트에 쓴다 (내용이 스스로 스크롤을 맡는다).
/// - [padded]: 좌우 20 여백. 화면 폭 목록을 그리는 시트는 false.
/// [memberStyle]은 기존 호출부 호환용이다 (테마는 하나).
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isDismissible = true,
  bool isScrollControlled = true,
  bool memberStyle = false,
  double? heightFactor,
  bool padded = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.backdrop,
    elevation: 0,
    builder: (_) => _AppBottomSheetFrame(
      heightFactor: heightFactor,
      padded: padded,
      child: child,
    ),
  );
}

class _AppBottomSheetFrame extends StatelessWidget {
  final Widget child;
  final double? heightFactor;
  final bool padded;

  const _AppBottomSheetFrame({
    required this.child,
    this.heightFactor,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final fixed = heightFactor != null;
    final horizontal = padded ? AppSpacing.screenH : 0.0;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: fixed ? media.size.height * heightFactor! : null,
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          AppSpacing.sm,
          horizontal,
          fixed ? 0 : AppSpacing.base + media.padding.bottom,
        ),
        child: Column(
          mainAxisSize: fixed ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.canvasMid,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (fixed)
              Expanded(child: child)
            else
              Flexible(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
    );
  }
}

/// 시트 머리: 제목(20) + 닫기 + (선택) 보조 줄. 카드 위이므로 보조 글자는 body 색.
class AppBottomSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  const AppBottomSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.title)),
              Transform.translate(
                offset: const Offset(12, 0),
                child: AppIconButton(
                  icon: AppIcons.close,
                  label: '닫기',
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                  color: AppColors.body,
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
            ),
        ],
      ),
    );
  }
}

/// 시트 안 행동 목록 한 줄 (높이 52, 아이콘 + 라벨 + 선택 값). 파괴적 행은 맨 아래, danger.
class AppSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  /// 오른쪽 보조 값 (예: 지금 설정 '90초').
  final String? value;

  const AppSheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? AppColors.danger : AppColors.ink;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              Icon(icon, size: AppSize.icon, color: fg),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMd.copyWith(color: fg),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
