import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/workout_parts.dart';

/// PT 기록을 처음 저장해 세션이 '완료'로 바뀐 순간에만 뜨는 축하 화면.
/// [TrainerPtWorkoutScreen._saveWorkout]에서 push하고, 사용자가 고른 행동을 반환한다.
enum TrainerPtDoneAction { confirm, feedback }

/// PT 완료 화면 (시안 TrainerPtDone, 기준 시안이라 500 = Bold).
/// 주황 바탕 · 흰 카드(290×350, 반경 32, 상태줄 아래 41)에 'PT 완료'(34)와 남은 횟수(112)가
/// 한 칸 위로 굴러 바뀌고(이전 숫자는 흐린 회색), 빛줄기가 퍼지며 주황 원 체크가 튀어나온다.
/// 카드 양옆 달력·덤벨 배지가 떠다니고, 아래 '최도윤 회원\n6회 남았어요'(32) + 요약 줄(15)
/// + '기록 다시 보기 >'(등장), 맨 아래 검정 60 pill '확인'과 밑줄 '바로 피드백 쓰기'.
///
/// [remainingSessions]는 서버가 완료 처리하며 돌려준 차감 뒤 잔여 횟수다. 모르면(null)
/// 숫자 굴림 없이 체크만 보여 준다.
class TrainerPtDoneScreen extends StatelessWidget {
  final String memberName;
  final int? remainingSessions;
  final int exerciseCount;
  final int setCount;
  final double totalVolumeKg;

  /// 유산소만 한 PT는 무게 대신 운동한 분 (종목마다 유산소인지 가려 계산한다).
  final int? cardioMinutes;

  const TrainerPtDoneScreen({
    super.key,
    required this.memberName,
    required this.remainingSessions,
    required this.exerciseCount,
    required this.setCount,
    required this.totalVolumeKg,
    this.cardioMinutes,
  });

