import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/app_colors.dart';
import 'app_motion.dart';

/// 흐른 시간(초)으로 다시 그리는 반복 그림. 기기의 '동작 줄이기'가 켜져 있으면 0초에 멈춘다.
class _Loop extends StatefulWidget {
  final Widget Function(BuildContext context, double seconds) builder;

  const _Loop({required this.builder});

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (elapsed) => setState(() => _seconds = elapsed.inMicroseconds / 1e6),
  );
  double _seconds = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      if (_ticker.isActive) _ticker.stop();
      _seconds = 0;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: widget.builder(context, _seconds));
}

/// 반복 주기 안의 위치 0~1 ([delay]만큼 늦게 시작).
double _phase(double seconds, double period, [double delay = 0]) {
  final t = seconds - delay;
  if (t <= 0) return 0;
  return (t % period) / period;
}

/// 0 → 1 → 0 (가운데 꼭짓점, ease-in-out) — CSS 0%·100% / 50% 키프레임.
double _wave(double phase) {
  final tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  return Curves.easeInOut.transform(tri);
}

// ── 불꽃 ─────────────────────────────────────────────────────────────────

/// 스플래시 브랜드 표시 (시안 Com-Splash): 120 상자에 주황 원 두 개가 차례로 퍼지고(2.2s, 1.1s 차이),
/// 가운데 92 주황 원 안 흰 불꽃이 흔들린다.
class SplashFlameMark extends StatelessWidget {
  const SplashFlameMark({super.key});

