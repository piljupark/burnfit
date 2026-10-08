import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 세트 입력 줄의 공용 부품 (회원 운동·트레이너 PT 기록이 함께 쓴다).
///
/// - 완료 = 주황 채운 원 + 굵은 체크, 진행 중 = ink 외곽선 원, 대기 = 흐린 외곽선 원.
/// - 값 상자: 기본 canvasSoft · 높이 36 · 진행 중 줄 ink 테두리.
///   [SetValueField.card]는 회색 카드 안의 흰 상자(높이 40, 반경 12, 17/700, 테두리 없음 — 시안 Main 계열 Workout).

const double kSetValueHeight = 36;
const double kSetCheckSize = 26;

/// 세트 완료 토글 (터치 영역 44, 스크린리더 "n세트 완료").
class SetDoneButton extends StatelessWidget {
  final int number;
  final bool done;
  final bool current;
  final VoidCallback onTap;

  /// 원 지름 (기본 26, 시안 Workout은 36 + 체크 18)
  final double size;

  const SetDoneButton({
    super.key,
    required this.number,
    required this.done,
    required this.current,
    required this.onTap,
    this.size = kSetCheckSize,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: done,
      label: '$number세트 완료',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: AppSize.touchMin,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.primary : Colors.transparent,
                border: done
                    ? null
                    : Border.all(
                        color: current ? AppColors.ink : AppColors.outline,
                        width: 1.5,
                      ),
              ),
              child: done
                  ? Icon(
                      AppIcons.checkBold,
                      // 기본 26 원은 14 체크 (예전과 같게), 큰 원은 지름의 절반
                      size: size == kSetCheckSize ? AppSize.iconSm : size / 2,
                      color: AppColors.onPrimary,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 세트 숫자 입력 상자 (무게·횟수·시간 등).
class SetValueField extends StatelessWidget {
  final TextEditingController controller;
  final bool decimal;
  final bool highlighted;
  final Color? textColor;
  final String semanticLabel;
  final VoidCallback onChanged;

  /// 회색 카드 안 흰 상자 모양 (높이 40, 반경 12, 17/700, 테두리 없음).
  final bool card;

  const SetValueField({
    super.key,
    required this.controller,
    required this.decimal,
    required this.highlighted,
    required this.semanticLabel,
    required this.onChanged,
    this.textColor,
    this.card = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = card ? 40.0 : kSetValueHeight;
    final lineHeight = card ? 24.0 : 22.0;
    final border = card ? 0.0 : 1.0;
    final base = card ? AppTextStyles.section : AppTextStyles.bodyMd;
    TextStyle valueStyle(Color color) => base.copyWith(
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: card ? AppColors.canvas : AppColors.canvasSoft,
          borderRadius: BorderRadius.circular(
            card ? AppRadius.iconBox : AppRadius.card,
          ),
          border: card
              ? null
              : Border.all(
                  color: highlighted ? AppColors.ink : AppColors.hairline,
                ),
        ),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'\d*'),
            ),
          ],
          onChanged: (_) => onChanged(),
          textAlign: TextAlign.center,
          // AppTextField와 같은 방식: 한 줄(22) + 위아래 같은 여백으로 칸(36)을 채운다.
          // (줄 높이 1.0 + 세로 가운데 정렬 방식은 웹에서 글자가 아래로 내려가 보였다)
          style: valueStyle(textColor ?? AppColors.ink),
          cursorColor: AppColors.ink,
          cursorHeight: 18,
          decoration: InputDecoration(
            filled: false,
            isDense: true,
            hintText: '-',
            hintStyle: valueStyle(AppColors.mute),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            // 한 줄 높이 + 위아래 같은 여백으로 칸을 채운다 (테두리 두께 제외)
            contentPadding: EdgeInsets.symmetric(
              vertical: (height - border * 2 - lineHeight) / 2,
            ),
          ),
        ),
      ),
    );
  }
}
