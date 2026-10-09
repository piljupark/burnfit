import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_motion.dart';

/// 숫자 칸: 라벨(13) + 값·단위(같은 크기, 값 500 / 단위 400 회색, 띄우지 않고 붙여 씀) + (선택) 추세.
/// 여러 칸을 나란히 두려면 [AppStatStrip]/[AppStatGrid]를 쓴다 (회색 칸, 사이 8).
/// [icon]·[isHighlight]·[accentColor]는 기존 호출부 호환용 — 색과 아이콘으로 강조하지 않는다.
///
/// 작은 칸(시안 MemB-Profile 인바디 · MemA-Stats 보조 칸)은
/// `padding: EdgeInsets.all(12)` / `EdgeInsets.symmetric(h:14, v:12)`, `labelSize: 12`, `labelGap: 2`로 줄인다.
class AppKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData? icon;
  final bool isHighlight;
  final Color? accentColor;
  final String? trend;
  final bool? trendUp;
  final bool framed;
  final double valueSize;

  /// 칸 안쪽 여백 (기본 16)
  final EdgeInsetsGeometry padding;

  /// 라벨 글자 크기 (기본 13)
  final double labelSize;

  /// 라벨 ↔ 값 간격 (기본 4)
  final double labelGap;

  /// 추세 글자 크기 (기본 13) · 값 ↔ 추세 간격 (기본 4)
  final double trendSize;
  final double trendGap;

  /// 값 글자색 (빈 값 '-'을 흐리게 그릴 때)
  final Color? valueColor;

  /// 값 Bold — 기준 시안 계열(AdminHome 숫자 칸)
  final bool bold;

  const AppKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.icon,
    this.isHighlight = false,
    this.accentColor,
    this.trend,
    this.trendUp,
    this.framed = true,
    this.valueSize = 28,
    this.padding = const EdgeInsets.all(AppSpacing.base),
    this.labelSize = 13,
    this.labelGap = AppSpacing.xs,
    this.trendSize = 13,
    this.trendGap = AppSpacing.xs,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueBase = AppTextStyles.displayMd.copyWith(
      fontSize: valueSize,
      height: 1.2,
      letterSpacing: valueSize * -0.019,
      color: valueColor,
    );
    final valueStyle = bold ? valueBase.bold : valueBase;
    final cell = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySm.copyWith(
              fontSize: labelSize,
              letterSpacing: labelSize * -0.019,
              color: framed ? AppColors.body : AppColors.mute,
            ),
          ),
          SizedBox(height: labelGap),
          // 값과 단위는 한 덩어리로 붙여 쓴다 (시안: 값 500 + 단위 400 mute, 사이 여백 없음)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.mute,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          ),
          if (trend != null) ...[
            SizedBox(height: trendGap),
            Text(
              '${trendUp == true
                  ? '+'
                  : trendUp == false
                  ? '−'
                  : ''}${trend!.replaceFirst(RegExp(r'^[+\-−]'), '')}',
              style: AppTextStyles.counter.copyWith(
                fontSize: trendSize,
                letterSpacing: trendSize * -0.019,
              ),
            ),
          ],
        ],
      ),
    );
    if (!framed) return cell;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: cell,
    );
  }
}

/// 칸이 차례로 떠오르는 움직임 설정 (시안 `up`: 아래 10에서, .5s ease-out).
/// [start] + 순번 × [step]만큼 늦게 시작한다.
class AppStatEntrance {
  final Duration start;
  final Duration step;

  const AppStatEntrance({
    this.start = Duration.zero,
    this.step = const Duration(milliseconds: 80),
  });
}

/// 가로 숫자 칸 줄: 회색 칸을 8 간격으로 나란히. 화면 폭에 두면 좌우 20 여백을 스스로 둔다
/// (시트처럼 이미 여백이 있는 곳은 [padded] false).
/// [bottomBorder]·[topBorder]는 호출부 호환용 — 선은 긋지 않는다.
class AppStatStrip extends StatelessWidget {
  final List<Widget> cells;
  final bool bottomBorder;
  final bool topBorder;
  final bool padded;

  /// 칸 모서리 (기본 18, 작은 칸 14)
  final double radius;

  /// 칸이 차례로 떠오르게 한다 (null이면 움직이지 않음)
  final AppStatEntrance? entrance;

  const AppStatStrip({
    super.key,
    required this.cells,
    this.bottomBorder = true,
    this.topBorder = false,
    this.radius = AppRadius.button,
    this.entrance,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: padded ? AppSpacing.screenH : 0,
      ),
      child: _tiles(cells, radius: radius, entrance: entrance),
    );
  }
}

Widget _tiles(
  List<Widget> cells, {
  double radius = AppRadius.button,
  AppStatEntrance? entrance,
  int firstIndex = 0,
}) {
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _maybeEntrance(
              entrance,
              firstIndex + i,
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.canvasCard,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: cells[i],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _maybeEntrance(AppStatEntrance? entrance, int index, Widget child) {
  if (entrance == null) return child;
  return AppEntrance(
    delay: entrance.start + entrance.step * index,
    child: child,
  );
}

/// 2열 숫자 격자: 회색 칸, 가로·세로 사이 8 (관리자 홈 숫자 칸).
class AppStatGrid extends StatelessWidget {
  final List<Widget> cells;

  /// 칸 모서리 (기본 18, 작은 칸 14)
  final double radius;

  /// 칸이 차례로 떠오르게 한다 (null이면 움직이지 않음)
  final AppStatEntrance? entrance;

  const AppStatGrid({
    super.key,
    required this.cells,
    this.radius = AppRadius.button,
    this.entrance,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: AppSpacing.sm));
      rows.add(
        i + 1 < cells.length
            ? _tiles(
                [cells[i], cells[i + 1]],
                radius: radius,
                entrance: entrance,
                firstIndex: i,
              )
            : Row(
                children: [
                  Expanded(
                    child: _tiles(
                      [cells[i]],
                      radius: radius,
                      entrance: entrance,
                      firstIndex: i,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(child: SizedBox()),
                ],
              ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Column(children: rows),
    );
  }
}
