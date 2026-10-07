import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String _font = 'WantedSans';

  static TextStyle _base({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double height = 1.5,
    double letterSpacing = -0.2,
  }) => TextStyle(
    fontFamily: _font,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  // ── Page Titles (홈 화면 대제목) ──────────────────────────────────────────
  static TextStyle get display => _base(
    size: 34,
    weight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -1.0,
  );

  static TextStyle get h1 => _base(
    size: 24,
    weight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.8,
  );

  // ── Navigation Titles (서브 화면 제목) ───────────────────────────────────
  static TextStyle get h2 => _base(
    size: 20,
    weight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.5,
  );

  static TextStyle get h3 => _base(
    size: 17,
    weight: FontWeight.w700,
    height: 1.4,
    letterSpacing: -0.3,
  );

  static TextStyle get h4 => _base(
    size: 15,
    weight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.2,
  );

  // ── Content Titles ────────────────────────────────────────────────────────
  // 카드 제목, 리스트 아이템 제목
  static TextStyle get headline => _base(
    size: 16,
    weight: FontWeight.w600,
    height: 1.45,
    letterSpacing: -0.3,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static TextStyle get body => _base(
    size: 15,
    weight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.6,
    letterSpacing: -0.2,
  );

  static TextStyle get bodyLarge => _base(
    size: 16,
    weight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.55,
    letterSpacing: -0.2,
  );

  static TextStyle get bodySmall => _base(
    size: 14,
    weight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
    letterSpacing: -0.1,
  );

  // ── Supporting ────────────────────────────────────────────────────────────
  static TextStyle get callout => _base(
    size: 15,
    weight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
    letterSpacing: -0.1,
  );

  static TextStyle get caption => _base(
    size: 13,
    weight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
    letterSpacing: -0.1,
  );

  static TextStyle get captionSmall => _base(
    size: 12,
    weight: FontWeight.w500,
    color: AppColors.textTertiary,
    height: 1.35,
    letterSpacing: 0,
  );

  // 섹션 헤더, 버튼 텍스트, 뱃지에 사용
  static TextStyle get label => _base(
    size: 15,
    weight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
    letterSpacing: -0.2,
  );

  static TextStyle get labelSmall => _base(
    size: 12,
    weight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.3,
    letterSpacing: 0,
  );

  // 사용하지 않는 letterSpacing: 1.0 제거
  static TextStyle get overline => _base(
    size: 11,
    weight: FontWeight.w600,
    color: AppColors.textTertiary,
    height: 1.3,
    letterSpacing: -0.1,
  );

  static TextStyle get button => _base(
    size: 16,
    weight: FontWeight.w600,
    color: AppColors.textOnAccent,
    height: 1.0,
    letterSpacing: -0.2,
  );

  // ── Numeric ───────────────────────────────────────────────────────────────
  static TextStyle get stat => _base(
    size: 44,
    weight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.0,
    letterSpacing: -2.0,
  );

  static TextStyle get numberLarge => _base(
    size: 30,
    weight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.0,
    letterSpacing: -1.0,
  );

  static TextStyle get numberMedium => _base(
    size: 22,
    weight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.0,
    letterSpacing: -0.6,
  );
}
