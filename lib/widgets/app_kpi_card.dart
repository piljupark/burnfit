import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

import 'app_action_row.dart';
import 'app_tag.dart';

/// 숫자 칸: 라벨(13, mute) + 값(28) + 단위 + (선택) 모노 추세.
/// 여러 칸을 hairline으로 나눠 붙이려면 [AppStatStrip]/[AppStatGrid]를 쓴다.
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
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
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
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: cell,
    );
  }
}

/// 가로 숫자 칸 줄: 칸 사이와 아래를 hairline으로 나눈다 (화면 폭).
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
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: topBorder
              ? BorderSide(color: AppColors.hairline)
              : BorderSide.none,
          bottom: bottomBorder
              ? BorderSide(color: AppColors.hairline)
              : BorderSide.none,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.hairline,
                ),
              Expanded(child: cells[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// 2열 숫자 격자: 칸 사이를 1px hairline으로 나눈다 (관리자 홈 KPI).
class AppStatGrid extends StatelessWidget {
  final List<Widget> cells;

  const AppStatGrid({super.key, required this.cells});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      if (i > 0) rows.add(const AppRowDivider());
      rows.add(
        AppStatStrip(
          bottomBorder: false,
          cells: [
            cells[i],
            if (i + 1 < cells.length) cells[i + 1] else const SizedBox(),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(children: rows),
    );
  }
}
