import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../models/meal.dart';
import '../../services/meal_service.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_text_field.dart';

class MealInputSheet extends StatefulWidget {
  final String centerId;
  final String memberId;
  final String memberName;
  final String? trainerId;
  final String selectedDate;

  const MealInputSheet({
    super.key,
    required this.centerId,
    required this.memberId,
    required this.memberName,
    this.trainerId,
    required this.selectedDate,
  });

  @override
  State<MealInputSheet> createState() => _MealInputSheetState();
}

class _MealInputSheetState extends State<MealInputSheet> {
  MealType _mealType = MealType.lunch;
  final _descController = TextEditingController();
  final _caloriesController = TextEditingController();
  final List<XFile> _images = [];
  final List<Uint8List> _imageBytes = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _descController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_images.length >= AppConstants.imageMaxCount) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미지는 최대 5장까지 추가할 수 있습니다.')));
      return;
    }
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(
        imageQuality: AppConstants.imageQuality,
        limit: AppConstants.imageMaxCount - _images.length,
      );
      for (final file in files) {
        final bytes = await file.length();
        if (bytes > AppConstants.imageMaxBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppConstants.imageMaxMegabytes}MB 이하의 이미지만 업로드 가능합니다.',
              ),
            ),
          );
          continue;
        }
        final previewBytes = kIsWeb ? await file.readAsBytes() : Uint8List(0);
        if (!mounted) return;
        setState(() {
          _images.add(file);
          _imageBytes.add(previewBytes);
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    var urls = <String>[];
    try {
      final now = DateFormat('HH:mm').format(DateTime.now());
      final description = _descController.text.trim();
      if (_images.isNotEmpty) {
        urls = await MealService.uploadImages(
          files: _images,
          centerId: widget.centerId,
          memberId: widget.memberId,
        );
      }
      await MealService.saveMeal(
        centerId: widget.centerId,
        memberId: widget.memberId,
        memberName: widget.memberName,
        trainerId: widget.trainerId,
        mealType: _mealType,
        mealDate: widget.selectedDate,
        mealTime: now,
        imageUrls: urls,
        description: description.isEmpty ? null : description,
        calories: int.tryParse(_caloriesController.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (urls.isNotEmpty) {
        await MealService.deleteImages(urls);
      }
      AppLogger.debug('[식단 저장 오류] $e');
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppScreenHeader(
                title: '식단 기록',
                onBack: () => Navigator.of(context).pop(false),
              ),
              const Gap(20),
              Row(
                children: MealType.values.map((type) {
                  final selected = _mealType == type;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: type != MealType.values.last ? 8 : 0,
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() => _mealType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.diet
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            boxShadow: selected
                                ? null
                                : const [
                                    BoxShadow(
                                      color: Color(0x0F000000),
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            type.label,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: selected
                                  ? AppColors.textOnAccent
                                  : AppColors.textNeutral,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Gap(20),
              GestureDetector(
                onTap: _pickImages,
                child: _images.isEmpty
                    ? Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 24,
                              color: AppColors.textTertiary,
                            ),
                            const Gap(AppSpacing.xxs),
                            Text(
                              '식단 사진 추가',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length < AppConstants.imageMaxCount
                              ? _images.length + 1
                              : _images.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: AppSpacing.xs),
                          itemBuilder: (_, i) {
                            if (i == _images.length) {
                              return GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  width: 120,
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xs,
                                    ),
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            }
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                  child: kIsWeb
                                      ? Image.memory(
                                          _imageBytes[i],
                                          width: 160,
                                          height: 160,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(_images[i].path),
                                          width: 160,
                                          height: 160,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _images.removeAt(i);
                                      _imageBytes.removeAt(i);
                                    }),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: AppColors.textOnAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
              const Gap(20),
              Text(
                '메모',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Gap(12),
              _MealMemoField(controller: _descController),
              const Gap(AppSpacing.sm),
              AppTextField(
                label: '칼로리',
                hint: '선택 입력',
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                suffix: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Center(
                    widthFactor: 1,
                    child: Text('kcal', style: AppTextStyles.caption),
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),
              const Gap(24),
              GestureDetector(
                onTap: _isSaving ? null : _save,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _isSaving
                        ? AppColors.diet.withValues(alpha: 0.45)
                        : AppColors.diet,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  alignment: Alignment.center,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnAccent,
                          ),
                        )
                      : Text(
                          '기록 저장',
                          style: AppTextStyles.button.copyWith(
                            color: AppColors.textOnAccent,
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

class _MealMemoField extends StatelessWidget {
  final TextEditingController controller;

  const _MealMemoField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      maxLines: 4,
      style: AppTextStyles.body.copyWith(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      cursorColor: AppColors.brand,
      decoration: InputDecoration(
        labelText: '메모',
        hintText: '먹은 음식을 기록해보세요',
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.border,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.border,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: AppColors.brand,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
