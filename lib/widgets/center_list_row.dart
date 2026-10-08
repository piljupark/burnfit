import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../models/center.dart' as center_model;

/// 센터 검색 결과 한 줄 (로그인 센터 선택 시트·가입 화면 공통).
/// 이름 16/500 + 주소 13 mute(위 3) + 오른쪽 화살표 18, 아래 hairline.
/// 최소 높이는 시안대로 화면마다 다르다 (로그인 시트 68, 가입 64).
class CenterListRow extends StatelessWidget {
  final center_model.Center center;
  final VoidCallback onTap;
  final double minHeight;

  const CenterListRow({
    super.key,
    required this.center,
    required this.onTap,
    this.minHeight = 64,
  });

  @override
  Widget build(BuildContext context) {
    final address = center.address ?? '';
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(center.name, style: AppTextStyles.listTitle),
                    if (address.isNotEmpty) ...[
                      const Gap(3),
                      Text(address, style: AppTextStyles.bodySm),
                    ],
                  ],
                ),
              ),
              Icon(
                AppIcons.chevronRightBold,
                size: 18,
                color: AppColors.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
