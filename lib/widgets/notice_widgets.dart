import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../models/notice.dart';
import 'app_action_row.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'app_motion.dart';

/// 공지 화면 공용 위젯 (목록 한 줄, 본문, 홈 배너, 중요 공지 시트).

/// 고정 핀 (시안: 외곽선 핀, 선 2 → Bold)
const IconData noticePinIcon = PhosphorIconsBold.pushPin;

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

/// 공지 한 줄.
/// - 기본(시안 Nt-List 일반 줄 · Nt-Admin-List): 좌우 20 안쪽, 최소 72, 아래 선. 고정이면 왼쪽 핀 18 주황.
///   제목 16(고정이면 500) + 새 글이면 바로 뒤 점 6 → (위 3) 보조 줄 13 mute → 화살표 16 chevron.
///   [dimRead]면 읽은 글 제목을 body 색으로 (회원 목록).
/// - [card](시안 Nt-List 중요 공지): 연한 주황 카드(안쪽 16, 반경 18), 왼쪽 핀 20 · 제목 16/500 · 맥박 점 ·
///   보조 줄 13 noticeText · 화살표 16 noticeText.
class NoticeTile extends StatelessWidget {
  final Notice notice;
  final bool isNew;
  final bool showAudience;
  final bool card;
  final bool dimRead;
  final VoidCallback onTap;

  const NoticeTile({
    super.key,
    required this.notice,
    required this.onTap,
    this.isNew = false,
    this.showAudience = false,
    this.card = false,
    this.dimRead = false,
  });

  Widget _dot({bool pulse = false}) {
    final dot = Container(
      key: const ValueKey('notice-new-dot'),
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.newDot,
        shape: BoxShape.circle,
      ),
    );
    return pulse ? AppPulse(child: dot) : dot;
  }

  @override
  Widget build(BuildContext context) {
    final semantics = [
      if (notice.pinned) '고정',
      if (notice.important) '중요',
      if (isNew) '새 글',
      notice.title,
    ].join(', ');
    return card ? _card(semantics) : _row(semantics);
  }

  Widget _card(String semantics) {
    final radius = BorderRadius.circular(AppRadius.button);
    // 바탕(noticeBg)이 두 테마 공통이라 제목은 테마와 관계없이 검정
    final ink = AppPalette.light.ink;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Material(
          color: AppColors.noticeBg,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Row(
                children: [
                  Icon(
                    notice.pinned ? noticePinIcon : AppIcons.megaphone,
                    size: 20,
                    color: AppColors.noticeText,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                notice.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.listTitle.copyWith(
                                  color: ink,
                                ),
                              ),
                            ),
                            if (isNew) ...[
                              const SizedBox(width: 6),
                              _dot(pulse: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          noticeMetaLine(notice, showAudience: showAudience),
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.noticeText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
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
    );
  }

  Widget _row(String semantics) {
    final titleStyle = notice.pinned
        ? AppTextStyles.listTitle
        : AppTextStyles.input.copyWith(
            color: dimRead && !isNew ? AppColors.body : AppColors.ink,
          );
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                if (notice.pinned) ...[
                  Icon(noticePinIcon, size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              notice.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                          ),
                          if (isNew) ...[const SizedBox(width: 6), _dot()],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        noticeMetaLine(notice, showAudience: showAudience),
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(
                  AppIcons.chevronRightBold,
                  size: 16,
                  color: AppColors.chevron,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 섹션 머리말 (상단 고정 / 전체 공지, 시안 Nt-Admin-List): 15 mute, 여백 20 20 4.
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
        AppSpacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(label, style: AppTextStyles.eyebrow),
      ),
    );
  }
}

/// 목록 자식들.
/// - 기본(관리자, 시안 Nt-Admin-List): '상단 고정' / (띠) '전체 공지' 섹션으로 나눈다.
/// - [memberStyle](회원·트레이너, 시안 Nt-List): 섹션 이름 없이 중요 공지는 위쪽 주황 카드(위 16, 사이 8),
///   나머지는 아래 줄(위 8). 줄은 왼쪽에서 차례로 밀려 들어온다(.4s, 0.05초 간격).
List<Widget> buildNoticeListChildren({
  required List<Notice> items,
  required void Function(Notice) onTap,
  Set<String> newIds = const {},
  bool showAudience = false,
  bool memberStyle = false,
}) {
  final pinned = items.where((n) => n.pinned).toList();
  final rest = items.where((n) => !n.pinned).toList();
  Widget tile(Notice n, {bool card = false}) => NoticeTile(
    key: ValueKey(n.id),
    notice: n,
    isNew: newIds.contains(n.id),
    showAudience: showAudience,
    card: card,
    dimRead: memberStyle,
    onTap: () => onTap(n),
  );

  if (memberStyle) {
    final ordered = [...pinned, ...rest];
    final cards = ordered.where((n) => n.important).toList();
    final rows = ordered.where((n) => !n.important).toList();
    var order = 0;
    Widget slide(Widget child) {
      final i = order++;
      return AppEntrance.slide(
        delay: Duration(milliseconds: 50 * (i < 8 ? i : 8)),
        child: child,
      );
    }

    return [
      if (cards.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.base),
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          slide(tile(cards[i], card: true)),
        ],
      ],
      if (rows.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.sm),
        for (final n in rows) slide(tile(n)),
      ],
    ];
  }

  return [
    if (pinned.isNotEmpty) ...[
      const NoticeSectionLabel('상단 고정'),
      ...pinned.map(tile),
    ],
    if (rest.isNotEmpty) ...[
      if (pinned.isNotEmpty) ...[
        const AppSectionBand(top: AppSpacing.md),
        const NoticeSectionLabel('전체 공지'),
      ],
      ...rest.map(tile),
    ],
  ];
}

