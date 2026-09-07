import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';

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
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;
  bool _focused = false;
  late FocusNode _node;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _node = widget.focusNode ?? FocusNode();
    _node.addListener(() {
      if (mounted) setState(() => _focused = _node.hasFocus);
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveKeyboardType =
        widget.maxLines > 1 && widget.keyboardType == TextInputType.text
        ? TextInputType.multiline
        : widget.keyboardType;
    final radius = BorderRadius.circular(AppRadius.md);

    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: effectiveKeyboardType,
      obscureText: widget.obscureText ? _obscure : false,
      readOnly: widget.readOnly,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      focusNode: _node,
      autofocus: widget.autofocus,
      style: AppTextStyles.body.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w400,
      ),
      cursorColor: AppColors.brand,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        filled: true,
        fillColor: _focused ? AppColors.card : AppColors.bg,
        prefixIcon: widget.prefix != null
            ? Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: widget.prefix,
              )
            : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : widget.suffix,
        counterText: '',
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: widget.maxLines > 1 ? AppSpacing.base : AppSpacing.itemV,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: radius,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: radius,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.brand,
            width: 1.5,
          ),
          borderRadius: radius,
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.destructive,
            width: 1,
          ),
          borderRadius: radius,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.destructive,
            width: 1.5,
          ),
          borderRadius: radius,
        ),
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: _focused
              ? AppColors.brand
              : AppColors.textSecondary,
        ),
        hintStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textTertiary,
        ),
        errorStyle: AppTextStyles.captionSmall.copyWith(
          color: AppColors.destructive,
        ),
      ),
    );
  }
}
