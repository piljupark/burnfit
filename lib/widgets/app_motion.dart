import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 시안 애니메이션의 공용 곡선·시간 (모든 움직임은 여기 값을 쓴다).
/// 기기의 '동작 줄이기'가 켜져 있으면 아래 위젯들은 끝 상태로 바로 그린다.
class AppMotion {
  AppMotion._();

  /// 시트·토스트 들어옴 (cubic-bezier(.2,.9,.2,1))
  static const Curve sheet = Cubic(.2, .9, .2, 1);

  /// 막대·도넛 채움 (cubic-bezier(.2,.8,.2,1))
  static const Curve fill = Cubic(.2, .8, .2, 1);

  /// 확인 창 커짐 (cubic-bezier(.2,.9,.3,1.2))
  static const Curve dialog = Cubic(.2, .9, .3, 1.2);

  /// 튀어나오는 점·체크 원 (cubic-bezier(.3,1.4,.5,1))
  static const Curve pop = Cubic(.3, 1.4, .5, 1);

  /// 스위치 손잡이 (cubic-bezier(.3,1.3,.5,1))
  static const Curve knob = Cubic(.3, 1.3, .5, 1);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// 한 번 들어오는 움직임: [offset]만큼 떨어진 곳에서 제자리로 오며 나타난다.
/// 시안의 `up`(아래 10~12에서), `slide`(왼쪽 -12에서), `row`(아래 8에서) 효과.
/// 목록은 순번 × 간격을 [delay]로 준다.
class AppEntrance extends StatefulWidget {
  final Widget child;
  final Offset offset;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const AppEntrance({
    super.key,
    required this.child,
    this.offset = const Offset(0, 10),
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.curve = Curves.easeOut,
  });

  /// 왼쪽에서 밀려 들어오는 줄 (시안 `slide`: -12px, .4s)
  const AppEntrance.slide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  }) : offset = const Offset(-12, 0),
       duration = const Duration(milliseconds: 400),
       curve = Curves.easeOut;

  @override
  State<AppEntrance> createState() => _AppEntranceState();
}

class _AppEntranceState extends State<AppEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
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
    Future.delayed(widget.delay, () {
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
    final t = CurvedAnimation(parent: _controller, curve: widget.curve);
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: t.value,
        child: Transform.translate(
          offset: widget.offset * (1 - t.value),
          child: child,
        ),
      ),
    );
  }
}

/// 계속 숨 쉬듯 커졌다 작아지는 점 (시안 `pulse`·`dotpulse`: 1 → [scale] → 1, 1.6s).
class AppPulse extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration period;

  const AppPulse({
    super.key,
    required this.child,
    this.scale = 1.35,
    this.period = const Duration(milliseconds: 1600),
  });

  @override
  State<AppPulse> createState() => _AppPulseState();
}

class _AppPulseState extends State<AppPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
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
      child: widget.child,
      builder: (context, child) {
        // 0 → 1 → 0 (ease-in-out)
        final v = _controller.value;
        final tri = v < 0.5 ? v * 2 : (1 - v) * 2;
        final s = 1 + (widget.scale - 1) * Curves.easeInOut.transform(tri);
        return Transform.scale(scale: s, child: child);
      },
    );
  }
}

/// 왼쪽에서 오른쪽으로 차오르는 막대 채움 (시안 `grow`·`fill`·`growx`: scaleX 0 → 1).
/// 막대 바탕은 부르는 쪽이 그리고, 이 위젯은 채움 [child]만 키운다.
class AppGrow extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Axis axis;

  const AppGrow({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 900),
    this.delay = Duration.zero,
    this.axis = Axis.horizontal,
  });

  @override
  State<AppGrow> createState() => _AppGrowState();
}

