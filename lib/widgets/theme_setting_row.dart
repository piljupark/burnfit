import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../services/theme_controller.dart';
import 'app_action_row.dart';
import 'app_bottom_sheet.dart';
import 'app_motion.dart';

/// 마이 → 계정의 '화면 테마' 줄 (회원·트레이너·관리자 공통). 누르면 선택 시트.
/// [plain]이면 아이콘 없는 글자 줄([AppPlainRow], 회원 마이).
class ThemeSettingRow extends StatelessWidget {
  final bool plain;

  const ThemeSettingRow({super.key, this.plain = false});

  void _open(BuildContext context) =>
      showAppBottomSheet<void>(context: context, child: const _ThemeSheet());

  @override
  Widget build(BuildContext context) {
    final choice = context.watch<ThemeController>().choice;
    if (plain) {
      return AppPlainRow(
        label: '화면 테마',
        value: choice.label,
        onTap: () => _open(context),
      );
    }
    return AppActionRow(
      icon: AppIcons.theme,
      label: '화면 테마',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(choice.label, style: AppTextStyles.bodySm),
          const SizedBox(width: AppSpacing.xs),
          Icon(AppIcons.forward, size: AppSize.icon, color: AppColors.mute),
        ],
      ),
      onTap: () => _open(context),
    );
  }
}

/// 화면 테마 시트 (시안 MemB-ThemeSheet): 머리(보조 14 mute) → 위 12 → 56 높이 줄 3개
/// (16 글자, 선택 줄 500 + 오른쪽 체크 22 · 선 2.4, 줄 사이 hairline, 마지막 줄 선 없음).
/// 체크는 그려지듯 나타난다 (시안 `draw`: .35s ease-out, 시트를 열 때는 .5초 뒤).
class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final choices = AppThemeChoice.values;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppBottomSheetHeader(
          title: '화면 테마',
          subtitle: '이 기기에만 적용돼요.',
          mutedSubtitle: true,
          gap: AppSpacing.md,
        ),
        for (var i = 0; i < choices.length; i++)
          Semantics(
            inMutuallyExclusiveGroup: true,
            selected: choices[i] == controller.choice,
            button: true,
            label: choices[i] == AppThemeChoice.system
                ? '${choices[i].label}, 기기의 다크 모드를 따릅니다'
                : choices[i].label,
            excludeSemantics: true,
            child: InkWell(
              onTap: () => controller.select(choices[i]),
              child: Container(
                height: AppSize.listRow,
                decoration: i == choices.length - 1
                    ? null
                    : BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.hairline),
                        ),
                      ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        choices[i].label,
                        style: choices[i] == controller.choice
                            ? AppTextStyles.input.medium
                            : AppTextStyles.input,
                      ),
                    ),
                    if (choices[i] == controller.choice)
                      _DrawnCheck(key: ValueKey(choices[i])),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 체크 22 (선 2.4, ink): 선이 앞에서부터 그려진다.
/// 처음 그릴 때는 시트가 올라온 뒤(.5초) 그리고, 선택을 바꾸면 바로 그린다.
class _DrawnCheck extends StatefulWidget {
  const _DrawnCheck({super.key});

  @override
  State<_DrawnCheck> createState() => _DrawnCheckState();
}

class _DrawnCheckState extends State<_DrawnCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    // 시트가 아직 올라오는 중이면(처음 열 때) .5초 기다린다
    final opening = ModalRoute.of(context)?.animation?.isCompleted == false;
    final delay = opening ? const Duration(milliseconds: 500) : Duration.zero;
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: const Size(22, 22),
        painter: _CheckPainter(
          progress: Curves.easeOut.transform(_controller.value),
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// 시안 경로 m5 12 5 5 9-10 (24 기준), 선 2.4, 둥근 끝.
class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    canvas.scale(size.width / 24, size.height / 24);
    final path = Path()
      ..moveTo(5, 12)
      ..lineTo(10, 17)
      ..lineTo(19, 7);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress || old.color != color;
}