  @override
  Widget build(BuildContext context) {
    // 주황 바탕·흰 카드는 두 테마 공통이라 글자도 라이트 색을 쓴다.
    final ink = AppPalette.light.ink;
    final summary = [
      '$exerciseCount종목',
      '$setCount세트',
      cardioMinutes != null
          ? '$cardioMinutes분'
          : '${NumberFormat('#,##0').format(totalVolumeKg.round())}kg',
    ].join(' · ');
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final remaining = remainingSessions;

    void pop(TrainerPtDoneAction action) => Navigator.of(context).pop(action);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) pop(TrainerPtDoneAction.confirm);
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 시안: 카드 위 88 = 상태줄 47 + 41
                      const SizedBox(height: 41),
                      _DoneCard(
                        from: remaining == null ? null : remaining + 1,
                        to: remaining,
                      ),
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
                                remaining == null
                                    ? '$memberName 회원\nPT를 완료했어요'
                                    : '$memberName 회원\n$remaining회 남았어요',
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
                              label: '기록 다시 보기',
                              chevron: true,
                              onTap: () => pop(TrainerPtDoneAction.confirm),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 시안: '확인' 아래 끝 76, 링크 글자 가운데는 화면 아래에서 약 42
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.md,
                ),
                child: DoneConfirmButton(
                  onTap: () => pop(TrainerPtDoneAction.confirm),
                ),
              ),
              DoneTextLink(
                label: '바로 피드백 쓰기',
                underline: true,
                onTap: () => pop(TrainerPtDoneAction.feedback),
              ),
              SizedBox(height: math.max(bottomInset - 14, AppSpacing.sm)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 흰 카드(290×350) + 화면 왼쪽 끝 달력 배지 · 오른쪽 끝 덤벨 배지
/// (시안 위치: 왼쪽 −10 · 카드 위에서 112, 오른쪽 −8 · 카드 위에서 262).
/// 움직임 (시안 TrainerPtDone, 3s 한 주기):
/// - `roll` 0~30% 그대로 → 55% 한 칸(120) 위로 (cubic-bezier(.6,0,.3,1))
/// - `spark` 55~100% 빛줄기 .3 → 1.3배, 70%에 불투명 → 끝에 투명
/// - `pop` 55~70% 체크 원 0 → 1.2 → 80% 1, `draw` 65~85% 체크 선 그리기
/// - `float` 3.4s 반복 배지 떠다님 (덤벨 배지는 −1.6s 앞서 시작)
/// 시안의 숫자 바뀜 반복은 시연용이라 한 번만 재생한다. 동작 줄이기면 끝 상태로 그린다.
class _DoneCard extends StatefulWidget {
  /// 차감 전 · 뒤 잔여 횟수 (모르면 null — 숫자 창과 '남은 횟수'를 그리지 않는다)
  final int? from;
  final int? to;

  const _DoneCard({required this.from, required this.to});

  @override
  State<_DoneCard> createState() => _DoneCardState();
}

class _DoneCardState extends State<_DoneCard> with TickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _reveal.value = 1;
      _float.stop();
      return;
    }
    if (!_started) {
      _started = true;
      _reveal.forward(from: 0);
    }
    if (!_float.isAnimating) _float.repeat();
  }

  @override
  void dispose() {
    _reveal.dispose();
    _float.dispose();
    super.dispose();
  }

  /// 시안 `float`: translateY 0 · −6° → 50% −10 · 6° → 처음 (ease-in-out).
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
            angle: (-6 + 12 * p) * math.pi / 180,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final light = AppPalette.light;
    final number = AppTextStyles.displayLg.bold.copyWith(
      fontSize: 112,
      height: 120 / 112,
      letterSpacing: 112 * -0.019,
    );
    return Semantics(
      label: widget.to == null ? 'PT 완료' : 'PT 완료. 남은 횟수 ${widget.to}회',
      excludeSemantics: true,
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
                color: light.canvas,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 44,
                    left: 0,
                    right: 0,
                    child: Text(
                      'PT 완료',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displayMd.bold.copyWith(
                        fontSize: 34,
                        height: 40 / 34,
                        letterSpacing: 34 * -0.019,
                        color: light.ink,
                      ),
                    ),
                  ),
                  // 숫자 창 (위 130, 높이 120): 이전 숫자(흐림) → 남은 숫자(ink)
                  if (widget.from != null && widget.to != null)
                    Positioned(
                      top: 130,
                      left: 0,
                      right: 0,
                      height: 120,
                      child: ClipRect(
                        child: AnimatedBuilder(
                          animation: _reveal,
                          builder: (context, _) {
                            final roll = keyframeValue(_reveal.value, const [
                              (0.0, 0.0),
                              (0.3, 0.0),
                              (0.55, 1.0),
                              (1.0, 1.0),
                            ], const Cubic(.6, 0, .3, 1));
                            return OverflowBox(
                              alignment: Alignment.topCenter,
                              maxHeight: 240,
                              child: Transform.translate(
                                offset: Offset(0, -120 * roll),
                                child: Column(
                                  children: [
                                    for (final (value, color) in [
                                      (widget.from, light.outline),
                                      (widget.to, light.ink),
                                    ])
                                      SizedBox(
                                        height: 120,
                                        child: Center(
                                          child: Text(
                                            '$value',
                                            maxLines: 1,
                                            style: number.copyWith(
                                              color: color,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  // 빛줄기 + 주황 원 체크 (시안 SVG 290×350 좌표 그대로)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _reveal,
                      builder: (context, _) => CustomPaint(
                        painter: _CelebratePainter(
                          t: _reveal.value,
                          check: light.ink,
                        ),
                      ),
                    ),
                  ),
                  if (widget.to != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 30,
                      child: Text(
                        '남은 횟수',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMd.natural.copyWith(
                          color: light.mute,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: -10,
              top: 112,
              child: _floating(
                const CustomPaint(
                  size: Size.square(72),
                  painter: _CalendarBadgePainter(),
                ),
                0,
              ),
            ),
            Positioned(
              right: -8,
              top: 262,
              child: _floating(
                const CustomPaint(
                  size: Size.square(66),
                  painter: _DumbbellBadgePainter(),
                ),
                1.6 / 3.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 빛줄기(`spark`, 기준점 145,175)와 주황 원 체크(`pop`·`draw`, 원 198,228 r20).
class _CelebratePainter extends CustomPainter {
  final double t;
  final Color check;

  const _CelebratePainter({required this.t, required this.check});

  @override
  void paint(Canvas canvas, Size size) {
    // `spark`: 55% .3배·투명 → 70% 불투명 → 100% 1.3배·투명 (ease-out)
    final sparkScale = keyframeValue(t, const [
      (0.0, 0.3),
      (0.55, 0.3),
      (1.0, 1.3),
    ], Curves.easeOut);
    final sparkOpacity = keyframeValue(t, const [
      (0.0, 0.0),
      (0.55, 0.0),
      (0.7, 1.0),
      (1.0, 0.0),
    ], Curves.easeOut);
    if (sparkOpacity > 0) {
      canvas.save();
      canvas.translate(145, 175);
      canvas.scale(sparkScale);
      canvas.translate(-145, -175);
      final rays = Paint()
        // 시안 #FFB020에 가장 가까운 토큰 (일러스트 노랑)
        ..color = AppColors.illustBurst.withValues(alpha: sparkOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(145, 120), const Offset(145, 108), rays);
      canvas.drawLine(const Offset(190, 140), const Offset(198, 132), rays);
      canvas.drawLine(const Offset(100, 140), const Offset(92, 132), rays);
      canvas.drawLine(const Offset(210, 185), const Offset(222, 185), rays);
      canvas.drawLine(const Offset(80, 185), const Offset(68, 185), rays);
      canvas.restore();
    }

    // `pop`: 55% 0 → 70% 1.2 → 80% 1 (ease-out)
    final pop = keyframeValue(t, const [
      (0.0, 0.0),
      (0.55, 0.0),
      (0.7, 1.2),
      (0.8, 1.0),
      (1.0, 1.0),
    ], Curves.easeOut);
    if (pop <= 0) return;
    canvas.save();
    canvas.translate(198, 228);
    canvas.scale(pop);
    canvas.drawCircle(Offset.zero, 20, Paint()..color = AppColors.primary);

    // `draw`: 65~85% 체크 선 (M189 228 l6 6 12-13, 선 3.5)
    final draw = keyframeValue(t, const [
      (0.0, 0.0),
      (0.65, 0.0),
      (0.85, 1.0),
      (1.0, 1.0),
    ], Curves.easeOut);
    if (draw > 0) {
      final path = Path()
        ..moveTo(-9, 0)
        ..lineTo(-3, 6)
        ..lineTo(9, -7);
      final paint = Paint()
        ..color = check
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * draw), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CelebratePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.check != check;
}

/// 흰 둥근 상자(56×52, 반경 14, 90%) 위 달력 선 (시안 72×72).
class _CalendarBadgePainter extends CustomPainter {
  const _CalendarBadgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 72);
    final light = AppPalette.light;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 10, 56, 52),
        const Radius.circular(AppRadius.field),
      ),
      Paint()..color = light.canvas.withValues(alpha: 0.9),
    );
    final line = Paint()
      ..color = light.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(8, 24), const Offset(64, 24), line);
    canvas.drawLine(const Offset(24, 6), const Offset(24, 16), line);
    canvas.drawLine(const Offset(48, 6), const Offset(48, 16), line);
  }

  @override
  bool shouldRepaint(_CalendarBadgePainter oldDelegate) => false;
}

/// 흰 원(반지름 27, 90%) 안 덤벨 선 (시안 66×66).
class _DumbbellBadgePainter extends CustomPainter {
  const _DumbbellBadgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 66);
    final light = AppPalette.light;
    canvas.drawCircle(
      const Offset(33, 33),
      27,
      Paint()..color = light.canvas.withValues(alpha: 0.9),
    );
    final line = Paint()
      ..color = light.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(20, 33), const Offset(46, 33), line);
    canvas.drawLine(const Offset(24, 25), const Offset(24, 41), line);
    canvas.drawLine(const Offset(42, 25), const Offset(42, 41), line);
  }

  @override
  bool shouldRepaint(_DumbbellBadgePainter oldDelegate) => false;
}
