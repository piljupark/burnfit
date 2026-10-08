import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import 'app_motion.dart';

/// 입력창 (시안 C2c·Com-*): canvasSoft 면, 반경 14, 높이 52, 글자 16, 평소 테두리 없음.
/// - 포커스: 안쪽 2px ink 테두리
/// - 오류: 연한 주황 면(noticeBg) + 1.5px noticeText 테두리, 아래 '!' 원 + 13/500 noticeText 문구(새 오류마다 한 번 흔들림)
/// - 라벨: 칸 위 14 mute, 칸과 6 띄움. [labelHint]는 라벨 뒤 '(선택)' 같은 흐린 글자(faint)
/// - [unit]: 칸 안 오른쪽 단위 글자(16 mute, 예: 'cm')
/// - [showCounter]: [maxLength]가 있을 때 칸 아래 오른쪽 '8/8' (12 faint)
/// - [showVisibilityToggle]: 비밀번호 보기 버튼 (시안에는 없어 기본 끔)
/// [fillColor]·[showEnabledBorder]·[labelAbove]는 기존 호출부 호환용이다.
class AppTextField extends StatefulWidget {
  final String label;
  final String? labelHint;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool showVisibilityToggle;
  final bool readOnly;
  final bool enabled;
  final Widget? suffix;
  final Widget? prefix;
  final String? unit;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final bool showCounter;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? fillColor;
  final bool showEnabledBorder;
  final bool labelAbove;
  final String? helper;
  final VoidCallback? onTap;

  /// 입력 글자를 500(Medium)으로 (시안의 숫자 값 칸)
  final bool strongValue;

  const AppTextField({
    super.key,
    required this.label,
    this.labelHint,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.showVisibilityToggle = false,
    this.readOnly = false,
    this.enabled = true,
    this.suffix,
    this.prefix,
    this.unit,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.showCounter = false,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
    this.autofocus = false,
    this.fillColor,
    this.showEnabledBorder = true,
    this.labelAbove = true,
    this.helper,
    this.onTap,
    this.strongValue = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final multiline = widget.maxLines > 1 && !widget.obscureText;
    final keyboardType = multiline && widget.keyboardType == TextInputType.text
        ? TextInputType.multiline
        : widget.keyboardType;
    final valueStyle = multiline
        ? AppTextStyles.input.copyWith(height: 1.5)
        : AppTextStyles.input;

    Widget? suffix = widget.suffix;
    if (widget.obscureText && widget.showVisibilityToggle) {
      suffix = IconButton(
        tooltip: _obscure ? '비밀번호 보기' : '비밀번호 숨기기',
        icon: Icon(
          _obscure ? AppIcons.eye : AppIcons.eyeSlash,
          size: AppSize.icon,
          color: AppColors.mute,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      );
    } else if (widget.unit != null && suffix == null) {
      // 단위: 값이 있으면 mute, 비어 있으면 faint (시안 Com-Onboarding-Body)
      Widget unitText(bool empty) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.base),
        child: Text(
          widget.unit!,
          style: AppTextStyles.input.copyWith(
            color: empty ? AppColors.faint : AppColors.mute,
          ),
        ),
      );
      final c = widget.controller;
      suffix = c == null
          ? unitText(true)
          : ValueListenableBuilder<TextEditingValue>(
              valueListenable: c,
              builder: (context, value, _) => unitText(value.text.isEmpty),
            );
    }

    final field = TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: keyboardType,
      obscureText: widget.obscureText && _obscure,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      onTap: widget.onTap,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.obscureText ? null : widget.minLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      style: widget.strongValue ? valueStyle.medium : valueStyle,
      cursorColor: AppColors.ink,
      errorBuilder: (context, errorText) => AppFieldError(errorText),
      decoration: InputDecoration(
        hintText: widget.hint,
        counterText: '',
        prefixIcon: widget.prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.base,
                  right: 10,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: AppColors.mute,
                    size: AppSize.icon,
                  ),
                  child: widget.prefix!,
                ),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        suffixIconConstraints: widget.unit != null && widget.suffix == null
            ? const BoxConstraints(minWidth: 0, minHeight: 0)
            : null,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: multiline ? 14 : 15,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: widget.label),
                if (widget.labelHint != null)
                  TextSpan(
                    text: ' ${widget.labelHint}',
                    style: TextStyle(color: AppColors.faint),
                  ),
              ],
            ),
            style: AppTextStyles.fieldLabel,
          ),
          const SizedBox(height: 6),
        ],
        field,
        if (widget.showCounter && widget.maxLength != null)
          _Counter(
            controller: widget.controller,
            maxLength: widget.maxLength!,
          ),
        if (widget.helper != null) ...[
          const SizedBox(height: 6),
          Text(widget.helper!, style: AppTextStyles.bodySm),
        ],
      ],
    );
  }
}

/// 입력창 아래 오류 문구: '!' 원 16 + 13/500 noticeText, 새 오류마다 한 번 흔들림 (시안 `shake`).
class AppFieldError extends StatelessWidget {
  final String message;

  const AppFieldError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: AppShake(
        trigger: message,
        child: Row(
          children: [
            Icon(AppIcons.warning, size: 16, color: AppColors.noticeText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySm.medium.copyWith(
                  color: AppColors.noticeText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// '8/8' 글자 수 (칸 아래 오른쪽, 12 faint).
class _Counter extends StatelessWidget {
  final TextEditingController? controller;
  final int maxLength;

  const _Counter({required this.controller, required this.maxLength});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget text(int n) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$n/$maxLength',
          style: AppTextStyles.captionSmall.copyWith(color: AppColors.faint),
        ),
      ),
    );
    if (c == null) return text(0);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: c,
      builder: (context, value, _) => text(value.text.characters.length),
    );
  }
}
