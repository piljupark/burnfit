import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_bottom_sheet.dart';
import 'app_motion.dart';

/// 세트 사이 휴식 타이머 (앱 전체에 하나). 운동 화면에서 세트를 완료하면 시작하고,
/// 홈 바로가기 '휴식 타이머'에서 직접 시작할 수도 있다.
class RestTimer extends ChangeNotifier {
  RestTimer._();

  static final instance = RestTimer._();

  Timer? _ticker;
  int _total = 0;
  int _remaining = 0;

  bool get isRunning => _ticker != null;
  int get remaining => _remaining;

  /// 남은 비율 1 → 0.
  double get fraction => _total == 0 ? 0 : _remaining / _total;

  void start(int seconds) {
    if (seconds <= 0) return;
    _ticker?.cancel();
    _total = seconds;
    _remaining = seconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void addSeconds(int seconds) {
    if (!isRunning) return;
    _remaining += seconds;
    _total = math.max(_total, _remaining);
    notifyListeners();
  }

  void skip() => _stop();

  void _tick() {
    _remaining -= 1;
    if (_remaining <= 0) {
      HapticFeedback.mediumImpact();
      _stop();
      return;
    }
    notifyListeners();
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    _remaining = 0;
    notifyListeners();
  }
}

/// 휴식 중 막대 (시안 Workout): 64 높이 검정 막대(반경 20) + 40 진행 고리 +
/// '휴식 중' / 남은 시간 + '+30초' · '건너뛰기'. 타이머가 멈춰 있으면 그리지 않는다.
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({super.key});

  static String _format(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final timer = RestTimer.instance;
    return ListenableBuilder(
      listenable: timer,
      builder: (context, _) {
        if (!timer.isRunning) return const SizedBox.shrink();
        // 시안 `rise`: 나타날 때 아래 16에서 올라온다 (.45s ease-out).
        return AppEntrance(
          offset: const Offset(0, 16),
          duration: const Duration(milliseconds: 450),
          child: Semantics(
            liveRegion: true,
            label: '휴식 중, ${timer.remaining}초 남음',
            child: Container(
              height: 64,
              padding: const EdgeInsets.fromLTRB(14, 0, AppSpacing.md, 0),
              decoration: BoxDecoration(
                color: AppColors.timerBar,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(child: _CountdownRing(timer.fraction)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '휴식 중',
                            style: AppTextStyles.bodySm.copyWith(
                              fontSize: 12,
                              height: 16 / 12,
                              color: AppColors.timerCaption,
                            ),
                          ),
                          Text(
                            _format(timer.remaining),
                            // 시안 Main 계열 Workout: 20/500 = Bold
                            style: AppTextStyles.title.bold.copyWith(
                              color: Colors.white,
                              height: 24 / 20,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _BarButton(label: '+30초', onTap: () => timer.addSeconds(30)),
                  // 시안: 막대 안 모든 요소 사이 14
                  const SizedBox(width: 14),
                  _BarButton(label: '건너뛰기', onTap: timer.skip),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BarButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: AppColors.timerButton,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Text(
              label,
              style: AppTextStyles.buttonLabel.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// 진행 고리 (40): 남은 비율이 줄 때는 1초 동안 일정한 속도로 이어서 줄고(시안 `ring`: linear),
/// 다시 시작·+30초로 늘 때는 바로 그 값으로 간다.
class _CountdownRing extends StatefulWidget {
  final double fraction;

  const _CountdownRing(this.fraction);

  @override
  State<_CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<_CountdownRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
    value: 1,
  );
  late double _from = widget.fraction;
  late double _to = widget.fraction;

  double get _value => _from + (_to - _from) * _controller.value;

  @override
  void didUpdateWidget(_CountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fraction == _to) return;
    if (widget.fraction < _to && !AppMotion.reduced(context)) {
      _from = _value;
      _to = widget.fraction;
      _controller.forward(from: 0);
    } else {
      _from = widget.fraction;
      _to = widget.fraction;
      _controller.value = 1;
    }
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
        size: const Size.square(40),
        painter: _RingPainter(_value),
      ),
    );
  }
}

/// 진행 고리: 반지름 18, 선 3. 바탕 고리 위에 남은 비율만큼 주황 호.
class _RingPainter extends CustomPainter {
  final double fraction;

  const _RingPainter(this.fraction);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = 18.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, paint..color = AppColors.timerTrack);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      paint
        ..color = AppColors.primary
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

/// 홈 바로가기 '휴식 타이머': 시간을 골라 바로 시작한다.
Future<void> showRestTimerSheet(BuildContext context) {
  const options = [60, 90, 120, 180];
  return showAppBottomSheet<void>(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppBottomSheetHeader(title: '휴식 타이머'),
        for (final seconds in options)
          AppSheetAction(
            icon: AppIcons.timer,
            label: seconds % 60 == 0
                ? '${seconds ~/ 60}분'
                : '${seconds ~/ 60}분 ${seconds % 60}초',
            onTap: () {
              RestTimer.instance.start(seconds);
              Navigator.of(context).pop();
            },
          ),
      ],
    ),
  );
}
