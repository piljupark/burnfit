import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';

/// 운동 완료 화면에서 고른 행동.
/// - [home]: '확인' → 홈으로
/// - [detail]: '기록 자세히 보기' → 운동 화면의 저장된 기록으로
enum MemberWorkoutDoneAction { home, detail }

/// 개인 운동을 새로 저장한 순간 뜨는 완료 화면 (시안 Done.html).
/// 주황 바탕 · 흰 카드(290×350, 반경 32)에 '운동 완료'와 바벨 그림, 양옆 불꽃·체크 표시,
/// 아래 '8,450kg을 들어 올렸어요' + 요약 줄 + '기록 자세히 보기 >', 맨 아래 검정 '확인'.
/// 꽃가루·바벨 들어 올리기 같은 반복 애니메이션은 넣지 않았다 (정지 그림).
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
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const _DoneCard(),
                        const SizedBox(height: 44),
                        Semantics(
                          header: true,
                          child: Text(
                            headline,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.displayMd.copyWith(
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
                        const SizedBox(height: AppSpacing.xs),
                        Semantics(
                          button: true,
                          child: InkWell(
                            onTap: () => pop(MemberWorkoutDoneAction.detail),
                            borderRadius: BorderRadius.circular(
                              AppRadius.field,
                            ),
                            child: Container(
                              height: AppSize.touchMin,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: Text(
                                '기록 자세히 보기 >',
                                style: AppTextStyles.bodyMd.copyWith(
                                  color: ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                child: SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: Material(
                    color: ink,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => pop(MemberWorkoutDoneAction.home),
                      child: Center(
                        child: Text(
                          '확인',
                          style: AppTextStyles.section.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
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
class _DoneCard extends StatelessWidget {
  const _DoneCard();

  @override
  Widget build(BuildContext context) {
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
                      style: AppTextStyles.displayMd.copyWith(
                        fontSize: 34,
                        height: 40 / 34,
                        letterSpacing: 34 * -0.019,
                        color: AppPalette.light.ink,
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 45,
                    bottom: 24,
                    child: CustomPaint(
                      size: Size.square(200),
                      painter: _BarbellPainter(),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: -14,
              top: 102,
              child: Transform.rotate(
                angle: -0.14,
                child: const CustomPaint(
                  size: Size.square(76),
                  painter: _FlameBadgePainter(),
                ),
              ),
            ),
            Positioned(
              right: -10,
              top: 242,
              child: Transform.rotate(
                angle: 0.1,
                child: const CustomPaint(
                  size: Size.square(70),
                  painter: _CheckBadgePainter(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시안 SVG(200×200)의 바벨: 그림자 타원 + 봉 + 원판 넷 + 주황 손잡이.
class _BarbellPainter extends CustomPainter {
  const _BarbellPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);
    final ink = AppPalette.light.ink;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 176), width: 124, height: 16),
      Paint()..color = ink.withValues(alpha: 0.18),
    );
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
  bool shouldRepaint(_BarbellPainter oldDelegate) => false;
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
