import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_motion.dart';

/// 시안 스위치: 트랙 52×32(켜짐 primary · 꺼짐 track), 흰 손잡이 26 + 그림자 0 1 3 18%.
/// 누름은 감싼 줄이 맡는다 (줄 전체가 토글 영역). 터치 높이 44.
/// 처음 그릴 때 켜진 스위치는 손잡이가 왼쪽에서 제자리로 미끄러진다
/// (시안 `knob`: .35s, [introDelay] 뒤, cubic-bezier(.3,1.3,.5,1)).
class AppSwitch extends StatefulWidget {
  final bool value;
  final Duration introDelay;

  const AppSwitch({
    super.key,
    required this.value,
    this.introDelay = Duration.zero,
  });

  @override
  State<AppSwitch> createState() => _AppSwitchState();
}

class _AppSwitchState extends State<AppSwitch> {
  bool _intro = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _intro = false;
      return;
    }
    Future.delayed(widget.introDelay, () {
      if (mounted) setState(() => _intro = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.value;
    final knobOn = on && !_intro;
    return SizedBox(
      width: 52,
      height: AppSize.touchMin,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : AppColors.track,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 350),
            curve: AppMotion.knob,
            alignment: knobOn ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                // 손잡이는 테마와 관계없이 흰색
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x2E000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 글자 + 스위치 한 줄 (시안 Nt-Admin-Compose): 최소 68 · 라벨 16 · (2) 설명 13 mute · 스위치.
/// 줄 전체가 토글 영역이고 아래 hairline. 좌우 여백은 부르는 쪽이 둔다.
class AppSwitchRow extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppSwitchRow({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      label: description == null ? label : '$label, $description',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: AppTextStyles.input),
                    if (description != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(description!, style: AppTextStyles.bodySm),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppSwitch(value: value),
            ],
          ),
        ),
      ),
    );
  }
}
