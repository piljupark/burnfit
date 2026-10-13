import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_haptics.dart';
import '../core/app_icons.dart';
import '../core/app_spacing.dart';
import '../core/app_text_styles.dart';
import '../core/consent_terms.dart';
import 'app_bottom_sheet.dart';

/// 가입 동의 묶음 (시안 09 '동의'): 테두리 상자(반경 20) 안에 회색 '전체 동의' 줄 →
/// '[필수] 개인정보 수집 · 이용' (+ 회원이면 '[필수] 건강 정보 수집 · 이용') 줄.
/// 줄마다 동그라미 24(체크하면 주황) · 제목 14/500 · 요약 12 mute · 오른쪽 '보기'(전문 시트).
///
/// 체크 상태는 부모가 들고 있다 (가입 확인 단계 · 동의 화면).
class ConsentChecklist extends StatelessWidget {
  final bool privacy;

  /// null이면 건강 정보 줄을 두지 않는다 (트레이너 · 관리자).
  final bool? health;
  final ValueChanged<bool> onPrivacy;
  final ValueChanged<bool>? onHealth;

  const ConsentChecklist({
    super.key,
    required this.privacy,
    required this.onPrivacy,
    this.health,
    this.onHealth,
  });

  bool get _all => privacy && (health ?? true);

  void _toggleAll() {
    final next = !_all;
    AppHaptics.selection();
    onPrivacy(next);
    if (health != null) onHealth?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            checked: _all,
            label: '전체 동의',
            excludeSemantics: true,
            child: InkWell(
              onTap: _toggleAll,
              child: Container(
                color: AppColors.canvasCard,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _Check(on: _all),
                    const SizedBox(width: AppSpacing.md),
                    Text('전체 동의', style: AppTextStyles.listTitle.bold),
                  ],
                ),
              ),
            ),
          ),
          _Item(
            document: ConsentTerms.privacy,
            checked: privacy,
            onChanged: onPrivacy,
          ),
          if (health != null)
            _Item(
              document: ConsentTerms.health,
              checked: health!,
              onChanged: (v) => onHealth?.call(v),
            ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final ConsentDocument document;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _Item({
    required this.document,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            checked: checked,
            label: '필수 ${document.title}',
            excludeSemantics: true,
            child: InkWell(
              onTap: () {
                AppHaptics.selection();
                onChanged(!checked);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    _Check(on: checked),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '[필수] ',
                                  style: TextStyle(color: AppColors.noticeText),
                                ),
                                TextSpan(text: document.title),
                              ],
                            ),
                            style: AppTextStyles.bodySmall.medium.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            document.summary,
                            style: AppTextStyles.captionSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: '${document.title} 전문 보기',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => showConsentDocument(context, document),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.md,
              ),
              child: Text(
                '보기',
                style: AppTextStyles.bodySm.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.mute,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  final bool on;

  const _Check({required this.on});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? AppColors.primary : null,
        border: on ? null : Border.all(color: AppColors.canvasMid, width: 1.5),
      ),
      child: on
          ? Icon(AppIcons.checkBold, size: 14, color: AppColors.onPrimary)
          : null,
    );
  }
}

/// 동의 전문 시트: 안내 → 항목 · 목적 표 → 보관 기간 · 보는 사람 · 맡기는 곳 → 거부 권리 → 판.
Future<void> showConsentDocument(BuildContext context, ConsentDocument doc) {
  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.base, bottom: 4),
    child: Text(
      text,
      style: AppTextStyles.bodySmall.medium.copyWith(color: AppColors.ink),
    ),
  );
  Widget body(String text) =>
      Text(text, style: AppTextStyles.note.copyWith(height: 1.55));
  return showAppBottomSheet<void>(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBottomSheetHeader(title: doc.title, gap: AppSpacing.md),
        body(doc.intro),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: AppColors.canvasCard,
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: Column(
            children: [
              _DocRow(left: '항목', right: '목적', header: true),
              for (final r in doc.rows)
                _DocRow(left: r.items, right: r.purpose),
            ],
          ),
        ),
        label('보관 기간'),
        body(doc.retention),
        label('보는 사람'),
        body(doc.viewers),
        label('맡기는 곳'),
        body(ConsentTerms.processor),
        label('동의하지 않을 권리'),
        body(doc.refusal),
        const SizedBox(height: AppSpacing.base),
        Text(
          '동의서 ${ConsentTerms.versionLabel}',
          style: AppTextStyles.captionSmall,
        ),
      ],
    ),
  );
}

class _DocRow extends StatelessWidget {
  final String left;
  final String right;
  final bool header;

  const _DocRow({required this.left, required this.right, this.header = false});

  @override
  Widget build(BuildContext context) {
    final style = header
        ? AppTextStyles.captionSmall
        : AppTextStyles.caption.copyWith(color: AppColors.ink, height: 1.45);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: header
          ? null
          : BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(left, style: style)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(right, style: style)),
        ],
      ),
    );
  }
}