class _AppGrowState extends State<AppGrow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
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
    Future.delayed(widget.delay, () {
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
    final t = CurvedAnimation(parent: _controller, curve: AppMotion.fill);
    final horizontal = widget.axis == Axis.horizontal;
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (context, child) => Transform(
        alignment: horizontal ? Alignment.centerLeft : Alignment.bottomCenter,
        transform: horizontal
            ? Matrix4.diagonal3Values(t.value, 1, 1)
            : Matrix4.diagonal3Values(1, t.value, 1),
        child: child,
      ),
    );
  }
}

/// 한 번 튀어나오는 크기 변화 (시안 `pop`: 0.4 → 1.18 → 1, .5s).
/// [play]가 false → true로 바뀔 때마다 다시 재생한다 (예: 세트 완료 체크).
/// [onMount]면 처음 나타날 때도 [delay] 뒤 한 번 재생한다 (예: 선택한 센터 체크).
class AppPop extends StatefulWidget {
  final Widget child;
  final bool play;
  final double from;
  final bool onMount;
  final Duration delay;

  const AppPop({
    super.key,
    required this.child,
    this.play = true,
    this.from = 0.4,
    this.onMount = false,
    this.delay = Duration.zero,
  });

  @override
  State<AppPop> createState() => _AppPopState();
}

class _AppPopState extends State<AppPop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: widget.onMount ? 0 : 1,
  );
  bool _mounted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mounted || !widget.onMount) return;
    _mounted = true;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(AppPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play && !AppMotion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _controller, curve: AppMotion.pop);
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (context, child) => Transform.scale(
        scale: widget.from + (1 - widget.from) * t.value,
        child: child,
      ),
    );
  }
}

/// 좌우로 흔들림 (시안 `shake`: 0·60·100% 제자리, 10·30·50% −4, 20·40% +4).
/// [trigger] 값이 바뀔 때마다 한 번 흔든다 (예: 오류가 새로 날 때).
class AppShake extends StatefulWidget {
  final Widget child;
  final Object? trigger;

  const AppShake({super.key, required this.child, this.trigger});

  @override
  State<AppShake> createState() => _AppShakeState();
}

class _AppShakeState extends State<AppShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: 1,
  );

  @override
  void didUpdateWidget(AppShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger &&
        widget.trigger != null &&
        !AppMotion.reduced(context)) {
      _controller.forward(from: 0);
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
      child: widget.child,
      builder: (context, child) {
        // 0~0.6 구간에서 다섯 번 흔들고 멈춘다.
        final v = _controller.value;
        final dx = v >= 0.6
            ? 0.0
            : -4 * math.sin(v / 0.6 * 5 * math.pi / 2 * 2);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// 숨 쉬듯 흐려졌다 돌아오는 깜빡임 (시안 `blink`: 투명도 1 → .35 → 1, 1.4s).
/// 현재 시각 점, '수정 중' 글자 등. 동작 줄이기면 또렷한 상태로 멈춘다.
class AppBlink extends StatefulWidget {
  final Widget child;

  const AppBlink({super.key, required this.child});

  @override
  State<AppBlink> createState() => _AppBlinkState();
}

class _AppBlinkState extends State<AppBlink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
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
      child: widget.child,
      builder: (context, child) {
        final v = _controller.value;
        final tri = v < 0.5 ? v * 2 : (1 - v) * 2;
        return Opacity(
          opacity: 1 - 0.65 * Curves.easeInOut.transform(tri),
          child: child,
        );
      },
    );
  }
}

/// 반복 움직임의 공통 뼈대: [period]마다 0 → 1을 되풀이하고, 동작 줄이기면 [restValue]에서 멈춘다.
abstract class _AppLoopState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  Duration get period;
  double get restValue => 0;

  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      controller.stop();
      controller.value = restValue;
    } else if (!controller.isAnimating) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// 위아래로 천천히 떠다니는 그림 (시안 `float`·`bob`: 0 → -[distance] → 0, ease-in-out).
/// 빈 상태 아이콘에 쓴다.
class AppFloat extends StatefulWidget {
  final Widget child;
  final double distance;
  final Duration period;

