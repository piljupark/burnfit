import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_motion.dart';

/// 세트 입력 줄의 공용 부품 (회원 운동·트레이너 PT 기록이 함께 쓴다).
///
/// - 완료 = 주황 채운 원 + 굵은 체크, 진행 중 = ink 외곽선 원, 대기 = 흐린 외곽선 원.
/// - 값 상자: 기본 canvasSoft · 높이 36 · 진행 중 줄 ink 테두리.
///   [SetValueField.card]는 회색 카드 안의 흰 상자(높이 40, 반경 12, 17/700, 테두리 없음 — 시안 Main 계열 Workout).

const double kSetValueHeight = 36;
const double kSetCheckSize = 26;

/// 세트 완료 토글 (터치 영역 44, 스크린리더 "n세트 완료").
class SetDoneButton extends StatelessWidget {
  final int number;
  final bool done;
  final bool current;
  final VoidCallback onTap;

  /// 원 지름 (기본 26, 시안 Workout은 36 + 체크 18)
  final double size;

  /// 완료로 바뀔 때 원이 튀어나오고(시안 `pop`) 체크 선이 그려진다(시안 `draw`).
  /// 기본 false(예전 모양 그대로). 켜면 체크를 시안 선(2.6/24)으로 직접 그린다.
  final bool animate;

  const SetDoneButton({
    super.key,
    required this.number,
    required this.done,
    required this.current,
    required this.onTap,
    this.size = kSetCheckSize,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: done,
      label: '$number세트 완료',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: AppSize.touchMin,
          child: Center(
            child: animate
                ? _AnimatedDoneCircle(done: done, current: current, size: size)
                : Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.primary : Colors.transparent,
                      border: done
                          ? null
                          : Border.all(
                              color: current
                                  ? AppColors.ink
                                  : AppColors.outline,
                              width: 1.5,
                            ),
                    ),
                    child: done
                        ? Icon(
                            AppIcons.checkBold,
                            // 기본 26 원은 14 체크 (예전과 같게), 큰 원은 지름의 절반
                            size: size == kSetCheckSize
                                ? AppSize.iconSm
                                : size / 2,
                            color: AppColors.onPrimary,
                          )
                        : null,
                  ),
          ),
        ),
      ),
    );
  }
}

/// 완료 원 (움직이는 판): 완료로 바뀌면 원이 .4 → 1.18 → 1 (.5s),
/// 체크 선은 .2s 뒤 .35s 동안 ease-out으로 그려진다.
class _AnimatedDoneCircle extends StatefulWidget {
  final bool done;
  final bool current;
  final double size;

  const _AnimatedDoneCircle({
    required this.done,
    required this.current,
    required this.size,
  });

  @override
  State<_AnimatedDoneCircle> createState() => _AnimatedDoneCircleState();
}

class _AnimatedDoneCircleState extends State<_AnimatedDoneCircle>
    with SingleTickerProviderStateMixin {
  static const _delayMs = 200.0;
  static const _drawMs = 350.0;

  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_delayMs + _drawMs).round()),
    value: 1,
  );

  @override
  void didUpdateWidget(_AnimatedDoneCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.done && !oldWidget.done && !AppMotion.reduced(context)) {
      _draw.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final done = widget.done;
    return AppPop(
      play: done,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AppColors.primary : Colors.transparent,
          border: done
              ? null
              : Border.all(
                  color: widget.current ? AppColors.ink : AppColors.outline,
                  width: 1.5,
                ),
        ),
        child: done
            ? AnimatedBuilder(
                animation: _draw,
                builder: (context, _) {
                  final ms = _draw.value * (_delayMs + _drawMs);
                  final t = ((ms - _delayMs) / _drawMs).clamp(0.0, 1.0);
                  return CustomPaint(
                    size: Size.square(size / 2),
                    painter: SetCheckPainter(
                      progress: Curves.easeOut.transform(t),
                      color: AppColors.onPrimary,
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }
}

/// 시안 체크 표시 (viewBox 24: m5 12 5 5 9-10, 선 2.6, 둥근 끝). [progress]만큼만 그린다.
class SetCheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  const SetCheckPainter({this.progress = 1, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final k = size.width / 24;
    final path = Path()
      ..moveTo(5 * k, 12 * k)
      ..lineTo(10 * k, 17 * k)
      ..lineTo(19 * k, 7 * k);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(SetCheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// 세트 숫자 입력 상자 (무게·횟수·시간 등).
class SetValueField extends StatelessWidget {
  final TextEditingController controller;
  final bool decimal;
  final bool highlighted;
  final Color? textColor;
  final String semanticLabel;
  final VoidCallback onChanged;

  /// 회색 카드 안 흰 상자 모양 (높이 40, 반경 12, 17/700 Bold, 테두리 없음 — 시안 Main 계열 Workout).
  final bool card;

  const SetValueField({
    super.key,
    required this.controller,
    required this.decimal,
    required this.highlighted,
    required this.semanticLabel,
    required this.onChanged,
    this.textColor,
    this.card = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = card ? 40.0 : kSetValueHeight;
    final lineHeight = card ? 24.0 : 22.0;
    final border = card ? 0.0 : 1.0;
    final base = card ? AppTextStyles.section.bold : AppTextStyles.bodyMd;
    TextStyle valueStyle(Color color) => base.copyWith(
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: card ? AppColors.canvas : AppColors.canvasSoft,
          borderRadius: BorderRadius.circular(
            card ? AppRadius.iconBox : AppRadius.card,
          ),
          border: card
              ? null
              : Border.all(
                  color: highlighted ? AppColors.ink : AppColors.hairline,
                ),
        ),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'\d*'),
            ),
          ],
          onChanged: (_) => onChanged(),
          textAlign: TextAlign.center,
          // AppTextField와 같은 방식: 한 줄(22) + 위아래 같은 여백으로 칸(36)을 채운다.
          // (줄 높이 1.0 + 세로 가운데 정렬 방식은 웹에서 글자가 아래로 내려가 보였다)
          style: valueStyle(textColor ?? AppColors.ink),
          cursorColor: AppColors.ink,
          cursorHeight: 18,
          decoration: InputDecoration(
            filled: false,
            isDense: true,
            hintText: '-',
            hintStyle: valueStyle(AppColors.mute),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            // 한 줄 높이 + 위아래 같은 여백으로 칸을 채운다 (테두리 두께 제외)
            contentPadding: EdgeInsets.symmetric(
              vertical: (height - border * 2 - lineHeight) / 2,
            ),
          ),
        ),
      ),
    );
  }
}
