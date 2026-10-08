import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Galloway 타입 스케일.
///
/// - 굵기는 400·500 두 가지뿐. 제목·값은 500, 나머지는 400. 600 이상은 쓰지 않는다.
/// - 한 줄 안의 값+단위는 크기를 같게 하고 굵기·색으로만 구분한다.
/// - 자간은 모든 sans 스타일에 -0.019em (Flutter는 px이므로 크기 × -0.019).
/// - 글꼴은 Wanted Sans 하나. [eyebrow](묶음 머리말)·[counter](작은 숫자)도 sans다.
class AppTextStyles {
  AppTextStyles._();

  static const String sans = 'WantedSans';
  static const String mono = 'GeistMono';

  static TextStyle _sans(
    double size,
    double lineHeight, {
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: sans,
      fontSize: size,
      height: lineHeight / size,
      // 줄 여백을 글자 위아래로 똑같이 나눠, 고정 높이 칸(입력창·버튼·태그) 안에서 글자가 가운데 오게 한다.
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: weight,
      letterSpacing: size * -0.019,
      color: color ?? AppColors.ink,
    );
  }

  // ── Galloway 기본 스타일 ───────────────────────────────────────────────────
  /// 상세 화면 상단 큰 제목 (40/44)
  static TextStyle get displayLg => _sans(40, 44, weight: FontWeight.w500);

  /// 홈·탭 화면 제목 (28/34)
  static TextStyle get displayMd => _sans(28, 34, weight: FontWeight.w500);

  /// 앱바·다이얼로그·시트 제목 (20/28)
  static TextStyle get title => _sans(20, 28, weight: FontWeight.w500);

  /// 목록 항목 주 텍스트 (17/26)
  static TextStyle get bodyLg => _sans(17, 26);

  /// 기본 본문·입력값 (15/22)
  static TextStyle get bodyMd => _sans(15, 22);

  /// 보조 텍스트·캡션 (13/18, mute — 카드 위에서는 color: body로)
  static TextStyle get bodySm => _sans(13, 18, color: AppColors.mute);

  /// pill 버튼 라벨 (14/20)
  static TextStyle get buttonLabel => _sans(14, 20);

  /// 섹션 제목 (17/24, 500)
  static TextStyle get section => _sans(17, 24, weight: FontWeight.w500);

  /// 사진·작은 배지 (11/14, 500)
  static TextStyle get badge => _sans(11, 14, weight: FontWeight.w500);

  /// 묶음 머리말: 섹션 위 회색 글자 (15/22, mute). 예전 모노 머리말 자리.
  static TextStyle get eyebrow => _sans(15, 22, color: AppColors.mute);

  /// 작은 숫자·상태 글자: D-12, 12/30 (13/18, mute). 예전 모노 카운터 자리.
  static TextStyle get counter => _sans(13, 18, color: AppColors.mute);

  // ═══════════════════════════════════════════════════════════════════════════
  // 기존 이름 → 새 스케일
  // ═══════════════════════════════════════════════════════════════════════════
  static TextStyle get display => displayMd;
  static TextStyle get h1 => displayMd;
  static TextStyle get h2 => title;
  static TextStyle get h3 => bodyLg;
  static TextStyle get h4 => bodyMd;
  static TextStyle get headline => bodyLg;
  static TextStyle get body => bodyMd;
  static TextStyle get bodyLarge => bodyLg;
  static TextStyle get bodySmall => _sans(14, 20, color: AppColors.body);
  static TextStyle get callout => _sans(15, 22, color: AppColors.body);
  static TextStyle get caption => _sans(13, 18, color: AppColors.body);
  static TextStyle get captionSmall => _sans(12, 16, color: AppColors.mute);
  static TextStyle get label => bodyMd;
  static TextStyle get labelSmall => _sans(12, 16, color: AppColors.body);
  static TextStyle get overline => _sans(12, 16, color: AppColors.mute);
  static TextStyle get button =>
      buttonLabel.copyWith(color: AppColors.onPrimary);
  static TextStyle get stat => _sans(40, 44, weight: FontWeight.w500);
  static TextStyle get numberLarge => displayMd;
  static TextStyle get numberMedium => title;
}
