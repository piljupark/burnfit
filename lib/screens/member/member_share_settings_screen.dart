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
import '../../widgets/app_screen_header.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/app_loader.dart';

/// 기록 공유 설정 (시안 MemB-Share): 가운데 17 머리 → 안내 15 → '공유 중  2 / 3' →
/// 72 높이 줄 3개(40 아이콘 상자 + 16/500 제목 + 14 보조 + 52×32 스위치), 좌우 20 안쪽 선.
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
    final trainerLabel = (trainerName?.isNotEmpty ?? false)
        ? '$trainerName 트레이너'
        : '담당 트레이너';
    final sharedCount = [
      _settings.workout,
      _settings.meal,
      _settings.body,
    ].where((v) => v).length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppScreenHeader.centered(
              title: '기록 공유 설정',
              onBack: () => Navigator.of(context).pop(),
              trailing: _saving
                  ? const AppLoader.inline(semanticLabel: '저장 중')
                  : null,
            ),
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.base,
                      AppSpacing.screenH,
                      0,
                    ),
                    child: Text(
                      '$trainerLabel에게 공유되는 항목을 설정하세요. 끄면 트레이너가 해당 기록을 볼 수 없습니다.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.body,
                        height: 1.55,
                      ),
                    ),
                  ),
                  // '공유 중' + 오른쪽 끝 '2 / 3' (공유 수만 500 ink)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.xl,
                      AppSpacing.screenH,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text('공유 중', style: AppTextStyles.eyebrow),
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$sharedCount',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.ink,
                                ),
                              ),
                              const TextSpan(text: ' / 3'),
                            ],
                          ),
                          style: AppTextStyles.eyebrow,
                        ),
                      ],
                    ),
                  ),
                  _ShareRow(
                    icon: AppIcons.workout,
                    title: '운동 기록 공유',
                    subtitle: '세트, 부위, 시간',
                    value: _settings.workout,
                    introDelay: const Duration(milliseconds: 400),
                    onChanged: (value) {
                      _update(_settings.copyWith(workout: value));
                    },
                  ),
                  _ShareRow(
                    icon: AppIcons.meal,
                    title: '식단 기록 공유',
                    subtitle: '사진, 메모',
                    value: _settings.meal,
                    introDelay: const Duration(milliseconds: 500),
                    onChanged: (value) {
                      _update(_settings.copyWith(meal: value));
                    },
                  ),
                  _ShareRow(
                    icon: AppIcons.clipboard,
                    title: '체중/신체 정보 공유',
                    subtitle: '체중, 체지방률 변화',
                    value: _settings.body,
                    introDelay: const Duration(milliseconds: 600),
                    last: true,
                    onChanged: (value) {
                      _update(_settings.copyWith(body: value));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 공유 항목 한 줄 (최소 72): 40 아이콘 상자(반경 12) + 간격 14 + 제목 16/500 · 보조 14 mute + 스위치.
/// 줄 전체가 토글 영역. 아래 선은 좌우 20 안쪽, 마지막 줄은 없음.
class _ShareRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Duration introDelay;
  final bool last;
  final ValueChanged<bool> onChanged;

  const _ShareRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.introDelay,
    required this.onChanged,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        highlightColor: AppColors.canvasSoft,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            decoration: last
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.hairline),
                    ),
                  ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.canvasCard,
                    borderRadius: BorderRadius.circular(AppRadius.iconBox),
                  ),
                  child: Icon(
                    AppIcons.bold(icon),
                    size: 22,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppTextStyles.listTitle),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: AppTextStyles.note.copyWith(
                          color: AppColors.mute,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppSwitch(value: value, introDelay: introDelay),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