  @override
  Widget build(BuildContext context) {
    return _Loop(
      builder: (context, s) => SizedBox.square(
        dimension: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final delay in [0.0, 1.1])
              _Ring(
                // 퍼지는 원: scale .6→1.5, 투명도 .5→0 (ease-out)
                progress: Curves.easeOut.transform(_phase(s, 2.2, delay)),
                started: s >= delay,
                size: 120,
                from: 0.6,
                to: 1.5,
                opacity: 0.5,
              ),
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _Flame(seconds: s, height: 52, outer: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// 작은 불꽃 (시안 Main '3일째 운동 중' 앞, 22×26): 주황 겉불꽃 + 노란 속불꽃, 흔들림.
class FlameIcon extends StatelessWidget {
  final double height;

  const FlameIcon({super.key, this.height = 26});

  @override
  Widget build(BuildContext context) {
    return _Loop(
      builder: (context, s) =>
          _Flame(seconds: s, height: height, outer: AppColors.primary),
    );
  }
}

/// 겉불꽃 `flick`(1.1s: 기울기 −2°↔2°, 크기 1,1 ↔ .94,1.08)과
/// 속불꽃 `inner`(.8s: 위로 살짝 + .85배)를 아래 90% 지점 기준으로 그린다.
class _Flame extends StatelessWidget {
  final double seconds;
  final double height;
  final Color outer;

  const _Flame({
    required this.seconds,
    required this.height,
    required this.outer,
  });

  @override
  Widget build(BuildContext context) {
    final f = _wave(_phase(seconds, 1.1));
    final i = _wave(_phase(seconds, 0.8));
    return CustomPaint(
      size: Size(height * 22 / 26, height),
      painter: _FlamePainter(
        outer: outer,
        outerRotate: (-2 + 4 * f) * math.pi / 180,
        outerScale: Offset(1 - 0.06 * f, 1 + 0.08 * f),
        innerScale: 1 - 0.15 * i,
        innerLift: (height >= 40 ? 2 : 1) * i,
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  final Color outer;
  final double outerRotate;
  final Offset outerScale;
  final double innerScale;
  final double innerLift;

  const _FlamePainter({
    required this.outer,
    required this.outerRotate,
    required this.outerScale,
    required this.innerScale,
    required this.innerLift,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22, size.height / 26);
    // 기준점: 가로 가운데, 세로 90%
    const pivot = Offset(11, 26 * 0.9);
    final outerPath = Path()
      ..moveTo(11, 1)
      ..cubicTo(12, 6, 19, 9, 19, 16)
      ..arcToPoint(const Offset(3, 16), radius: const Radius.circular(8))
      ..cubicTo(3, 12, 5, 10, 6, 8)
      ..cubicTo(6.5, 10, 7.5, 11, 9, 11)
      ..cubicTo(8, 7, 9, 4, 11, 1)
      ..close();
    final inner = Path()
      ..moveTo(11, 13)
      ..cubicTo(11.5, 15.5, 15, 16.5, 15, 20)
      ..arcToPoint(const Offset(7, 20), radius: const Radius.circular(4))
      ..cubicTo(7, 18, 8, 17, 9, 16)
      ..cubicTo(9.3, 17, 9.8, 17.5, 10.5, 17.5)
      ..cubicTo(10, 15.5, 10.5, 14.3, 11, 13)
      ..close();

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(outerRotate);
    canvas.scale(outerScale.dx, outerScale.dy);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(outerPath, Paint()..color = outer);
    canvas.restore();

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy - innerLift);
    canvas.scale(innerScale);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(inner, Paint()..color = AppColors.flameCore);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.outer != outer ||
      old.outerRotate != outerRotate ||
      old.outerScale != outerScale ||
      old.innerScale != innerScale ||
      old.innerLift != innerLift;
}

/// 퍼지며 사라지는 주황 원.
class _Ring extends StatelessWidget {
  final double progress;
  final bool started;
  final double size;
  final double from;
  final double to;
  final double opacity;

  const _Ring({
    required this.progress,
    required this.started,
    required this.size,
    required this.from,
    required this.to,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    if (!started) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity * (1 - progress),
      child: Transform.scale(
        scale: from + (to - from) * progress,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ── 승인 대기 시계 ──────────────────────────────────────────────────────

/// 승인 대기 표시 (시안 Com-Pending, 96): 퍼지는 원(2.4s) + 주황 원 · 흰 시계판 ·
/// 긴 바늘(36s에 한 바퀴) · 짧은 바늘(3s에 한 바퀴).
class PendingClockMark extends StatelessWidget {
  const PendingClockMark({super.key});

  @override
  Widget build(BuildContext context) {
    return _Loop(
      builder: (context, s) => SizedBox.square(
        dimension: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _Ring(
              progress: Curves.easeOut.transform(_phase(s, 2.4)),
              started: true,
              size: 96,
              from: 0.8,
              to: 1.45,
              opacity: 0.45,
            ),
            CustomPaint(
              size: const Size.square(96),
              // 바늘은 흰 시계판 위라 테마와 관계없이 검정.
              painter: _ClockPainter(
                face: AppColors.primary,
                hand: AppPalette.light.ink,
                longTurn: _phase(s, 36),
                shortTurn: _phase(s, 3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final Color face;
  final Color hand;
  final double longTurn;
  final double shortTurn;

  const _ClockPainter({
    required this.face,
    required this.hand,
    required this.longTurn,
    required this.shortTurn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 96);
    const center = Offset(48, 48);
    canvas.drawCircle(center, 40, Paint()..color = face);
    canvas.drawCircle(center, 26, Paint()..color = Colors.white);
    final stroke = Paint()
      ..color = hand
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    Offset tip(double length, double baseAngle, double turn) {
      final a = baseAngle + turn * 2 * math.pi;
      return center + Offset(math.cos(a), math.sin(a)) * length;
    }

    // 긴 바늘: 위(−90°)에서 시작, 짧은 바늘: 오른쪽(0°)에서 시작
    canvas.drawLine(
      center,
      tip(16, -math.pi / 2, longTurn),
      stroke..strokeWidth = 4,
    );
    canvas.drawLine(center, tip(12, 0, shortTurn), stroke..strokeWidth = 3);
    canvas.drawCircle(center, 3.5, Paint()..color = hand);
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.longTurn != longTurn ||
      old.shortTurn != shortTurn ||
      old.face != face ||
      old.hand != hand;
}

// ── 식단 그릇 ───────────────────────────────────────────────────────────

/// 식단 안내 카드 그림 (시안 Meal, 200×130): 김 세 줄이 차례로 피어오르고(2s, .6s 간격),
/// 그릇 전체가 위아래로 살짝 흔들린다(2.4s, 4px).
class MealBowlIllustration extends StatelessWidget {
  const MealBowlIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return _Loop(
      builder: (context, s) => Transform.translate(
        offset: Offset(0, -4 * _wave(_phase(s, 2.4))),
        child: CustomPaint(
          size: const Size(200, 130),
          painter: _BowlPainter(
            steam: [
              for (final delay in [0.0, 0.6, 1.2])
                s >= delay ? _phase(s, 2, delay) : -1,
            ],
          ),
        ),
      ),
    );
  }
}

class _BowlPainter extends CustomPainter {
  /// 김 줄마다 주기 위치 (0~1, 아직 시작 전이면 −1)
  final List<double> steam;

  const _BowlPainter({required this.steam});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 130);
    final starts = [(78.0, 40.0), (100.0, 36.0), (122.0, 40.0)];
    for (var k = 0; k < starts.length; k++) {
      final p = steam[k];
      if (p < 0) continue;
      // 0%: 아래 6 · 투명 → 40%: 불투명 .9 → 100%: 위 14 · 투명 (ease-out)
      final e = Curves.easeOut.transform(p);
      final dy = 6 - 20 * e;
      final opacity = p < 0.4 ? 0.9 * (p / 0.4) : 0.9 * (1 - (p - 0.4) / 0.6);
      final (x, y) = starts[k];
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy)
          ..cubicTo(x - 6, y + dy - 8, x + 6, y + dy - 12, x, y + dy - 22),
        Paint()
          ..color = AppColors.illustSteam.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
    final white = Paint()..color = Colors.white;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 62), width: 140, height: 20),
      white,
    );
    canvas.drawCircle(
      const Offset(76, 58),
      12,
      Paint()..color = AppColors.illustYellow,
    );
    canvas.drawCircle(
      const Offset(102, 56),
      13,
      Paint()..color = AppColors.illustGreen,
    );
    canvas.drawCircle(
      const Offset(126, 59),
      11,
      Paint()..color = AppColors.primary,
    );
    canvas.drawPath(
      Path()
        ..moveTo(30, 62)
        ..lineTo(170, 62)
        ..arcToPoint(
          const Offset(30, 62),
          radius: const Radius.elliptical(70, 54),
        )
        ..close(),
      white,
    );
    canvas.drawLine(
      const Offset(30, 62),
      const Offset(170, 62),
      Paint()
        ..color = AppPalette.light.ink
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BowlPainter old) => true;
}

// ── 바벨 들기 ───────────────────────────────────────────────────────────

/// 운동 빈 화면 바벨 그림 (시안 `lift`: 1.8s ease-in-out 반복, 위아래 [lift]씩 들렸다 내려감).
/// 시안 SVG(viewBox 200×110) 좌표: 봉 + 안쪽 원판 둘 (+ [outerPlates]면 바깥 원판 둘) + 가운데 손잡이.
///
/// - 회원 운동(기본): 64×40 · 봉 faint · 원판 ink · 주황 손잡이 · 바깥 원판.
/// - 트레이너 PT 기록: 56×40 · 원판 mute · 바깥 원판 없음.
/// - 회원 PT 기록 빈 화면: 56×34 · 늘려 그림([stretch]) · 손잡이 없음 · 들기 5.
///
/// 동작 줄이기가 켜져 있으면 내려놓은 자세(+[lift])에 멈춘다.
class LiftingBarbellMark extends StatelessWidget {
  final Size size;
  final double lift;
  final bool outerPlates;

  /// 그림 비율을 무시하고 [size]에 꽉 채운다 (회원 PT 기록 빈 화면).
  final bool stretch;
  final Color? barColor;
  final Color? plateColor;

  /// 가운데 손잡이 색 (null이면 주황). [showHandle]이 false면 그리지 않는다.
  final Color? handleColor;
  final bool showHandle;

  const LiftingBarbellMark({
    super.key,
    this.size = const Size(64, 40),
    this.lift = 6,
    this.outerPlates = true,
    this.stretch = false,
    this.barColor,
    this.plateColor,
    this.handleColor,
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final painter = _BarbellArtPainter(
      bar: barColor ?? AppColors.faint,
      plate: plateColor ?? AppColors.ink,
      handle: showHandle ? (handleColor ?? AppColors.primary) : null,
      outerPlates: outerPlates,
      stretch: stretch,
    );
    return ExcludeSemantics(
      child: _Loop(
        builder: (context, s) => Transform.translate(
          // 0%·100% → +lift, 50% → −lift
          offset: Offset(0, lift - 2 * lift * _wave(_phase(s, 1.8))),
          child: CustomPaint(size: size, painter: painter),
        ),
      ),
    );
  }
}

class _BarbellArtPainter extends CustomPainter {
  final Color bar;
  final Color plate;
  final Color? handle;
  final bool outerPlates;
  final bool stretch;

  const _BarbellArtPainter({
    required this.bar,
    required this.plate,
    required this.handle,
    required this.outerPlates,
    required this.stretch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stretch) {
      canvas.scale(size.width / 200, size.height / 110);
    } else {
      final k = size.width / 200;
      canvas.translate(0, (size.height - 110 * k) / 2);
      canvas.scale(k);
    }
    void rrect(double x, double y, double w, double h, double r, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        Paint()..color = c,
      );
    }

    rrect(40, 49, 120, 12, 6, bar);
    rrect(26, 23, 22, 64, 8, plate);
    rrect(152, 23, 22, 64, 8, plate);
    if (outerPlates) {
      rrect(8, 33, 18, 44, 7, plate);
      rrect(174, 33, 18, 44, 7, plate);
    }
    if (handle != null) rrect(80, 46, 40, 18, 9, handle!);
  }

  @override
  bool shouldRepaint(_BarbellArtPainter old) =>
      old.bar != bar ||
      old.plate != plate ||
      old.handle != handle ||
      old.outerPlates != outerPlates ||
      old.stretch != stretch;
}

// ── 비밀번호 재설정 봉투 ─────────────────────────────────────────────────

/// 비밀번호 재설정 시트 그림 (시안 Com-PasswordReset): 회색 상자(88, 반경 18) 가운데 봉투 56×44.
/// 봉투가 3초마다 오른쪽 위로 날아갔다가(사라짐) 왼쪽 아래에서 제자리로 돌아온다 (`fly`).
class EnvelopeMark extends StatelessWidget {
  const EnvelopeMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Center(
          child: _Loop(
            builder: (context, s) {
              final p = _phase(s, 3);
              var dx = 0.0, dy = 0.0, rot = 0.0, opacity = 1.0;
              if (p > 0.3 && p <= 0.6) {
                // 30~60%: 제자리 → (26,−14) 회전 −8° · 사라짐
                final t = Curves.easeInOut.transform((p - 0.3) / 0.3);
                dx = 26 * t;
                dy = -14 * t;
                rot = -8 * t;
                opacity = 1 - t;
              } else if (p > 0.6) {
                // 61~100%: (−20, 8) 투명 → 제자리 · 나타남
                final t = Curves.easeInOut.transform(
                  ((p - 0.61) / 0.39).clamp(0.0, 1.0),
                );
                dx = -20 * (1 - t);
                dy = 8 * (1 - t);
                opacity = t;
              }
              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.rotate(
                    angle: rot * math.pi / 180,
                    child: const CustomPaint(
                      size: Size(56, 44),
                      painter: _EnvelopePainter(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EnvelopePainter extends CustomPainter {
  const _EnvelopePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ink = AppPalette.light.ink;
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 6, 48, 32),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(rect, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(6, 9)
        ..lineTo(28, 25)
        ..lineTo(50, 9),
      stroke,
    );
    canvas.drawCircle(
      const Offset(46, 10),
      6,
      Paint()..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(_EnvelopePainter oldDelegate) => false;
}
