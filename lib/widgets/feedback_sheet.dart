import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/app_colors.dart';
import '../core/app_icons.dart';
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
import 'app_calendar.dart';
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

  /// 대상 기록에 이미 피드백이 이어져 있다(hasFeedback). 그러면 연결값을 덮어쓰지 않는다
  /// — 담당이 바뀌어 이전 트레이너의 피드백이 있어도 함께 남는다.
  /// false면 저장할 때 잇는다 (앞서 문서만 만들고 연결이 실패한 기록도 이때 다시 잇는다).
  final bool targetLinked;

  /// 같은 기록에 다른(이전 담당) 트레이너가 남긴 피드백. 읽기 전용으로 위에 보여 준다.
  final List<fb.Feedback> others;

  /// 저장을 시작하면 그 작업을 알린다. 저장 중에 시트가 끌어내려 닫혀도
  /// [show]가 작업이 끝나기를 기다렸다가 부모에게 다시 불러오라고(true) 알리기 위함이다.
  final ValueChanged<Future<void>>? onSaveStarted;

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
    this.targetLinked = false,
    this.others = const [],
    this.onSaveStarted,
  });

  /// 기록 하나의 피드백을 불러와 내 것(가장 최근 하나)과 다른 트레이너 것으로 나눈다.
  /// [show]의 `existing`·`others`에 그대로 넘긴다.
  static Future<({fb.Feedback? mine, List<fb.Feedback> others})> loadForTarget({
    required String targetId,
    required String centerId,
    required String memberId,
    required String trainerId,
  }) async {
    final all = await FirestoreService.getFeedbacksByTarget(
      targetId,
      centerId: centerId,
      memberId: memberId,
    );
    final mine = all.where((f) => f.trainerId == trainerId).lastOrNull;
    return (
      mine: mine,
      others: all.where((f) => f.trainerId != trainerId).toList(),
    );
  }

  /// 저장했거나, 저장하던 중 시트가 닫혀 무언가 쓰였을 수 있으면 true.
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
    bool targetLinked = false,
    List<fb.Feedback> others = const [],
  }) async {
    Future<void>? lastSave;
    final result = await showAppBottomSheet<bool>(
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
        targetLinked: targetLinked,
        others: others,
        onSaveStarted: (save) => lastSave = save,
      ),
    );
    if (result == true) return true;
    final pending = lastSave;
    if (pending == null) return result;
    // 저장을 한 번이라도 시작했다면 (닫힘·실패와 관계없이) 문서가 생겼을 수 있으니 다시 불러오게 한다.
    try {
      await pending;
    } catch (_) {
      // 오류는 시트가 이미 알렸다.
    }
    return true;
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  /// 이 시트에서 이미 만든 피드백 id. 만든 뒤 연결이 실패해 다시 누르면 새로 만들지 않고
  /// 이 문서의 내용을 고치고 연결만 다시 한다 (중복 생성 방지).
  String? _createdId;

  /// [_createdId] 문서에 마지막으로 저장한 내용.
  String? _createdContent;

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
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final content = _controller.text.trim();
    setState(() => _isLoading = true);
    final save = _save(content);
    widget.onSaveStarted?.call(save);
    try {
      await save;
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

  Future<void> _save(String content) async {
    final existing = widget.existing;
    if (existing != null) {
      await FirestoreService.updateFeedbackContent(existing.id, content);
      if (!widget.targetLinked) await _linkTarget(existing.id);
      return;
    }

    // 앞선 시도에서 문서는 만들었고 연결만 실패했다 → 내용만 맞추고 연결을 다시 한다.
    final createdId = _createdId;
    if (createdId != null) {
      if (content != _createdContent) {
        await FirestoreService.updateFeedbackContent(createdId, content);
        _createdContent = content;
      }
      if (!widget.targetLinked) await _linkTarget(createdId);
      return;
    }

    final id = const Uuid().v4();
    final now = DateTime.now();
    await FirestoreService.createFeedback(
      fb.Feedback(
        id: id,
        centerId: widget.centerId,
        trainerId: widget.trainerId,
        trainerName: widget.trainerName,
        memberId: widget.memberId,
        memberName: widget.memberName,
        targetType: widget.targetType,
        targetId: widget.targetId,
        targetDate: widget.targetDate,
        content: content,
        createdAt: now,
        updatedAt: now,
      ),
    );
    _createdId = id;
    _createdContent = content;
    if (!widget.targetLinked) await _linkTarget(id);
  }

  /// 대상 기록(식단·운동·유산소)에 피드백 id를 잇는다. 같은 값을 다시 써도 안전하다.
  Future<void> _linkTarget(String feedbackId) async {
    final targetId = widget.targetId;
    if (targetId == null) return;
    switch (widget.targetType) {
      case fb.FeedbackTargetType.meal:
        await MealService.linkFeedback(targetId, feedbackId);
      case fb.FeedbackTargetType.workout:
        await WorkoutService.linkFeedback(targetId, feedbackId);
      case fb.FeedbackTargetType.cardio:
        await CardioService.linkFeedback(targetId, feedbackId);
      case fb.FeedbackTargetType.general:
        break;
    }
  }

  /// 대상 날짜 (10월 7일 (수)). 날짜가 없으면 null.
  String? get _dateMeta {
    final date = DateTime.tryParse(widget.targetDate ?? '');
    return date == null ? null : appDayLabel(date);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    // 저장 중에는 뒤로 가기·바깥 누르기로 닫지 않는다.
    // (끌어내리기는 시트 공용 설정상 막을 수 없어 [show]가 저장이 끝나기를 기다린다.)
    return PopScope(
      canPop: !_isLoading,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBottomSheetHeader(
              title: isEditing ? '피드백 수정' : '피드백 작성',
              gap: 6,
            ),
            // 대상 (시안 Tr-Feedback): 회원 · 종류 17/500 + 날짜 14 body, 아래 14 띄우고 hairline
            Container(
              padding: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.hairline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.memberName} · ${widget.targetType.label}',
                    style: AppTextStyles.section.natural,
                  ),
                  if (_dateMeta != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(_dateMeta!, style: AppTextStyles.bodySmall.natural),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            // 이전 담당 트레이너의 피드백 (인수인계): 읽기 전용, 길면 안에서 스크롤
            if (widget.others.isNotEmpty) ...[
              Text('이전 피드백', style: AppTextStyles.fieldLabel.natural),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, other) in widget.others.indexed) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.sm),
                        FeedbackQuote(feedback: other, showDate: true),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
            ],
            // 빠른 문구: 14 mute 라벨 → 8 → 36 pill (사이 8)
            // pill 위아래 터치 여백 4를 빼고 시안 간격(8 · 16)을 맞춘다.
            Text('자주 쓰는 문구', style: AppTextStyles.fieldLabel.natural),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final template in _templates)
                  _TemplateChip(
                    label: template.label,
                    onTap: () => _applyTemplate(template.content),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: '피드백',
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
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: isEditing ? '피드백 수정' : '피드백 남기기',
              onPressed: _submit,
              isLoading: _isLoading,
              fullWidth: true,
              size: AppButtonSize.lg,
            ),
          ],
        ),
      ),
    );
  }
}

