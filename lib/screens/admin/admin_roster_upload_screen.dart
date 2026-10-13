import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/roster_import.dart';
import '../../services/firestore_service.dart';
import '../../services/roster_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_inputs.dart';
import '../../widgets/app_screen_header.dart';

/// 명단 업로드 (시안 09 '명단 올리기'): 회원 탭 · 트레이너 탭의 '명단 업로드'에서 연다.
/// [role]의 명단만 받는다. 칸 안내 → '파일 고르기' →
/// 3칸 결과(가입됨 · 미가입 · 확인 필요) → 줄마다 결과 → 아래 '미가입 N명 등록'.
///
/// 확인 필요 줄 · 가입됨 줄은 저장하지 않는다. 같은 번호가 명단에 있으면 덮어쓴다.
/// 등록하면 true로 닫힌다.
class AdminRosterUploadScreen extends StatefulWidget {
  /// 'member' | 'trainer'
  final String role;

  const AdminRosterUploadScreen({super.key, required this.role});

  bool get isTrainer => role == 'trainer';

  @override
  State<AdminRosterUploadScreen> createState() =>
      _AdminRosterUploadScreenState();
}

class _AdminRosterUploadScreenState extends State<AdminRosterUploadScreen> {
  String? _fileName;
  List<RosterPreviewRow> _rows = const [];
  bool _reading = false;
  bool _saving = false;

  List<RosterPreviewRow> _of(RosterCheck c) =>
      _rows.where((r) => r.check == c).toList();

  Future<void> _pick() async {
    final admin = context.read<UserProvider>().user;
    if (admin == null || _reading) return;
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
    );
    if (file == null || !mounted) return;
    setState(() => _reading = true);
    try {
      final bytes = await file.xFile.readAsBytes();
      final table = RosterImport.readTable(bytes, file.name);
      // 둘을 함께 읽는다
      final trainersFuture = FirestoreService.getTrainersByCenter(
        admin.centerId,
      );
      final joinedFuture = RosterService.joinedPhones(admin.centerId);
      final trainers = [
        for (final t in await trainersFuture) (uid: t.uid, name: t.name),
      ];
      final joined = await joinedFuture;
      final rows = RosterImport.check(
        table,
        role: widget.role,
        centerId: admin.centerId,
        trainers: trainers,
        joinedPhones: joined,
      );
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _rows = rows;
      });
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _save() async {
    final admin = context.read<UserProvider>().user;
    final ready = _of(RosterCheck.ready);
    if (admin == null || ready.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await RosterService.saveAll(admin.centerId, [
        for (final r in ready) r.entry!,
      ]);
      if (!mounted) return;
      AppFeedback.showSuccessSnackBar(context, '미가입 ${ready.length}명을 등록했어요');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _of(RosterCheck.ready).length;
    final problems = _of(RosterCheck.problem).length;
    final joined = _of(RosterCheck.joined).length;
    // 확인 필요 → 미가입 → 가입됨 순 (고칠 것부터)
    final ordered = [
      ..._of(RosterCheck.problem),
      ..._of(RosterCheck.ready),
      ..._of(RosterCheck.joined),
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.centered(
              title: widget.isTrainer ? '트레이너 명단 업로드' : '회원 명단 업로드',
              onBack: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.xl,
                ),
                children: [
                  _ColumnGuide(role: widget.role),
                  const SizedBox(height: AppSpacing.base),
                  AppButton(
                    label: _fileName == null ? '파일 고르기' : '다른 파일 고르기',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    isLoading: _reading,
                    icon: const Icon(AppIcons.upload, size: 20),
                    onPressed: _reading || _saving ? null : _pick,
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        _Stat(label: '가입됨', value: joined),
                        const SizedBox(width: AppSpacing.sm),
                        _Stat(label: '미가입', value: ready),
                        const SizedBox(width: AppSpacing.sm),
                        _Stat(label: '확인 필요', value: problems, warn: true),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '$_fileName · ${_rows.length}줄',
                      style: AppTextStyles.counter,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final r in ordered) _PreviewRow(row: r),
                  ],
                ],
              ),
            ),
            if (_fileName != null)
              AppBottomActionBar(
                primaryLabel: ready == 0
                    ? '등록할 줄이 없어요'
                    : problems > 0
                    ? '$ready명 등록 · 확인 필요 $problems줄은 빼고'
                    : '$ready명 등록',
                loading: _saving,
                onPrimary: ready == 0 || _saving ? null : _save,
              ),
          ],
        ),
      ),
    );
  }
}

/// 칸 순서 안내 (회색 상자 반경 14).
class _ColumnGuide extends StatelessWidget {
  final String role;

  const _ColumnGuide({required this.role});

  @override
  Widget build(BuildContext context) {
    final body = AppTextStyles.note.copyWith(height: 1.55);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.canvasCard,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '엑셀(.xlsx) · CSV 첫 줄에 칸 이름을 적어 주세요',
            style: AppTextStyles.bodySmall.medium.copyWith(
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(RosterImport.columnsFor(role).join(' · '), style: body),
          const SizedBox(height: AppSpacing.xs),
          Text(
            role == 'trainer'
                ? '필수: 이름 · 휴대폰. 같은 번호를 다시 올리면 덮어써요.'
                : '필수: 이름 · 휴대폰. 담당 트레이너는 앱에 가입한 트레이너 이름 그대로. '
                      '날짜는 2026-10-01처럼. 같은 번호를 다시 올리면 덮어써요.',
            style: AppTextStyles.captionSmall.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final bool warn;

  const _Stat({required this.label, required this.value, this.warn = false});

  @override
  Widget build(BuildContext context) {
    final emphasize = warn && value > 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.captionSmall),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: AppTextStyles.title.bold.copyWith(
                color: emphasize ? AppColors.noticeText : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 결과 한 줄: 이름 15/500 + 결과 13 mute (확인 필요는 noticeText) · 오른쪽 상태 글자.
class _PreviewRow extends StatelessWidget {
  final RosterPreviewRow row;

  const _PreviewRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (row.check) {
      RosterCheck.joined => ('가입됨', AppColors.mute),
      RosterCheck.ready => ('미가입', AppColors.ink),
      RosterCheck.problem => ('확인 필요', AppColors.noticeText),
    };
    final problem = row.check == RosterCheck.problem;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: AppTextStyles.bodyMd.medium.copyWith(
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  problem ? '${row.line}번째 줄 · ${row.message}' : row.message,
                  style: AppTextStyles.counter.copyWith(
                    color: problem ? AppColors.noticeText : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: AppTextStyles.counter.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
