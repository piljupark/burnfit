import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

/// 입력창: canvasSoft 면 + hairline, 반경 8, 높이 48. 포커스는 흰 테두리, 오류는 danger.
///
/// 라벨은 입력창 위에 둔다. 라벨 글자는 13 body.
/// [fillColor]·[showEnabledBorder]·[labelAbove]는 기존 호출부 호환용이다
/// (라벨은 항상 위, 테두리는 항상 hairline).
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool readOnly;
  final Widget? suffix;
  final Widget? prefix;
  final int maxLines;
  final int? maxLength;
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

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.readOnly = false,
    this.suffix,
    this.prefix,
    this.maxLines = 1,
    this.maxLength,
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

    final field = TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: keyboardType,
      obscureText: widget.obscureText && _obscure,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      style: AppTextStyles.bodyMd,
      cursorColor: AppColors.ink,
      decoration: InputDecoration(
        hintText: widget.hint,
        counterText: '',
        prefixIcon: widget.prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.base,
                  right: AppSpacing.sm,
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
        suffixIcon: widget.obscureText
            ? IconButton(
                tooltip: _obscure ? '비밀번호 보기' : '비밀번호 숨기기',
                icon: Icon(
                  _obscure ? AppIcons.eye : AppIcons.eyeSlash,
                  size: AppSize.icon,
                  color: AppColors.body,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : widget.suffix,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: multiline ? AppSpacing.md : 13,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.body),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        field,
        if (widget.helper != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(widget.helper!, style: AppTextStyles.bodySm),
        ],
      ],
    );
  }
}