/// 공지 본문 (시안 Nt-Detail): '중요 공지' 14 noticeText → (위 6) 제목 24/500 · 줄 높이 1.35 →
/// (위 8) 보조 줄 14 mute → (위 20) 선 → (위 20) 내용 16 · 줄 높이 1.7.
/// 머리 묶음과 내용이 아래 10에서 떠오른다 (시안 `up` .45s, 내용은 .08초 늦게).
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
    const duration = Duration(milliseconds: 450);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppEntrance(
          duration: duration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notice.important) ...[
                Text(
                  '중요 공지',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.noticeText,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                notice.title,
                style: AppTextStyles.title.copyWith(
                  fontSize: 24,
                  height: 1.35,
                  letterSpacing: 24 * -0.019,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                meta,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.mute),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Divider(height: 1, thickness: 1, color: AppColors.hairline),
        const SizedBox(height: AppSpacing.lg),
        AppEntrance(
          duration: duration,
          delay: const Duration(milliseconds: 80),
          child: SelectableText(
            notice.body,
            style: AppTextStyles.input.copyWith(height: 1.7),
          ),
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
                    Icon(
                      AppIcons.bold(AppIcons.megaphone),
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

/// 중요 공지 시트 (시안 Nt-ImportantSheet): 확성기 상자 64(반경 20, 흔들림·물결) →
/// (위 16) '센터 공지' 14 noticeText → (위 6) 제목 22/500 · 1.35 → (위 12) 내용 15 body · 1.6 →
/// (위 24) 자세히 보기 / 확인 (56, 16/500) → (위 10) 다시 보지 않기 14 mute 밑줄.
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
        // 손잡이 아래 14 + 6 = 시안 20
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.noticeBg,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const _AnimatedMegaphone(),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Text(
          centerName.isEmpty ? '중요 공지' : '$centerName 공지',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.noticeText),
        ),
        const SizedBox(height: 6),
        Text(
          notice.title,
          style: AppTextStyles.sheetTitle.copyWith(height: 1.35),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          notice.body,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.body,
            height: 1.6,
          ),
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
                      labelSize: 16,
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
                      labelSize: 16,
                      variant: AppButtonVariant.dark,
                      onPressed: () =>
                          Navigator.of(ctx).pop(NoticeSheetAction.confirm),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Semantics(
                  button: true,
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(NoticeSheetAction.never),
                    splashFactory: NoSplash.splashFactory,
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppSize.touchMin,
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Text(
                        '다시 보지 않기',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.mute,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.mute,
                        ),
                      ),
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

/// 시안 확성기 그림 (34, 선 1.6 noticeText):
/// 몸통은 ±8° 흔들림(`wiggle` 1.6s ease-in-out, 기준점 30% 60%),
/// 소리 물결은 0.6 → 1.2배로 퍼지며 나타났다 사라짐(`wave` 1.6s ease-out, 기준점 14·12).
class _AnimatedMegaphone extends StatefulWidget {
  const _AnimatedMegaphone();

  @override
  State<_AnimatedMegaphone> createState() => _AnimatedMegaphoneState();
}

class _AnimatedMegaphoneState extends State<_AnimatedMegaphone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = _controller.value;
          final reduced = AppMotion.reduced(context);
          // -8° → +8° → -8°
          final tri = v < 0.5 ? v * 2 : (1 - v) * 2;
          final angle = reduced
              ? 0.0
              : (-8 + 16 * Curves.easeInOut.transform(tri)) * math.pi / 180;
          final wave = reduced ? 0.5 : Curves.easeOut.transform(v);
          return CustomPaint(
            size: const Size(34, 34),
            painter: _MegaphonePainter(
              angle: angle,
              waveScale: 0.6 + 0.6 * wave,
              waveOpacity: reduced
                  ? 1
                  : (wave < 0.5 ? wave * 2 : (1 - wave) * 2).clamp(0.0, 1.0),
            ),
          );
        },
      ),
    );
  }
}

class _MegaphonePainter extends CustomPainter {
  final double angle;
  final double waveScale;
  final double waveOpacity;

  const _MegaphonePainter({
    required this.angle,
    required this.waveScale,
    required this.waveOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    Paint stroke(double opacity) => Paint()
      ..color = AppColors.noticeText.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 몸통: M3 10v4h3l7 4V6L6 10Z (기준점 30% 60% = 7.2, 14.4)
    canvas.save();
    canvas.translate(7.2, 14.4);
    canvas.rotate(angle);
    canvas.translate(-7.2, -14.4);
    final body = Path()
      ..moveTo(3, 10)
      ..lineTo(3, 14)
      ..lineTo(6, 14)
      ..lineTo(13, 18)
      ..lineTo(13, 6)
      ..lineTo(6, 10)
      ..close();
    canvas.drawPath(body, stroke(1));
    canvas.restore();

    // 물결: M16 9a4 4 0 0 1 0 6 · M18.5 6.5a7.5 7.5 0 0 1 0 11 (기준점 14, 12)
    canvas.save();
    canvas.translate(14, 12);
    canvas.scale(waveScale);
    canvas.translate(-14, -12);
    final waves = Path()
      ..moveTo(16, 9)
      ..arcToPoint(const Offset(16, 15), radius: const Radius.circular(4))
      ..moveTo(18.5, 6.5)
      ..arcToPoint(
        const Offset(18.5, 17.5),
        radius: const Radius.circular(7.5),
      );
    canvas.drawPath(waves, stroke(waveOpacity));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MegaphonePainter old) =>
      old.angle != angle ||
      old.waveScale != waveScale ||
      old.waveOpacity != waveOpacity;
}
