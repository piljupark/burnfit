import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';

/// PT 기록을 처음 저장해 세션이 '완료'로 바뀐 순간에만 뜨는 축하 화면.
/// [TrainerPtWorkoutScreen._saveWorkout]에서 push하고, 사용자가 고른 행동을 반환한다.
enum TrainerPtDoneAction { confirm, feedback }

class TrainerPtDoneScreen extends StatefulWidget {
  final String memberName;
  final int remainingSessions;
  final int exerciseCount;
  final int setCount;
  final double totalVolumeKg;

  const TrainerPtDoneScreen({
    super.key,
    required this.memberName,
    required this.remainingSessions,
    required this.exerciseCount,
    required this.setCount,
    required this.totalVolumeKg,
  });

  @override
  State<TrainerPtDoneScreen> createState() => _TrainerPtDoneScreenState();
}

class _TrainerPtDoneScreenState extends State<TrainerPtDoneScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _controller.value = reduceMotion ? 1 : 0;
    if (!reduceMotion) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pop(TrainerPtDoneAction action) => Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context) {
    final previous = widget.remainingSessions + 1;
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pop(TrainerPtDoneAction.confirm);
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: FadeTransition(
                    opacity: fade,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.96, end: 1.0).animate(fade),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 290,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xl2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.canvas,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Column(
                              children: [
                                Text('PT 완료', style: AppTextStyles.displayMd),
                                const SizedBox(height: AppSpacing.base),
                                _RollingCount(
                                  from: previous,
                                  to: widget.remainingSessions,
                                  animation: _controller,
                                ),
                                const SizedBox(height: AppSpacing.base),
                                Text(
                                  '남은 횟수',
                                  style: AppTextStyles.bodyMd.copyWith(
                                    color: AppColors.body,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl2),
                          Text(
                            '${widget.memberName} 회원\n${widget.remainingSessions}회 남았어요',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.displayMd.copyWith(
                              color: AppColors.onPrimary,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${widget.exerciseCount}종목 · ${widget.setCount}세트 · '
                            '${widget.totalVolumeKg.toStringAsFixed(0)}kg',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.onPrimary.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          GestureDetector(
                            onTap: () => _pop(TrainerPtDoneAction.confirm),
                            child: Text(
                              '기록 다시 보기 >',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  0,
                  AppSpacing.screenH,
                  AppSpacing.sm,
                ),
                child: SizedBox(
                  height: 60,
                  child: Material(
                    color: AppColors.ink,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => _pop(TrainerPtDoneAction.confirm),
                      child: Center(
                        child: Text(
                          '확인',
                          style: AppTextStyles.bodyLg.copyWith(
                            color: AppColors.canvas,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: GestureDetector(
                  onTap: () => _pop(TrainerPtDoneAction.feedback),
                  child: Text(
                    '바로 피드백 쓰기',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.onPrimary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.onPrimary,
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

/// 숫자가 위로 한 칸 밀려 올라가며 [from] -> [to]로 바뀌는 연출.
class _RollingCount extends StatelessWidget {
  final int from;
  final int to;
  final Animation<double> animation;

  const _RollingCount({
    required this.from,
    required this.to,
    required this.animation,
  });

  static const _height = 100.0;
  static TextStyle get _style => AppTextStyles.displayLg.copyWith(
    fontSize: 96,
    height: 1.0,
    color: AppColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(animation.value);
            return Transform.translate(
              offset: Offset(0, -_height * t),
              child: Column(
                children: [
                  SizedBox(
                    height: _height,
                    child: Center(
                      child: Text(
                        '$from',
                        style: _style.copyWith(color: AppColors.outline),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _height,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(child: Text('$to', style: _style)),
                        Positioned(
                          right: 36,
                          bottom: 8,
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              AppIcons.checkBold,
                              size: 18,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
