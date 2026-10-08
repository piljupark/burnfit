import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../models/notice.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';

/// 공지 화면 공용 위젯 (목록 한 줄, 본문, 홈 배너, 중요 공지 시트).

const IconData noticePinIcon = PhosphorIconsFill.pushPin;

String formatNoticeDate(DateTime? date) {
  if (date == null) return '';
  final sameYear = date.year == DateTime.now().year;
  return DateFormat(sameYear ? 'M월 d일' : 'yyyy년 M월 d일').format(date);
}

/// 보조 줄: "2026.10.08 · 회원 대상 · 수정됨"
String noticeMetaLine(Notice n, {bool showAudience = false}) {
  final parts = <String>[
    if (n.createdAt != null) formatNoticeDate(n.createdAt),
    if (showAudience) '${n.audience.label} 대상',
    if (n.important) '중요',
    if (n.isEdited) '수정됨',
  ];
  return parts.join(' · ');
}

/// 공지 한 줄: 제목(고정이면 앞에 작은 핀) + 보조 줄. 새 글은 오른쪽 점.
class NoticeTile extends StatelessWidget {
  final Notice notice;
  final bool isNew;
  final bool showAudience;
  final VoidCallback onTap;

  const NoticeTile({
    super.key,
    required this.notice,
    required this.onTap,
    this.isNew = false,
    this.showAudience = false,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = notice.important;
    final chevronColor = highlight ? AppColors.noticeText : AppColors.mute;

    return Semantics(
      button: true,
      label: [
        if (notice.pinned) '고정',
        if (isNew) '새 글',
        notice.title,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        borderRadius: highlight
            ? BorderRadius.circular(AppRadius.button)
            : null,
        child: Container(
          margin: highlight
              ? const EdgeInsets.symmetric(vertical: AppSpacing.xs)
              : null,
          decoration: highlight
              ? BoxDecoration(
                  color: AppColors.noticeBg,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                )
              : BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.hairline),
                  ),
                ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (notice.pinned) ...[
                          Icon(
                            noticePinIcon,
                            size: 14,
                            color: highlight
                                ? AppColors.noticeText
                                : AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            notice.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyLg,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      noticeMetaLine(notice, showAudience: showAudience),
                      style: AppTextStyles.bodySm.copyWith(
                        color: highlight ? AppColors.noticeText : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (isNew)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Container(
                    key: const ValueKey('notice-new-dot'),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.newDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              Icon(AppIcons.forward, size: 16, color: chevronColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// 섹션 머리말 (고정 / 전체).
class NoticeSectionLabel extends StatelessWidget {
  final String label;
  const NoticeSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.sm,
      ),
      child: Text(label, style: AppTextStyles.bodySm),
    );
  }
}

/// 고정·일반 섹션으로 나눈 목록 자식들.
List<Widget> buildNoticeListChildren({
  required List<Notice> items,
  required void Function(Notice) onTap,
  Set<String> newIds = const {},
  bool showAudience = false,
}) {
  final pinned = items.where((n) => n.pinned).toList();
  final rest = items.where((n) => !n.pinned).toList();
  Widget tile(Notice n) => NoticeTile(
    key: ValueKey(n.id),
    notice: n,
    isNew: newIds.contains(n.id),
    showAudience: showAudience,
    onTap: () => onTap(n),
  );
  return [
    if (pinned.isNotEmpty) ...[
      const NoticeSectionLabel('고정된 공지'),
      ...pinned.map(tile),
    ],
    if (rest.isNotEmpty) ...[
      if (pinned.isNotEmpty) const NoticeSectionLabel('전체 공지'),
      ...rest.map(tile),
    ],
  ];
}

/// 공지 본문 (중요 라벨 · 제목 · 보조 줄 · 내용).
class NoticeArticle extends StatelessWidget {
  final Notice notice;
  final bool showAudience;
  final String centerName;
  const NoticeArticle({
    super.key,
    required this.notice,
    this.showAudience = false,
    this.centerName = '',
  });

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (centerName.isNotEmpty) centerName,
      if (notice.createdAt != null) formatNoticeDate(notice.createdAt),
      if (showAudience) '${notice.audience.label} 대상',
      if (notice.isEdited) '수정됨',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notice.important) ...[
          Text(
            '중요 공지',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.noticeText),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          notice.title,
          style: AppTextStyles.title.copyWith(fontSize: 24),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(meta, style: AppTextStyles.bodySm),
        const SizedBox(height: AppSpacing.lg),
        Divider(height: 1, color: AppColors.hairline),
        const SizedBox(height: AppSpacing.lg),
        SelectableText(
          notice.body,
          style: AppTextStyles.bodyMd.copyWith(height: 1.6),
        ),
      ],
    );
  }
}

/// 홈 헤더 아래 한 줄 배너 (최신 공지).
class NoticeBanner extends StatelessWidget {
  final Notice notice;
  final VoidCallback onTap;
  const NoticeBanner({super.key, required this.notice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 시안 MemA-Home·Tr-Home: 연한 주황 48 줄(반경 14) + 확성기 18 + '공지' 14 + 제목 15 + 화살표 16
    final radius = BorderRadius.circular(AppRadius.field);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        0,
      ),
      child: Semantics(
        button: true,
        label: '공지, ${notice.title}',
        excludeSemantics: true,
        child: Material(
          color: AppColors.noticeBg,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(
                      AppIcons.megaphone,
                      size: 18,
                      color: AppColors.noticeText,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '공지',
                      style: AppTextStyles.buttonLabel.copyWith(
                        color: AppColors.noticeText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        notice.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // 바탕(noticeBg)이 두 테마 공통이라 글자도 테마와 관계없이 검정
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppPalette.light.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      AppIcons.chevronRightBold,
                      size: 16,
                      color: AppColors.noticeText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum NoticeSheetAction { confirm, detail, never }

/// 중요 공지 시트: 확인 / 자세히 보기 / 다시 보지 않기.
Future<NoticeSheetAction?> showImportantNoticeSheet(
  BuildContext context,
  Notice notice, {
  String centerName = '',
}) {
  return showAppBottomSheet<NoticeSheetAction>(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.noticeBg,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Icon(AppIcons.megaphone, size: 34, color: AppColors.noticeText),
        ),
        const SizedBox(height: AppSpacing.base),
        Text(
          centerName.isEmpty ? '중요 공지' : '$centerName 공지',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.noticeText),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(notice.title, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        Text(
          notice.body,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
        ),
        const SizedBox(height: AppSpacing.xl),
        Builder(
          builder: (ctx) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '자세히 보기',
                      fullWidth: true,
                      size: AppButtonSize.lg,
                      variant: AppButtonVariant.secondary,
                      onPressed: () =>
                          Navigator.of(ctx).pop(NoticeSheetAction.detail),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: '확인',
                      fullWidth: true,
                      size: AppButtonSize.lg,
                      variant: AppButtonVariant.dark,
                      onPressed: () =>
                          Navigator.of(ctx).pop(NoticeSheetAction.confirm),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(NoticeSheetAction.never),
                  child: Text(
                    '다시 보지 않기',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.mute,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.mute,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
