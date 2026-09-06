import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_feedback.dart';
import '../../core/app_text_styles.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_screen_header.dart';

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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppScreenHeader(
                title: '기록 공유 설정',
                subtitle:
                    '${(trainerName?.isNotEmpty ?? false) ? trainerName : '담당'} 트레이너에게 공유되는 항목을 설정하세요',
                onBack: () => Navigator.of(context).pop(),
              ),
              const Gap(20),
              _ShareRow(
                title: '운동 기록 공유',
                subtitle: '세트, 부위, 시간',
                value: _settings.workout,
                onChanged: (value) {
                  _update(_settings.copyWith(workout: value));
                },
              ),
              const Gap(12),
              _ShareRow(
                title: '식단 기록 공유',
                subtitle: '사진, 메모',
                value: _settings.meal,
                onChanged: (value) {
                  _update(_settings.copyWith(meal: value));
                },
              ),
              const Gap(12),
              _ShareRow(
                title: '체중/신체 정보 공유',
                subtitle: '체중, 체지방률 변화',
                value: _settings.body,
                onChanged: (value) {
                  _update(_settings.copyWith(body: value));
                },
              ),
              if (_saving) ...[
                const Gap(16),
                Text(
                  '저장 중...',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ShareRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      hasBorder: false,
      hasShadow: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(4),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppColors.workout,
            inactiveTrackColor: const Color(0x29787880),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
