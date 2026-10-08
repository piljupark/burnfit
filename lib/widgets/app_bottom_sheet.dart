import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_icon_box.dart';
import 'app_icon_button.dart';
import 'app_motion.dart';

/// 하단 시트 (시안 Com-CenterPicker·MemA-Sheet-*): 흰 면(canvas), 위 모서리 28, 손잡이 36×5,
/// 위 10 · 손잡이와 머리 사이 14, 아래는 안전 영역(최소 20). 뒤는 검정 40%.
/// 아래에서 올라오는 움직임 450ms (AppMotion.sheet). 모든 하단 시트는 이 함수로 연다.
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
    sheetAnimationStyle: AnimationStyle(
      duration: const Duration(milliseconds: 450),
      curve: AppMotion.sheet,
      reverseDuration: const Duration(milliseconds: 250),
    ),
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
          10,
          horizontal,
          fixed ? 0 : math.max(media.padding.bottom, AppSpacing.lg),
        ),
        child: Column(
          mainAxisSize: fixed ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.canvasMid,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: 14),
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

/// 시트 머리: 제목 22/500 + 닫기(22, ink) + (선택) 보조 줄.
/// - 보조 줄: 기본 15 body(시안 Com-*), [mutedSubtitle]이면 14 mute(시안 MemA-Sheet-*)
/// - [gap]: 머리 아래 간격 (시안마다 12·16·20)
/// - [trailingTitle]: 제목 바로 뒤 그림 (예: 휴식 타이머 시계)
class AppBottomSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// 서식이 섞인 보조 줄 (있으면 [subtitle] 대신 쓴다). 제목과 4 띄운다.
  final Widget? subtitleWidget;
  final VoidCallback? onClose;
  final bool mutedSubtitle;
  final double gap;
  final Widget? trailingTitle;

  const AppBottomSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.onClose,
    this.mutedSubtitle = false,
    this.gap = AppSpacing.base,
    this.trailingTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 보조 줄이 없으면 제목을 닫기 단추(44)와 가운데 맞춤,
                // 있으면 제목 줄(28)을 위로 붙이고 보조 줄을 4 아래에 둔다 (시안 MemA-Sheet-ExerciseMenu).
                Container(
                  height: subtitle == null && subtitleWidget == null
                      ? AppSize.touchMin
                      : null,
                  padding: subtitle == null && subtitleWidget == null
                      ? null
                      : const EdgeInsets.only(top: AppSpacing.sm),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Flexible(
                        child: Semantics(
                          header: true,
                          child: Text(title, style: AppTextStyles.sheetTitle),
                        ),
                      ),
                      if (trailingTitle != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        trailingTitle!,
                      ],
                    ],
                  ),
                ),
                if (subtitleWidget != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: subtitleWidget,
                  )
                else if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      subtitle!,
                      style: mutedSubtitle
                          ? AppTextStyles.fieldLabel
                          : AppTextStyles.bodyMd.copyWith(
                              color: AppColors.body,
                            ),
                    ),
                  ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(11, 0),
            child: AppIconButton(
              icon: AppIcons.closeBold,
              label: '닫기',
              iconSize: 22,
              onPressed: onClose ?? () => Navigator.of(context).pop(),
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// 시트 안 행동 한 줄 (시안 MemA-Sheet-ExerciseMenu): 높이 60, 40 아이콘 상자(반경 12) + 14 + 라벨 16
/// + 오른쪽 값 15 mute (+ [chevron]이면 16 화살표). 파괴적 행은 맨 아래 — 연한 주황 상자 + noticeText 500.
class AppSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool chevron;

  /// 오른쪽 보조 값 (예: 지금 설정 '90초').
  final String? value;

  const AppSheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.value,
    this.chevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? AppColors.noticeText : AppColors.ink;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              AppIconBox(
                icon: icon,
                background: destructive ? AppColors.noticeBg : null,
                iconColor: fg,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: destructive
                      ? AppTextStyles.input.medium.copyWith(color: fg)
                      : AppTextStyles.input.copyWith(color: fg),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.mute),
                ),
              if (chevron) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  AppIcons.chevronRightBold,
                  size: 16,
                  color: AppColors.chevron,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
