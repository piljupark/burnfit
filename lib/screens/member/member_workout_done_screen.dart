import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/workout_parts.dart';

/// 운동 완료 화면에서 고른 행동.
/// - [home]: '확인' → 홈으로
/// - [detail]: '기록 자세히 보기' → 운동 화면의 저장된 기록으로
enum MemberWorkoutDoneAction { home, detail }

/// 꽃가루 주황 (강조색과 같은 값, const 목록에 쓰려고 따로 둔다).
const Color _confettiOrange = Color(0xFFFF7A33);

/// 개인 운동을 새로 저장한 순간 뜨는 완료 화면 (시안 Done.html, Main 계열이라 500 = Bold).
/// 주황 바탕 · 흰 카드(290×350, 반경 32, 상태줄 아래 41)에 '운동 완료'와 바벨 그림(들었다 내림 ·
/// 그림자 · 빛줄기 · 꽃가루), 양옆 불꽃·체크 배지(떠다님), 아래 '8,450kg을 들어 올렸어요' +
/// 요약 줄 + '기록 자세히 보기 >'(등장), 맨 아래 검정 '확인'.
class MemberWorkoutDoneScreen extends StatelessWidget {
  final double totalVolumeKg;
  final int exerciseCount;
  final int setCount;

  /// 유산소만 한 날은 무게 대신 운동한 분.
  final int? cardioMinutes;

  /// 지난주 같은 요일과 비교한 볼륨 차이(kg). 비교할 기록이 없으면 null.
  final double? weekOverWeekKg;

