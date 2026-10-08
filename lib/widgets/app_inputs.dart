import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';

/// 숫자 조절: − 값 단위 +. 범위를 벗어나는 쪽 버튼은 꺼진다.
/// 가운데 숫자를 누르면 숫자를 직접 입력하는 시트가 열린다 (큰 값을 한 번에 넣을 때).
class AppStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  /// 스크린리더용 이름 (예: '총 횟수')
  final String semanticLabel;

  const AppStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.min = 0,
    this.max = 999,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = AppTextStyles.title;
    return Semantics(
      label: semanticLabel,
      value: '$value$unit',
      increasedValue: value < max ? '${value + 1}$unit' : null,
      decreasedValue: value > min ? '${value - 1}$unit' : null,
      onIncrease: value < max ? () => onChanged(value + 1) : null,
      onDecrease: value > min ? () => onChanged(value - 1) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: AppIcons.remove,
            label: '$semanticLabel 줄이기',
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          Semantics(
            button: true,
            label: '$semanticLabel 직접 입력',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => _promptNumber(context),
              borderRadius: BorderRadius.circular(AppRadius.iconBox),
              child: SizedBox(
                width: 64,
                height: AppSize.touchMin,
                child: Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$value'),
                        if (unit.isNotEmpty)
                          TextSpan(
                            text: unit,
                            style: valueStyle.copyWith(
                              fontWeight: FontWeight.w400,
                              color: AppColors.mute,
                            ),
                          ),
                      ],
                    ),
                    style: valueStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          _StepButton(
            icon: AppIcons.add,
            label: '$semanticLabel 늘리기',
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _promptNumber(BuildContext context) async {
    final result = await showAppBottomSheet<int>(
      context: context,
      child: _NumberInputSheet(
        title: semanticLabel,
        initial: value,
        min: min,
        max: max,
        unit: unit,
      ),
    );
    if (result != null && result != value) onChanged(result);
  }
}

/// 숫자 직접 입력 시트. 입력칸 컨트롤러는 시트가 사라질 때 정리한다
/// (닫히는 애니메이션 중에도 입력칸이 남아 있으므로 먼저 정리하면 안 된다).
class _NumberInputSheet extends StatefulWidget {
  final String title;
  final int initial;
  final int min;
  final int max;
  final String unit;

  const _NumberInputSheet({
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
    required this.unit,
  });

  @override
  State<_NumberInputSheet> createState() => _NumberInputSheetState();
}

class _NumberInputSheetState extends State<_NumberInputSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.initial}')
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: '${widget.initial}'.length,
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_controller.text.trim());

  String? get _error {
    final n = _value;
    if (n == null) return '숫자를 입력해주세요.';
    if (n < widget.min || n > widget.max) {
      return '${widget.min}~${widget.max} 사이로 입력해주세요.';
    }
    return null;
  }

  void _submit() {
    if (_error == null) Navigator.of(context).pop(_value);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBottomSheetHeader(title: widget.title),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          style: AppTextStyles.title,
          decoration: InputDecoration(
            suffixText: widget.unit.isEmpty ? null : widget.unit,
            errorText: _controller.text.isEmpty ? null : error,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.base),
        AppButton(
          label: '확인',
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: error == null ? _submit : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: AppSize.touchMin,
        child: Material(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.iconBox),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.iconBox),
            child: Icon(
              icon,
              size: 18,
              color: onTap == null ? AppColors.canvasMid : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 날짜 고르기: 아래에서 올라오는 시트 + 휠(년·월·일) + 확인.
/// 앱의 모든 날짜 선택은 이 함수로 연다 (Material 달력 창은 쓰지 않는다).
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = '날짜 선택',
}) {
  DateTime clamp(DateTime d) => d.isBefore(firstDate)
      ? firstDate
      : d.isAfter(lastDate)
      ? lastDate
      : d;
  var picked = DateUtils.dateOnly(clamp(initialDate));
  return showAppBottomSheet<DateTime>(
    context: context,
    child: StatefulBuilder(
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBottomSheetHeader(title: title),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: AppTextStyles.bodyLg,
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: picked,
                minimumDate: DateUtils.dateOnly(firstDate),
                maximumDate: DateUtils.dateOnly(lastDate),
                dateOrder: DatePickerDateOrder.ymd,
                onDateTimeChanged: (d) => picked = DateUtils.dateOnly(d),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          AppButton(
            label: '확인',
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(picked),
          ),
        ],
      ),
    ),
  );
}

/// 하단 고정 버튼 바: (선택) 보조 버튼 + 주 버튼, 같은 너비. 화면 맨 아래에 둔다.
class AppBottomActionBar extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool loading;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;

  const AppBottomActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.loading = false,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      color: AppColors.canvas,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        bottom + AppSpacing.md,
      ),
      child: Row(
        children: [
          if (secondaryLabel != null) ...[
            Expanded(
              child: AppButton(
                label: secondaryLabel!,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.lg,
                fullWidth: true,
                icon: secondaryIcon == null ? null : Icon(secondaryIcon),
                onPressed: onSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: AppButton(
              label: primaryLabel,
              size: AppButtonSize.lg,
              fullWidth: true,
              isLoading: loading,
              onPressed: onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
