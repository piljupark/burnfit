import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 이니셜 원 아바타. 배경은 일러스트 팔레트를 [seed](보통 사용자 id)로 고정 순환한다
/// — accent가 UI에 나오는 유일한 곳.
class AppAvatar extends StatelessWidget {
  final String name;
  final String seed;
  final double size;

  const AppAvatar({super.key, required this.name, String? seed, this.size = AppSize.avatar})
      : seed = seed ?? name;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    // 한글 이름은 성 다음 글자(이민지 → 민), 그 외는 첫 글자.
    final runes = trimmed.runes.toList();
    final isHangul = runes.first >= 0xAC00 && runes.first <= 0xD7A3;
    final pick = isHangul && runes.length >= 2 ? runes[1] : runes.first;
    return String.fromCharCode(pick).toUpperCase();
  }

  Color get _color {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return AppColors.avatarColors[hash % AppColors.avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
        child: Text(
          _initial,
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.onPrimary,
            fontSize: size * 0.4,
            height: 1,
          ),
        ),
      ),
    );
  }
}
