import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/app_feedback.dart';
import '../core/app_text_styles.dart';
import '../models/feedback.dart' as fb;
import '../services/cardio_service.dart';
import '../services/firestore_service.dart';
import '../services/meal_service.dart';
import '../services/workout_service.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'app_text_field.dart';

class FeedbackSheet extends StatefulWidget {
  final String centerId;
  final String trainerId;
  final String trainerName;
  final String memberId;
  final String memberName;
  final fb.FeedbackTargetType targetType;
  final String? targetId;
  final String? targetDate;
  final fb.Feedback? existing;

  const FeedbackSheet({
    super.key,
    required this.centerId,
    required this.trainerId,
    required this.trainerName,
    required this.memberId,
    required this.memberName,
    required this.targetType,
    this.targetId,
    this.targetDate,
    this.existing,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String centerId,
    required String trainerId,
    required String trainerName,
    required String memberId,
    required String memberName,
    required fb.FeedbackTargetType targetType,
    String? targetId,
    String? targetDate,
    fb.Feedback? existing,
  }) {
    return showAppBottomSheet<bool>(
      context: context,
      memberStyle: true,
      child: FeedbackSheet(
        centerId: centerId,
        trainerId: trainerId,
        trainerName: trainerName,
        memberId: memberId,
        memberName: memberName,
        targetType: targetType,
        targetId: targetId,
        targetDate: targetDate,
        existing: existing,
      ),
    );
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  List<_FeedbackTemplate> get _templates {
    switch (widget.targetType) {
      case fb.FeedbackTargetType.meal:
        return const [
          _FeedbackTemplate(
            '균형 좋아요',
            '전체적인 식단 균형이 좋습니다. 단백질 섭취를 지금처럼 유지해 주세요.',
          ),
          _FeedbackTemplate(
            '단백질 보강',
            '단백질이 조금 부족해 보입니다. 다음 식사에는 닭가슴살, 달걀, 두부 중 하나를 추가해 주세요.',
          ),
          _FeedbackTemplate(
            '간식 조절',
            '간식 비중이 높습니다. 오늘은 당류가 낮은 간식으로 바꾸고 물 섭취를 늘려 주세요.',
          ),
        ];
      case fb.FeedbackTargetType.workout:
        return const [
          _FeedbackTemplate(
            '자세 체크',
            '운동 기록 좋습니다. 다음 세트에서는 속도를 조금 낮추고 자세 안정성에 집중해 주세요.',
          ),
          _FeedbackTemplate(
            '강도 유지',
            '현재 강도가 적절합니다. 같은 중량과 반복 수를 한 번 더 안정적으로 가져가 주세요.',
          ),
          _FeedbackTemplate(
            '점진 증가',
            '수행이 안정적입니다. 다음 운동에서는 마지막 세트만 중량 또는 반복 수를 소폭 올려 보세요.',
          ),
        ];
      case fb.FeedbackTargetType.cardio:
        return const [
          _FeedbackTemplate(
            '페이스 유지',
            '유산소 페이스가 좋습니다. 같은 강도로 시간을 꾸준히 채우는 데 집중해 주세요.',
          ),
          _FeedbackTemplate(
            '강도 조절',
            '강도가 다소 높아 보입니다. 숨이 너무 차면 속도를 낮추고 지속 시간을 우선해 주세요.',
          ),
          _FeedbackTemplate(
            '마무리 권장',
            '운동 후 가벼운 유산소 10분을 추가하면 회복과 컨디션 관리에 도움이 됩니다.',
          ),
        ];
      case fb.FeedbackTargetType.general:
        return const [
          _FeedbackTemplate(
            '좋은 흐름',
            '이번 주 흐름이 좋습니다. 지금 루틴을 유지하면서 수면과 수분 섭취도 함께 챙겨 주세요.',
          ),
          _FeedbackTemplate(
            '컨디션 확인',
            '최근 컨디션 변화를 확인해 주세요. 피로감이 높으면 운동 강도를 한 단계 낮추겠습니다.',
          ),
          _FeedbackTemplate('상담 필요', '다음 수업 때 현재 목표와 진행 상황을 함께 점검해 보겠습니다.'),
        ];
    }
  }

  void _applyTemplate(String content) {
    final current = _controller.text.trim();
    final nextText = current.isEmpty ? content : '$current\n\n$content';
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _controller.text = widget.existing!.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      const uuid = Uuid();
      final id = widget.existing?.id ?? uuid.v4();
      final now = DateTime.now();

      final feedback = fb.Feedback(
        id: id,
        centerId: widget.centerId,
        trainerId: widget.trainerId,
        trainerName: widget.trainerName,
        memberId: widget.memberId,
        memberName: widget.memberName,
        targetType: widget.targetType,
        targetId: widget.targetId,
        targetDate: widget.targetDate,
        content: _controller.text.trim(),
        readAt: widget.existing?.readAt,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );

      await FirestoreService.createFeedback(feedback);

      if (widget.targetId != null && widget.existing == null) {
        switch (widget.targetType) {
          case fb.FeedbackTargetType.meal:
            await MealService.linkFeedback(widget.targetId!, id);
          case fb.FeedbackTargetType.workout:
            await WorkoutService.linkFeedback(widget.targetId!, id);
          case fb.FeedbackTargetType.cardio:
            await CardioService.linkFeedback(widget.targetId!, id);
          case fb.FeedbackTargetType.general:
            break;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.78;

    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBottomSheetHeader(
                title: widget.existing != null ? '피드백 수정' : '피드백 작성',
                subtitle: '${widget.memberName} · ${widget.targetType.label}',
              ),
              Text(
                '빠른 템플릿',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final template in _templates)
                    _TemplateChip(
                      label: template.label,
                      onTap: () => _applyTemplate(template.content),
                    ),
                ],
              ),
              const Gap(AppSpacing.md),
              AppTextField(
                label: '피드백 내용',
                hint: '내용을 입력하세요.',
                controller: _controller,
                keyboardType: TextInputType.multiline,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '내용을 입력해주세요.';
                  return null;
                },
              ),
              const Gap(AppSpacing.lg),
              AppButton(
                label: widget.existing != null ? '수정' : '작성',
                onPressed: _submit,
                isLoading: _isLoading,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackTemplate {
  final String label;
  final String content;

  const _FeedbackTemplate(this.label, this.content);
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TemplateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brand.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.brand,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