  const AppFloat({
    super.key,
    required this.child,
    this.distance = 5,
    this.period = const Duration(milliseconds: 2600),
  });

  @override
  State<AppFloat> createState() => _AppFloatState();
}

class _AppFloatState extends _AppLoopState<AppFloat> {
  @override
  Duration get period => widget.period;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        final v = controller.value;
        final tri = v < 0.5 ? v * 2 : (1 - v) * 2;
        return Transform.translate(
          offset: Offset(0, -widget.distance * Curves.easeInOut.transform(tri)),
          child: child,
        );
      },
    );
  }
}

/// 좌우로 흔들리는 종·확성기 (시안 `ring`: 0~50% 구간에서 14° → -12° → 8° → -4° → 0, 나머지는 멈춤).
/// [angle]은 첫 흔들림 각도(도). 위쪽 가운데를 축으로 돈다.
class AppRingShake extends StatefulWidget {
  final Widget child;
  final double angle;
  final Duration period;
  final Alignment pivot;

  const AppRingShake({
    super.key,
    required this.child,
    this.angle = 14,
    this.period = const Duration(milliseconds: 2400),
    this.pivot = const Alignment(0, -0.8),
  });

  @override
  State<AppRingShake> createState() => _AppRingShakeState();
}

class _AppRingShakeState extends _AppLoopState<AppRingShake> {
  @override
  Duration get period => widget.period;

  // 시안 키프레임 비율 (첫 흔들림 각도에 대한 비)
  static const _steps = [0.0, 1.0, -0.857, 0.571, -0.286, 0.0];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        final v = controller.value;
        var deg = 0.0;
        if (v < 0.5) {
          final pos = v / 0.1; // 10% 간격
          final i = pos.floor().clamp(0, _steps.length - 2);
          final t = Curves.easeInOut.transform(pos - i);
          deg = (_steps[i] + (_steps[i + 1] - _steps[i]) * t) * widget.angle;
        }
        return Transform.rotate(
          angle: deg * math.pi / 180,
          alignment: widget.pivot,
          child: child,
        );
      },
    );
  }
}

/// 계속 도는 아이콘 (시안 `spin`: 한 바퀴 2.4초, cubic-bezier(.6,0,.4,1)). 다시 시도 버튼의 새로고침 표시.
class AppSpin extends StatefulWidget {
  final Widget child;
  final Duration period;

  const AppSpin({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 2400),
  });

  @override
  State<AppSpin> createState() => _AppSpinState();
}

class _AppSpinState extends _AppLoopState<AppSpin> {
  static const _curve = Cubic(.6, 0, .4, 1);

  @override
  Duration get period => widget.period;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) => Transform.rotate(
        angle: _curve.transform(controller.value) * 2 * math.pi,
        child: child,
      ),
    );
  }
}

/// 좌우로 천천히 기우는 그림 (시안 `wiggle`: -[angle]° ↔ [angle]°, ease-in-out). 공지 빈 상태 확성기.
class AppSway extends StatefulWidget {
  final Widget child;
  final double angle;
  final Duration period;

  const AppSway({
    super.key,
    required this.child,
    this.angle = 6,
    this.period = const Duration(milliseconds: 1800),
  });

  @override
  State<AppSway> createState() => _AppSwayState();
}

class _AppSwayState extends _AppLoopState<AppSway> {
  @override
  Duration get period => widget.period;

  // 동작 줄이기면 가운데(0°)에 멈춘다
  @override
  double get restValue => 0.25;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        // 0 → 1: -angle → angle → -angle
        final v = controller.value;
        final tri = v < 0.5 ? v * 2 : (1 - v) * 2;
        final deg =
            -widget.angle + 2 * widget.angle * Curves.easeInOut.transform(tri);
        return Transform.rotate(angle: deg * math.pi / 180, child: child);
      },
    );
  }
}