/// 빠른 문구 pill (시안 Tr-Feedback): 36 높이 · 왼쪽 10 오른쪽 14 · canvasSoft,
/// 14 더하기(body) + 4 + 14 글자(ink). 누르면 문구를 입력창 끝에 붙인다.
class _TemplateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TemplateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label 문구 넣기',
      excludeSemantics: true,
      child: Padding(
        // 터치 영역 44를 위아래 4로 채운다
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Material(
          color: AppColors.canvasSoft,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            highlightColor: AppColors.canvasMid,
            splashFactory: NoSplash.splashFactory,
            child: Container(
              height: 36,
              padding: const EdgeInsets.only(left: 10, right: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.bold(AppIcons.add),
                    size: AppSize.iconSm,
                    color: AppColors.body,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(label, style: AppTextStyles.buttonLabel),
                ],
              ),
            ),
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

/// 트레이너 피드백 상자 (시안 MemB-MealLog): 회색 면, 반경 14, 안쪽 14/16, 테두리 없음.
/// 본문(15, 줄 1.5) → 위 6 '이름 트레이너 · 시각'(13 mute). [showDate]면 시각 대신 날짜.
/// 회원 식단 기록과 트레이너 피드백 시트('이전 피드백')가 함께 쓴다.
class FeedbackQuote extends StatelessWidget {
  final fb.Feedback feedback;
  final bool showDate;

  const FeedbackQuote({
    super.key,
    required this.feedback,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = feedback.trainerName.trim();
    final who = name.isEmpty ? '트레이너' : '$name 트레이너';
    final when = showDate
        ? appDayLabel(feedback.createdAt)
        : DateFormat('HH:mm').format(feedback.createdAt);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback.content,
            style: AppTextStyles.bodyMd.copyWith(height: 1.5),
          ),
          const SizedBox(height: 6),
          Text(
            '$who · $when',
            style: AppTextStyles.bodySm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