  const MemberWorkoutDoneScreen({
    super.key,
    required this.totalVolumeKg,
    required this.exerciseCount,
    required this.setCount,
    this.cardioMinutes,
    this.weekOverWeekKg,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AppPalette.light.ink;
    final number = NumberFormat('#,##0');
    final headline = cardioMinutes != null
        ? '$cardioMinutes분\n운동했어요'
        : '${number.format(totalVolumeKg.round())}kg을\n들어 올렸어요';
    final diff = weekOverWeekKg;
    final summary = [
      '$exerciseCount종목',
      '$setCount세트',
      if (diff != null && diff.round() != 0)
        diff > 0
            ? '지난주보다 ${number.format(diff.round())}kg 더'
            : '지난주보다 ${number.format(-diff.round())}kg 덜',
    ].join(' · ');

    void pop(MemberWorkoutDoneAction action) =>
        Navigator.of(context).pop(action);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) pop(MemberWorkoutDoneAction.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 시안: 카드 위 88 = 상태줄 47 + 41
                      const SizedBox(height: 41),
                      const _DoneCard(),
                      const SizedBox(height: 44),
                      // 시안 `appear`: 아래 14에서 올라오며 나타남 (.6s, .2s 뒤)
                      AppEntrance(
                        offset: const Offset(0, 14),
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 200),
                        child: Column(
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                headline,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.displayMd.bold.copyWith(
                                  fontSize: 32,
                                  height: 1.35,
                                  letterSpacing: 32 * -0.019,
                                  color: ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              summary,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMd.copyWith(
                                color: ink.withValues(alpha: 0.72),
                              ),
                            ),
                            // 시안 위 10: 44 터치 칸의 위 여백(11)이 그 몫을 한다.
                            DoneTextLink(
                              label: '기록 자세히 보기 >',
                              onTap: () => pop(MemberWorkoutDoneAction.detail),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.xl,
                ),
                child: DoneConfirmButton(
                  onTap: () => pop(MemberWorkoutDoneAction.home),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 흰 카드(290×350, 가운데) + 화면 왼쪽 끝 불꽃 원 · 오른쪽 끝 체크 상자
/// (시안 위치: 화면 왼쪽 −14 · 카드 위에서 102, 화면 오른쪽 −10 · 카드 위에서 242).
/// 움직임 (시안 Done):
/// - `lift`·`shadow`·`burst` 1.6s 반복 (바벨 들기 · 그림자 줄어듦 · 빛줄기 퍼짐)
/// - `fall` 2.6s 반복 꽃가루 5개 (지연 0 · .6 · 1.2 · .3 · 1.8s)
/// - `float` 3.2s 반복 배지 떠다님 (체크 배지는 −1.4s 앞서 시작)
class _DoneCard extends StatefulWidget {
  const _DoneCard();

  @override
  State<_DoneCard> createState() => _DoneCardState();
}

class _DoneCardState extends State<_DoneCard> with TickerProviderStateMixin {
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _fall = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  List<AnimationController> get _all => [_lift, _fall, _float];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final c in _all) {
      if (AppMotion.reduced(context)) {
        c.stop();
      } else if (!c.isAnimating) {
        c.repeat();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  /// 시안 `float`: translateY 0 · −8° → 50% −10 · 6° → 처음 (ease-in-out).
  Widget _floating(Widget child, double phase) {
    return AnimatedBuilder(
      animation: _float,
      child: child,
      builder: (context, child) {
        final t = (_float.value + phase) % 1;
        const frames = [(0.0, 0.0), (0.5, 1.0), (1.0, 0.0)];
        final p = keyframeValue(t, frames, Curves.easeInOut);
        return Transform.translate(
          offset: Offset(0, -10 * p),
          child: Transform.rotate(
            angle: (-8 + 14 * p) * math.pi / 180,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: double.infinity,
        height: 350,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: 290,
              height: 350,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 44,
                    left: 0,
                    right: 0,
                    child: Text(
                      '운동 완료',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displayMd.bold.copyWith(
                        fontSize: 34,
                        height: 40 / 34,
                        letterSpacing: 34 * -0.019,
                        color: AppPalette.light.ink,
                      ),
                    ),
                  ),
                  if (!reduced)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _fall,
                        builder: (context, _) =>
                            CustomPaint(painter: _ConfettiPainter(_fall.value)),
                      ),
                    ),
                  Positioned(
                    left: 45,
                    bottom: 24,
                    child: AnimatedBuilder(
                      animation: _lift,
                      builder: (context, _) => CustomPaint(
                        size: const Size.square(200),
                        painter: _BarbellPainter(_lift.value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: -14,
              top: 102,
              child: _floating(
                const CustomPaint(
                  size: Size.square(76),
                  painter: _FlameBadgePainter(),
                ),
                0,
              ),
            ),
            Positioned(
              right: -10,
              top: 242,
              child: _floating(
                const CustomPaint(
                  size: Size.square(70),
                  painter: _CheckBadgePainter(),
                ),
                1.4 / 3.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시안 `fall`: 꽃가루 5개 (8×12 반경 2 · 원 8×8). 위 −30 → 260으로 떨어지며 320° 돌고,
/// 투명도 0 → 15%에 1 → 끝에 0 (2.6s linear).
class _ConfettiPainter extends CustomPainter {
  final double t;

  const _ConfettiPainter(this.t);

  static const _pieces = [
    (40.0, 0.0, _confettiOrange, false),
    (90.0, 0.6, AppColors.illustYellow, true),
    (150.0, 1.2, AppColors.illustBlue, false),
    (205.0, 0.3, AppColors.illustGreen, true),
    (245.0, 1.8, _confettiOrange, false),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (left, delay, color, round) in _pieces) {
      final p = (t - delay / 2.6) % 1;
      final opacity = p < 0.15 ? p / 0.15 : (1 - p) / 0.85;
      final dy = -30 + 290 * p;
      final h = round ? 8.0 : 12.0;
      canvas.save();
      canvas.translate(left + 4, dy + h / 2);
      canvas.rotate(320 * p * math.pi / 180);
      final rect = Rect.fromCenter(center: Offset.zero, width: 8, height: h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(round ? 4 : 2)),
        Paint()..color = color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}

/// 시안 SVG(200×200)의 바벨: 그림자 타원 + 빛줄기 + 봉 + 원판 넷 + 주황 손잡이.
/// [t]는 1.6s 주기의 진행(0~1). 동작 줄이기면 0(내려 놓은 자세, 빛줄기 없음).
class _BarbellPainter extends CustomPainter {
  final double t;

  const _BarbellPainter(this.t);

  static const _liftCurve = Cubic(.5, 0, .3, 1);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);
    final ink = AppPalette.light.ink;

    // `shadow`: scaleX 1 → .6, 투명도 .18 → .08 (45~60%)
    const holdFrames = [(0.0, 0.0), (0.45, 1.0), (0.6, 1.0), (1.0, 0.0)];
    final up = keyframeValue(t, holdFrames, _liftCurve);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(100, 176),
        width: 124 * (1 - 0.4 * up),
        height: 16,
      ),
      Paint()..color = ink.withValues(alpha: 0.18 - 0.10 * up),
    );

    // `burst`: 0~40% 작고 투명 → 55% 크기 1 · 불투명 → 80~100% 1.25 · 투명 (ease-out)
    final scale = keyframeValue(t, const [
      (0.0, 0.2),
      (0.4, 0.2),
      (0.55, 1.0),
      (0.8, 1.25),
      (1.0, 1.25),
    ], Curves.easeOut);
    final opacity = keyframeValue(t, const [
      (0.0, 0.0),
      (0.4, 0.0),
      (0.55, 1.0),
      (0.8, 0.0),
      (1.0, 0.0),
    ], Curves.easeOut);
    if (opacity > 0) {
      canvas.save();
      canvas.translate(100, 100);
      canvas.scale(scale);
      canvas.translate(-100, -100);
      final rays = Paint()
        ..color = AppColors.illustBurst.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(100, 30), const Offset(100, 14), rays);
      canvas.drawLine(const Offset(64, 44), const Offset(54, 32), rays);
      canvas.drawLine(const Offset(136, 44), const Offset(146, 32), rays);
      canvas.drawLine(const Offset(44, 74), const Offset(28, 74), rays);
      canvas.drawLine(const Offset(156, 74), const Offset(172, 74), rays);
      canvas.restore();
    }

    // `lift`: translateY 18 → −14 (45~60%) → 18
    canvas.translate(0, 18 - 32 * up);
    void rrect(double x, double y, double w, double h, double r, Color c) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        Paint()..color = c,
      );
    }

    rrect(40, 96, 120, 12, 6, AppColors.timerTrack);
    rrect(26, 70, 22, 64, 8, ink);
    rrect(8, 80, 18, 44, 7, ink);
    rrect(152, 70, 22, 64, 8, ink);
    rrect(174, 80, 18, 44, 7, ink);
    rrect(80, 93, 40, 18, 9, AppColors.primary);
  }

  @override
  bool shouldRepaint(_BarbellPainter oldDelegate) => oldDelegate.t != t;
}

/// 흰 원(반지름 30, 90%) 안 주황 불꽃.
class _FlameBadgePainter extends CustomPainter {
  const _FlameBadgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 76);
    canvas.drawCircle(
      const Offset(38, 38),
      30,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    final flame = Path()
      ..moveTo(38, 20)
      ..cubicTo(39, 27, 48, 30, 48, 39)
      ..arcToPoint(const Offset(28, 39), radius: const Radius.circular(10))
      ..cubicTo(28, 34, 30.5, 32, 32, 29)
      ..cubicTo(32.6, 31.5, 34, 32.6, 35.8, 32.6)
      ..cubicTo(34.5, 27.6, 35.8, 24, 38, 20)
      ..close();
    canvas.drawPath(flame, Paint()..color = AppColors.newDot);
  }

  @override
  bool shouldRepaint(_FlameBadgePainter oldDelegate) => false;
}

/// 흰 둥근 상자(54, 반경 16, 90%) 안 검정 체크.
class _CheckBadgePainter extends CustomPainter {
  const _CheckBadgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 70);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 8, 54, 54),
        const Radius.circular(16),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawPath(
      Path()
        ..moveTo(22, 36)
        ..lineTo(31, 45)
        ..lineTo(48, 26),
      Paint()
        ..color = AppPalette.light.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckBadgePainter oldDelegate) => false;
}
