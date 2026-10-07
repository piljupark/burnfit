import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 세트 입력 줄의 공용 부품 (회원 운동·트레이너 PT 기록이 함께 쓴다).
///
/// - 완료 = 흰 채운 원 + 굵은 체크, 진행 중 = 흰 외곽선 원, 대기 = 흐린 외곽선 원.
/// - 값 상자: canvasSoft, 높이 36, 진행 중 줄은 흰 테두리.

const double kSetValueHeight = 36;
const double kSetCheckSize = 26;

/// 세트 완료 토글 (터치 영역 44, 스크린리더 "n세트 완료").
class SetDoneButton extends StatelessWidget {
  final int number;
  final bool done;
  final bool current;
  final VoidCallback onTap;

  const SetDoneButton({
    super.key,
    required this.number,
    required this.done,
    required this.current,
    required this.onTap,
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
              width: kSetCheckSize,
              height: kSetCheckSize,
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
                      size: AppSize.iconSm,
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

  const SetValueField({
    super.key,
    required this.controller,
    required this.decimal,
    required this.highlighted,
    required this.semanticLabel,
    required this.onChanged,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: Container(
        height: kSetValueHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.canvasSoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
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
          textAlignVertical: TextAlignVertical.center,
          style: AppTextStyles.bodyMd.copyWith(
            color: textColor ?? AppColors.ink,
            height: 1.0,
          ),
          cursorColor: AppColors.ink,
          cursorHeight: 18,
          decoration: const InputDecoration(
            filled: false,
            isCollapsed: true,
            isDense: true,
            hintText: '-',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
