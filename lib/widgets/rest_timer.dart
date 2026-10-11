import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../services/rest_timer_alerts.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'app_motion.dart';

/// 세트 사이 휴식 타이머 (앱 전체에 하나). 운동 화면에서 세트를 완료하면 시작하고,
/// 홈 바로가기 '휴식 타이머'에서 직접 시작할 수도 있다.
///
/// 남은 시간은 '끝나는 시각'에서 지금을 빼서 구한다 — 다른 앱에 가 있거나 화면을 꺼도 시간이 흐르고,
/// 돌아오면 바로 맞는 값이 보인다. 10초 전 · 끝 알림은 [RestTimerAlerts]가 맡는다
/// (앱이 앞이면 바로 진동, 뒤로 가면 기기 알림 예약).
class RestTimer extends ChangeNotifier with WidgetsBindingObserver {
  RestTimer._();

  static final instance = RestTimer._();

  /// 앞에서 돌던 타이머가 이 간격보다 늦게 깨면 앱이 잠들었다 깬 것으로 본다
  /// (그 사이 알림은 기기 알림이 이미 울렸으므로 다시 울리지 않는다).
  static const _wakeGap = Duration(milliseconds: 2500);

  Timer? _ticker;
  DateTime? _startAt;
  DateTime? _endAt;
  DateTime _lastTick = DateTime.now();
  int _total = 0;
  int _remaining = 0;
  bool _warned = false;
  bool _observing = false;
  bool _inForeground = true;

  bool get isRunning => _ticker != null;
  int get remaining => _remaining;

  /// 남은 비율 1 → 0.
  double get fraction => _total == 0 ? 0 : _remaining / _total;

  void start(int seconds) {
    if (seconds <= 0) return;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _ticker?.cancel();
    final now = DateTime.now();
    _startAt = now;
    _endAt = now.add(Duration(seconds: seconds));
    _lastTick = now;
    _total = seconds;
    _remaining = seconds;
    _warned = seconds <= RestTimerAlerts.warningSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _syncAlerts();
    notifyListeners();
  }

  void addSeconds(int seconds) {
    final endAt = _endAt;
    if (!isRunning || endAt == null) return;
    _endAt = endAt.add(Duration(seconds: seconds));
    _remaining += seconds;
    _total = math.max(_total, _remaining);
    if (_remaining > RestTimerAlerts.warningSeconds) _warned = false;
    _syncAlerts();
    notifyListeners();
  }

  void skip() => _stop();

  /// 남은 초 (올림): 0.2초 남았으면 1초로 보인다.
  int _secondsLeft(DateTime now) {
    final ms = _endAt!.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _tick() {
    if (_endAt == null) return;
    final now = DateTime.now();
    final woke = now.difference(_lastTick) > _wakeGap;
    _lastTick = now;
    _remaining = _secondsLeft(now);
    if (_remaining <= 0) {
      if (!woke) RestTimerAlerts.fireNow(RestAlertKind.done);
      _stop(keepDoneAlert: !woke);
      return;
    }
    if (!_warned && _remaining <= RestTimerAlerts.warningSeconds) {
      _warned = true;
      if (!woke) RestTimerAlerts.fireNow(RestAlertKind.warning);
    }
    notifyListeners();
  }

  /// [keepDoneAlert]: 방금 띄운 '휴식 끝' 알림(안드로이드)은 남겨 둔다.
  void _stop({bool keepDoneAlert = false}) {
    _ticker?.cancel();
    _ticker = null;
    _startAt = null;
    _endAt = null;
    _remaining = 0;
    if (keepDoneAlert) {
      RestTimerAlerts.cancelScheduled();
      RestTimerAlerts.clearOngoing();
    } else {
      RestTimerAlerts.clearAll();
    }
    notifyListeners();
  }

  /// 진행 표시는 늘 맞추고, 알림 예약은 앱이 뒤에 있을 때만 둔다.
  void _syncAlerts() {
    final endAt = _endAt;
    if (endAt == null) return;
    RestTimerAlerts.showOngoing(_startAt ?? DateTime.now(), endAt);
    if (_inForeground) {
      RestTimerAlerts.cancelScheduled();
    } else {
      RestTimerAlerts.scheduleFor(endAt);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _inForeground) return;
    _inForeground = foreground;
    if (!isRunning) return;
    if (foreground) {
      // 돌아오면 지나간 시간을 바로 반영한다 (알림은 이미 기기가 울렸다).
      _lastTick = DateTime.fromMillisecondsSinceEpoch(0);
      _tick();
      if (isRunning) RestTimerAlerts.cancelScheduled();
    } else {
      RestTimerAlerts.scheduleFor(_endAt!);
    }
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
              Navigator.of(context).pop();
              startRestTimer(context, seconds);
            },
          ),
      ],
    ),
  );
}

/// 휴식 타이머 시작. 안드로이드 14+에서 '알람 및 리마인더' 권한이 꺼져 있으면 처음 한 번만
/// 허용을 권한다 (꺼져 있으면 앱이 뒤에 있을 때 끝 알림이 몇 분 늦을 수 있다).
Future<void> startRestTimer(BuildContext context, int seconds) async {
  RestTimer.instance.start(seconds);
  if (!await RestTimerAlerts.shouldAskExactPermission() || !context.mounted) {
    return;
  }
  await showAppBottomSheet<void>(
    context: context,
    child: Builder(
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppBottomSheetHeader(
            title: '휴식 끝 알림',
            subtitle:
                '다른 앱을 쓰는 중에도 휴식이 끝나는 순간 알려 드리려면 '
                "'알람 및 리마인더'를 허용해 주세요.",
            mutedSubtitle: true,
            gap: AppSpacing.lg,
          ),
          AppButton(
            label: '허용하러 가기',
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              RestTimerAlerts.requestExactPermission();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: '나중에',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}
