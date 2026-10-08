import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../models/user.dart';

/// 성별 선택 (시안 Com-Onboarding-Basic): 같은 폭 2칸, 높이 52 · 반경 14 · 회색 면(canvasSoft),
/// 글자 16 body. 선택 = 검정 채움 + 흰 16/500. 온보딩·기본 정보 편집 공통.
/// '기타'는 고르게 하지 않는다 (예전 값이면 아무것도 선택되지 않은 상태로 보인다).
class GenderSelector extends StatelessWidget {
  final Gender? value;
  final ValueChanged<Gender> onChanged;

  const GenderSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _options = [Gender.male, Gender.female];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '성별',
      container: true,
      child: Row(
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _GenderOption(
                label: _options[i].label,
                selected: value == _options[i],
                onTap: () => onChanged(_options[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.canvasSoft,
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: Text(
            label,
            style: AppTextStyles.input.copyWith(
              color: selected ? AppColors.canvas : AppColors.body,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
