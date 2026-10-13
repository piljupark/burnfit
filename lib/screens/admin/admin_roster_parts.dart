import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/roster_import.dart';
import '../../core/validators.dart';
import '../../models/roster_entry.dart';
import '../../services/roster_service.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_confirm_dialog.dart';
import 'admin_roster_upload_screen.dart';

// 관리자 회원 탭 · 트레이너 탭이 함께 쓰는 명단 부품 (시안 09 '미가입 목록').

/// 탭 제목 줄 오른쪽 '명단 업로드' 글자 버튼 (14/500 body, 누름 높이 44).
class RosterUploadButton extends StatelessWidget {
  final VoidCallback onPressed;

  const RosterUploadButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: AppSize.touchMin,
          child: Center(
            widthFactor: 1,
            child: Text(
              '명단 업로드',
              style: AppTextStyles.bodySmall.medium.copyWith(
                color: AppColors.body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 명단 업로드 화면을 연다 ([role] 'member' | 'trainer'). 등록했으면 true.
Future<bool> openRosterUpload(BuildContext context, String role) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => AdminRosterUploadScreen(role: role)),
  );
  return saved == true;
}

/// 미가입 줄 시트(이름 · 가린 번호 · 요약) → '명단에서 지우기' → 확인 창. 지웠으면 true.
Future<bool> showRosterEntryActions(BuildContext context, RosterEntry e) async {
  final remove = await showAppBottomSheet<bool>(
    context: context,
    child: Builder(
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBottomSheetHeader(
            title: e.name,
            subtitle: e.isTrainer
                ? Validators.maskPhone(e.phone)
                : '${Validators.maskPhone(e.phone)} · ${RosterImport.summary(e)}',
            mutedSubtitle: true,
            gap: AppSpacing.md,
          ),
          AppSheetAction(
            icon: AppIcons.trash,
            label: '명단에서 지우기',
            destructive: true,
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
        ],
      ),
    ),
  );
  if (remove != true || !context.mounted) return false;
  final ok = await showAppConfirmDialog(
    context,
    title: '명단에서 지우기',
    message: '${e.name}님 줄을 지웁니다. 가입해도 가입 요청에 명단 정보가 뜨지 않아요.',
    confirmLabel: '지우기',
  );
  if (!ok || !context.mounted) return false;
  try {
    await RosterService.delete(e.centerId, e.id);
    if (!context.mounted) return true;
    AppFeedback.showSuccessSnackBar(context, '명단에서 지웠어요');
    return true;
  } catch (err) {
    if (context.mounted) AppFeedback.showErrorSnackBar(context, err);
    return false;
  }
}

/// 미가입 한 줄 (좌우 20 · 위아래 14 · 아래 hairline): 이름 16/500 + '미가입' 13 mute →
/// '010-****-5678 · 박코치 · PT 10회 (기간)' 13 mute → 'M월 d일 올림' 12 mute · 화살표 18.
class RosterEntryRow extends StatelessWidget {
  final RosterEntry entry;
  final VoidCallback onTap;

  const RosterEntryRow({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final detail = e.isTrainer
        ? Validators.maskPhone(e.phone)
        : '${Validators.maskPhone(e.phone)} · ${RosterImport.summary(e)}';
    return Semantics(
      button: true,
      label: '${e.name}, 미가입, $detail',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: e.name),
                            TextSpan(
                              text: '  미가입',
                              style: AppTextStyles.counter,
                            ),
                          ],
                        ),
                        style: AppTextStyles.listTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(detail, style: AppTextStyles.counter),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('M월 d일').format(e.updatedAt)} 올림',
                        style: AppTextStyles.captionSmall,
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.forward, size: 18, color: AppColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 미가입 목록 아래 안내 12.
class RosterHint extends StatelessWidget {
  final bool trainer;

  const RosterHint({super.key, this.trainer = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        0,
      ),
      child: Text(
        trainer
            ? "가입하면 '가입 요청'에 '명단과 일치'로 떠요. 승인하면 미가입에서 빠져요."
            : "가입하면 '가입 요청'에 '명단과 일치'로 떠요. 승인하면 담당 · PT가 붙고 미가입에서 빠져요.",
        style: AppTextStyles.captionSmall.copyWith(height: 1.5),
      ),
    );
  }
}
