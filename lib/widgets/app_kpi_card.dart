import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

import 'app_tag.dart';

/// 숫자 칸: 라벨(13) + 값·단위(같은 크기, 값 500 / 단위 400 회색) + (선택) 추세.
/// 여러 칸을 나란히 두려면 [AppStatStrip]/[AppStatGrid]를 쓴다 (회색 칸, 사이 8).
/// [icon]·[isHighlight]·[accentColor]는 기존 호출부 호환용 — 색과 아이콘으로 강조하지 않는다.
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
  });

  @override
  Widget build(BuildContext context) {
    final cell = Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySm.copyWith(
              color: framed ? AppColors.body : AppColors.mute,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.displayMd.copyWith(
                    fontSize: valueSize,
                    height: 1.2,
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: AppTextStyles.displayMd.copyWith(
                    fontSize: valueSize,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mute,
                  ),
                ),
              ],
            ],
          ),
          if (trend != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              monoCase(
                '${trendUp == true
                    ? '+'
                    : trendUp == false
                    ? '−'
                    : ''}${trend!.replaceFirst(RegExp(r'^[+\-−]'), '')}',
              ),
              style: AppTextStyles.counter,
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

/// 가로 숫자 칸 줄: 회색 칸을 8 간격으로 나란히 (화면 폭에 두면 좌우 여백을 스스로 둔다).
/// [bottomBorder]·[topBorder]는 호출부 호환용 — 선은 긋지 않는다.
class AppStatStrip extends StatelessWidget {
  final List<Widget> cells;
  final bool bottomBorder;
  final bool topBorder;

  const AppStatStrip({
    super.key,
    required this.cells,
    this.bottomBorder = true,
    this.topBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: _tiles(cells),
    );
  }
}

Widget _tiles(List<Widget> cells) {
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.canvasCard,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: cells[i],
            ),
          ),
        ],
      ],
    ),
  );
}

/// 2열 숫자 격자: 회색 칸, 가로·세로 사이 8 (관리자 홈 숫자 칸).
class AppStatGrid extends StatelessWidget {
  final List<Widget> cells;

  const AppStatGrid({super.key, required this.cells});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: AppSpacing.sm));
      rows.add(
        i + 1 < cells.length
            ? _tiles([cells[i], cells[i + 1]])
            : Row(
                children: [
                  Expanded(child: _tiles([cells[i]])),
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
