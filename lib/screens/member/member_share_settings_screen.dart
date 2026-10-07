import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_icons.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_action_row.dart';
import '../../widgets/app_hero.dart';
import '../../widgets/app_screen_header.dart';
import '../../widgets/orb_loader.dart';

class MemberShareSettingsScreen extends StatefulWidget {
  const MemberShareSettingsScreen({super.key});

  @override
  State<MemberShareSettingsScreen> createState() =>
      _MemberShareSettingsScreenState();
}

class _MemberShareSettingsScreenState extends State<MemberShareSettingsScreen> {
  late ShareSettings _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings =
        context.read<UserProvider>().user?.shareSettings ??
        const ShareSettings();
  }

  Future<void> _update(ShareSettings next) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null || _saving) return;

    setState(() {
      _settings = next;
      _saving = true;
    });

    try {
      await FirestoreService.updateUser(user.uid, {
        'shareSettings': next.toMap(),
      });
      userProvider.updateUserLocally(user.copyWith(shareSettings: next));
    } catch (e) {
      if (!mounted) return;
      setState(() => _settings = user.shareSettings);
      AppFeedback.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final trainerName = user?.trainerName?.trim();
    final trainerLabel = (trainerName?.isNotEmpty ?? false) ? '$trainerName 트레이너' : '담당 트레이너';
    final sharedCount = [_settings.workout, _settings.meal, _settings.body].where((v) => v).length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: AppScreenHeader(
                title: '기록 공유 설정',
                onBack: () => Navigator.of(context).pop(),
                trailing: _saving ? const OrbLoader.inline(semanticLabel: '저장 중') : null,
              ),
            ),
            const AppRowDivider(),
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.xl,
                      AppSpacing.screenH,
                      0,
                    ),
                    child: Text(
                      '$trainerLabel에게 공유되는 항목을 설정하세요. 끄면 트레이너가 해당 기록을 볼 수 없습니다.',
                      style: AppTextStyles.bodyMd.copyWith(color: AppColors.body),
                    ),
                  ),
                  AppMonthHeader(label: 'SHARED', count: '$sharedCount / 3'),
                  _ShareRow(
                    icon: AppIcons.workout,
                    title: '운동 기록 공유',
                    subtitle: '세트, 부위, 시간',
                    value: _settings.workout,
                    onChanged: (value) {
                      _update(_settings.copyWith(workout: value));
                    },
                  ),
                  const AppRowDivider(indent: AppSpacing.screenH),
                  _ShareRow(
                    icon: AppIcons.meal,
                    title: '식단 기록 공유',
                    subtitle: '사진, 메모',
                    value: _settings.meal,
                    onChanged: (value) {
                      _update(_settings.copyWith(meal: value));
                    },
                  ),
                  const AppRowDivider(indent: AppSpacing.screenH),
                  _ShareRow(
                    icon: AppIcons.inbody,
                    title: '체중/신체 정보 공유',
                    subtitle: '체중, 체지방률 변화',
                    value: _settings.body,
                    onChanged: (value) {
                      _update(_settings.copyWith(body: value));
                    },
                  ),
                  const AppRowDivider(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 공유 항목 한 줄: 아이콘 + 라벨(17) + 보조 줄 + 테마 Switch. 줄 전체가 토글 영역.
class _ShareRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ShareRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, size: AppSize.icon, color: AppColors.ink),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyLg),
                      Text(subtitle, style: AppTextStyles.bodySm),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
