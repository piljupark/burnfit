import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// 스플래시 브랜드 표시: 주황 원 안 흰 불꽃 (시안 Com-Splash, 120 상자 안 92 원).
class SplashFlameMark extends StatelessWidget {
  const SplashFlameMark({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 120,
      child: Center(
        child: Container(
          width: 92,
          height: 92,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const CustomPaint(
            size: Size(44, 52),
            painter: _FlamePainter(outer: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 작은 불꽃 (시안 Main '3일째 운동 중' 앞, 22×26): 주황 겉불꽃 + 노란 속불꽃.
class FlameIcon extends StatelessWidget {
  final double height;

  const FlameIcon({super.key, this.height = 26});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(height * 22 / 26, height),
      painter: _FlamePainter(outer: AppColors.primary),
    );
  }
}

/// 시안 SVG(viewBox 22×26)의 불꽃 두 겹을 옮겨 그린다.
class _FlamePainter extends CustomPainter {
  final Color outer;

  const _FlamePainter({required this.outer});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22, size.height / 26);
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
    canvas.drawPath(outerPath, Paint()..color = outer);
    canvas.drawPath(inner, Paint()..color = AppColors.flameCore);
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => oldDelegate.outer != outer;
}

/// 승인 대기 표시: 주황 원 + 흰 시계판 + 검정 바늘 (시안 Com-Pending, 96 상자).
class PendingClockMark extends StatelessWidget {
  const PendingClockMark({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(96),
      // 바늘은 흰 시계판 위라 테마와 관계없이 검정.
      painter: _ClockPainter(
        face: AppColors.primary,
        hand: AppPalette.light.ink,
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final Color face;
  final Color hand;

  const _ClockPainter({required this.face, required this.hand});

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
    canvas.drawLine(center, const Offset(48, 32), stroke..strokeWidth = 4);
    canvas.drawLine(center, const Offset(60, 48), stroke..strokeWidth = 3);
    canvas.drawCircle(center, 3.5, Paint()..color = hand);
  }

  @override
  bool shouldRepaint(_ClockPainter oldDelegate) =>
      oldDelegate.face != face || oldDelegate.hand != hand;
}

/// 식단 안내 카드 그림 (시안 Meal, 200×130): 김 세 줄 + 그릇 위 음식 세 알 + 흰 그릇.
class MealBowlIllustration extends StatelessWidget {
  const MealBowlIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(size: Size(200, 130), painter: _BowlPainter());
  }
}

class _BowlPainter extends CustomPainter {
  const _BowlPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 130);
    final steam = Paint()
      ..color = AppColors.illustSteam
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final (x, y) in [(78.0, 40.0), (100.0, 36.0), (122.0, 40.0)]) {
      // 'c-6-8 6-12 0-22': 아래에서 위로 휘는 김
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..cubicTo(x - 6, y - 8, x + 6, y - 12, x, y - 22),
        steam,
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
  bool shouldRepaint(_BowlPainter oldDelegate) => false;
}
