import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Galloway 타입 스케일.
///
/// - Wanted Sans 400이 기본. 강조는 굵기가 아니라 크기·위치로 한다 (예외: [badge] 500).
/// - 자간은 모든 sans 스타일에 -0.019em (Flutter는 px이므로 크기 × -0.019).
/// - Geist Mono([eyebrow], [counter])는 영문·숫자 대문자에만 쓴다. 한글을 모노로 쓰지 않는다.
class AppTextStyles {
  AppTextStyles._();

  static const String sans = 'WantedSans';
  static const String mono = 'GeistMono';

  static TextStyle _sans(double size, double lineHeight, {Color color = AppColors.ink, FontWeight weight = FontWeight.w400}) {
    return TextStyle(
      fontFamily: sans,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: size * -0.019,
      color: color,
    );
  }

  static TextStyle _mono(double size, double lineHeight, double trackingEm, {Color color = AppColors.mute}) {
    return TextStyle(
      fontFamily: mono,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: FontWeight.w400,
      letterSpacing: size * trackingEm,
      color: color,
    );
  }

  // ── Galloway 기본 스타일 ───────────────────────────────────────────────────
  /// 상세 화면 상단 큰 제목 (40/44)
  static TextStyle get displayLg => _sans(40, 44);

  /// 홈·탭 화면 제목 (28/34)
  static TextStyle get displayMd => _sans(28, 34);

  /// 앱바·다이얼로그·시트 제목 (20/28)
  static TextStyle get title => _sans(20, 28);

  /// 목록 항목 주 텍스트 (17/26)
  static TextStyle get bodyLg => _sans(17, 26);

  /// 기본 본문·입력값 (15/22)
  static TextStyle get bodyMd => _sans(15, 22);

  /// 보조 텍스트·캡션 (13/18, mute — 카드 위에서는 color: body로)
  static TextStyle get bodySm => _sans(13, 18, color: AppColors.mute);

  /// pill 버튼 라벨 (14/20)
  static TextStyle get buttonLabel => _sans(14, 20);

  /// 사진·작은 배지 (11/14, 500 — 시스템 유일한 500)
  static TextStyle get badge => _sans(11, 14, weight: FontWeight.w500);

  /// 머리말: 월 헤더·섹션 머리말 (모노 12/16, +0.1em). 대문자 영문·숫자에만.
  static TextStyle get eyebrow => _mono(12, 16, 0.1);

  /// 숫자 카운터: D-12, 12/30, 역할 태그 (모노 11/14, +0.06em)
  static TextStyle get counter => _mono(11, 14, 0.06);

  // ═══════════════════════════════════════════════════════════════════════════
  // 기존 이름 → Galloway 스케일 (모두 400)
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
  static TextStyle get button => buttonLabel.copyWith(color: AppColors.onPrimary);
  static TextStyle get stat => _sans(40, 44);
  static TextStyle get numberLarge => displayMd;
  static TextStyle get numberMedium => title;
}
