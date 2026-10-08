import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

/// 52 높이 키/값 한 줄 (시안 Tr-Member-Profile · Tr-Inbody-Detail):
/// 왼쪽 라벨 15 body, 오른쪽 값 16/500 + (선택) 단위 400 mute.
/// [divider]면 아래 1px 구분선 — 캔버스 위는 `hairline`(기본), 회색 카드 안은 `line`을 [dividerColor]로 준다.
class AppKeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool divider;
  final Color? dividerColor;

  const AppKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.divider = false,
    this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final unit = this.unit;
    return Semantics(
      label: '$label ${unit == null ? value : '$value$unit'}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: divider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: dividerColor ?? AppColors.hairline),
                ),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value),
                  if (unit != null && unit.isNotEmpty)
                    TextSpan(
                      text: unit,
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: AppColors.mute,
                      ),
                    ),
                ],
              ),
              style: AppTextStyles.input.medium,
            ),
          ],
        ),
      ),
    );
  }
}
