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
            painter: _FlamePainter(),
          ),
        ),
      ),
    );
  }
}

/// 시안 SVG(viewBox 22×26)의 불꽃 두 겹을 옮겨 그린다.
class _FlamePainter extends CustomPainter {
  const _FlamePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22, size.height / 26);
    final outer = Path()
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
    canvas.drawPath(outer, Paint()..color = Colors.white);
    canvas.drawPath(inner, Paint()..color = AppColors.flameCore);
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => false;
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
