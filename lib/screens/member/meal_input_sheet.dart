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
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_motion.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_text_field.dart';

/// 식단 기록 입력 화면 (하위 화면으로 push, 시안 MemB-MealInput).
/// 끼니 칩 → 사진 3열 격자(간격 6, 반경 14) → 메모·칼로리 → 아래 고정 주 행동 하나.
class MealInputSheet extends StatefulWidget {
  final String centerId;
  final String memberId;
  final String memberName;
  final String? trainerId;
  final String selectedDate;

  /// 영양 가이드에서 음식을 골라 열 때 미리 채울 값. 모두 사용자가 고칠 수 있다.
  final MealType? initialMealType;
  final String? initialDescription;
  final int? initialCalories;

  const MealInputSheet({
    super.key,
    required this.centerId,
    required this.memberId,
    required this.memberName,
    this.trainerId,
    required this.selectedDate,
    this.initialMealType,
    this.initialDescription,
    this.initialCalories,
  });

  @override
  State<MealInputSheet> createState() => _MealInputSheetState();
}

class _MealInputSheetState extends State<MealInputSheet> {
  late MealType _mealType = widget.initialMealType ?? MealType.lunch;
  late final _descController = TextEditingController(
    text: widget.initialDescription,
  );
  late final _caloriesController = TextEditingController(
    text: widget.initialCalories?.toString(),
  );
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
      AppFeedback.showWarning(
        context,
        '이미지는 최대 ${AppConstants.imageMaxCount}장까지 추가할 수 있습니다.',
      );
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
          AppFeedback.showWarning(
            context,
            '${AppConstants.imageMaxMegabytes}MB 이하의 이미지만 업로드 가능합니다.',
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
    final calories = _caloriesController.text.trim();
    // 식단은 사진이 꼭 있어야 한다 (규칙도 같은 것을 요구한다)
    if (_images.isEmpty) {
      AppFeedback.showWarning(context, '사진을 1장 이상 올려 주세요.');
      return;
    }
    if (calories.isNotEmpty && (int.tryParse(calories) ?? -1) < 0) {
      AppFeedback.showWarning(context, '칼로리는 0 이상의 숫자로 입력해주세요.');
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      // 아래 버튼 바가 안전 영역을 스스로 채운다 (시안 12 20 34)
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.centered(
              title: '식단 기록',
              onBack: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.lg,
                  AppSpacing.screenH,
                  AppSpacing.xl,
                ),
                children: [
                  Text('끼니', style: AppTextStyles.fieldLabel),
                  const SizedBox(height: AppSpacing.sm),
                  // 시안: 같은 폭 4칸 (높이 44, 반경 14, 간격 8)
                  Row(
                    children: [
                      for (final type in MealType.values) ...[
                        if (type != MealType.values.first)
                          const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppChip(
                            label: type.label,
                            selected: _mealType == type,
                            cell: true,
                            onTap: () => setState(() => _mealType = type),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: '사진'),
                            TextSpan(
                              text: ' (필수)',
                              style: TextStyle(color: AppColors.faint),
                            ),
                          ],
                        ),
                        style: AppTextStyles.fieldLabel,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${_images.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink,
                              ),
                            ),
                            TextSpan(text: ' / ${AppConstants.imageMaxCount}'),
                          ],
                        ),
                        style: AppTextStyles.fieldLabel,
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
                  if (_images.isEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '사진을 1장 이상 올려야 저장할 수 있어요',
                      style: AppTextStyles.bodySm,
                    ),
                  ],
                  const SizedBox(height: 28),
                  AppTextField(
                    label: '메모',
                    hint: '먹은 음식을 기록해보세요',
                    controller: _descController,
                    minLines: 4,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  AppTextField(
                    label: '칼로리',
                    hint: '선택 입력',
                    controller: _caloriesController,
                    keyboardType: TextInputType.number,
                    unit: 'kcal',
                    strongValue: true,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
            AppBottomActionBar(
              primaryLabel: '기록 저장',
              loading: _isSaving,
              // 사진이 없으면 누를 수 없다 (위에 안내 줄)
              onPrimary: _isSaving || _images.isEmpty ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// 사진 3열 격자 (간격 6, 반경 14). 마지막 칸은 점선 추가 칸.
/// 새로 넣은 사진 칸은 커지며 나타난다 (시안 `pop`).
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
      padding: EdgeInsets.zero,
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (_, i) {
        if (i == images.length) {
          final radius = BorderRadius.circular(AppRadius.field);
          return Semantics(
            button: true,
            label: '식단 사진 추가',
            excludeSemantics: true,
            child: CustomPaint(
              foregroundPainter: _DashedBorderPainter(
                color: AppColors.outline,
                radius: AppRadius.field,
              ),
              child: Material(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: radius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onAdd,
                  highlightColor: AppColors.canvasSoft,
                  splashFactory: NoSplash.splashFactory,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.camera, size: 24, color: AppColors.body),
                      const SizedBox(height: 6),
                      Text(
                        '사진 추가',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return _PopIn(
          key: ValueKey(images[i].path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.field),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  image: true,
                  label: '식단 사진 ${i + 1}',
                  child: ColoredBox(
                    color: AppColors.track,
                    child: kIsWeb
                        ? Image.memory(imageBytes[i], fit: BoxFit.cover)
                        : Image.file(File(images[i].path), fit: BoxFit.cover),
                  ),
                ),
                // 삭제: 누름 영역 44, 원 26 (rgba(25,25,25,.6)) + 흰 X 14
                Positioned(
                  top: 0,
                  right: 0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0x99191919),
                          shape: BoxShape.circle,
                        ),
                      ),
                      AppIconButton(
                        icon: AppIcons.closeBold,
                        label: '사진 ${i + 1} 삭제',
                        iconSize: 14,
                        color: Colors.white,
                        onPressed: () => onRemove(i),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 사진 칸이 처음 놓일 때 커지며 나타난다 (시안 `pop`: .6 → 1.05 → 1, .45s,
/// cubic-bezier(.3,1.3,.5,1)). '동작 줄이기'면 바로 그린다.
class _PopIn extends StatelessWidget {
  final Widget child;

  const _PopIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: AppMotion.knob,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
    );
  }
}

/// 점선 둥근 테두리 (시안 사진 추가 칸: 1.5 dashed #D4D4D8, 반경 14).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;
    const dash = 4.5;
    const gap = 3.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
