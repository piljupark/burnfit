import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_logger.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/constants.dart';
import '../../models/meal.dart';
import '../../services/meal_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_text_field.dart';

/// 식단 기록 입력 화면 (하위 화면으로 push).
/// 끼니 칩 → 사진 3열 격자 → 메모·칼로리 → 아래 고정 주 행동 하나.
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

  void _removeImage(int i) => setState(() {
    _images.removeAt(i);
    _imageBytes.removeAt(i);
  });

  String get _dateLabel {
    final date = DateTime.tryParse(widget.selectedDate);
    return date == null ? widget.selectedDate : DateFormat('MM.dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: AppScreenHeader(
                title: '식단 기록',
                onBack: () => Navigator.of(context).pop(false),
                trailing: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(_dateLabel, style: AppTextStyles.eyebrow),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xl,
                  AppSpacing.screenH,
                  AppSpacing.xl,
                ),
                children: [
                  Text('끼니', style: AppTextStyles.bodySm.copyWith(color: AppColors.body)),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final type in MealType.values)
                        AppChip(
                          label: type.label,
                          selected: _mealType == type,
                          onTap: () => setState(() => _mealType = type),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Text('사진', style: AppTextStyles.bodySm.copyWith(color: AppColors.body)),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${_images.length} / ${AppConstants.imageMaxCount}',
                        style: AppTextStyles.counter,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PhotoGrid(
                    images: _images,
                    imageBytes: _imageBytes,
                    canAdd: _images.length < AppConstants.imageMaxCount,
                    onAdd: _pickImages,
                    onRemove: _removeImage,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    label: '메모',
                    hint: '먹은 음식을 기록해보세요',
                    controller: _descController,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  AppTextField(
                    label: '칼로리',
                    hint: '선택 입력',
                    controller: _caloriesController,
                    keyboardType: TextInputType.number,
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.base),
                      child: Center(
                        widthFactor: 1,
                        child: Text('KCAL', style: AppTextStyles.counter),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.md,
              ),
              child: AppButton(
                label: '기록 저장',
                size: AppButtonSize.lg,
                fullWidth: true,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 사진 3열 격자 (간격 2, 반경 0). 마지막 칸은 추가 칸.
class _PhotoGrid extends StatelessWidget {
  final List<XFile> images;
  final List<Uint8List> imageBytes;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _PhotoGrid({
    required this.images,
    required this.imageBytes,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final count = images.length + (canAdd ? 1 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.xxs,
        crossAxisSpacing: AppSpacing.xxs,
      ),
      itemBuilder: (_, i) {
        if (i == images.length) {
          return Semantics(
            button: true,
            label: '식단 사진 추가',
            excludeSemantics: true,
            child: Material(
              color: AppColors.canvasSoft,
              shape: const RoundedRectangleBorder(
                side: BorderSide(color: AppColors.hairline),
              ),
              child: InkWell(
                onTap: onAdd,
                highlightColor: AppColors.canvasMid,
                splashFactory: NoSplash.splashFactory,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(AppIcons.camera, size: AppSize.icon, color: AppColors.body),
                    const SizedBox(height: AppSpacing.xs),
                    Text('사진 추가', style: AppTextStyles.bodySm),
                  ],
                ),
              ),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              image: true,
              label: '식단 사진 ${i + 1}',
              child: kIsWeb
                  ? Image.memory(imageBytes[i], fit: BoxFit.cover)
                  : Image.file(File(images[i].path), fit: BoxFit.cover),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 사진 위 아이콘 대비용 scrim 원
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(color: AppColors.scrim, shape: BoxShape.circle),
                  ),
                  AppIconButton(
                    icon: AppIcons.close,
                    label: '사진 ${i + 1} 삭제',
                    onPressed: () => onRemove(i),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
