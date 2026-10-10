import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

/// 로그인·가입 공용 부품.

/// 가운데 제목 28 + 설명 15 body (로고 없이 화면 위쪽 가운데).
class AuthHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeading({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.displayMd,
          ),
        ),
        const Gap(6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
        ),
      ],
    );
  }
}

/// 아래 글자 링크 한 줄: '처음이에요 · 가입하기' — 15 body + 가운데 점 faint + 15/500 ink (높이 48).
class AuthTextLink extends StatelessWidget {
  final String lead;
  final String action;
  final VoidCallback onTap;

  const AuthTextLink({
    super.key,
    required this.lead,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.bodyMd.copyWith(color: AppColors.body);
    return Semantics(
      button: true,
      label: '$lead $action',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(lead, style: base),
              const Gap(6),
              Text('·', style: base.copyWith(color: AppColors.faint)),
              const Gap(6),
              Text(action, style: base.copyWith(color: AppColors.ink).medium),
            ],
          ),
        ),
      ),
    );
  }
}
