import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../widgets/app_button.dart';
import 'app_colors.dart';
import 'app_icons.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

class AppFeedback {
  AppFeedback._();

  static String errorMessage(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? '입력값을 확인해주세요.';
    }
    if (error is TimeoutException) {
      return '응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.';
    }
    // 서버 함수가 사용자에게 보여줄 문구를 details.userMessage로 내려준 경우 그대로 쓴다.
    if (error is FirebaseFunctionsException) {
      final details = error.details;
      if (details is Map && details['userMessage'] is String) {
        return details['userMessage'] as String;
      }
    }
    if (error is FirebaseException) {
      switch (error.code) {
        // firebase_auth
        case 'wrong-password':
        case 'invalid-credential':
          return '비밀번호가 올바르지 않습니다.';
        case 'invalid-email':
          return '이메일 형식이 올바르지 않습니다.';
        case 'too-many-requests':
          return '시도가 너무 많습니다. 잠시 후 다시 시도해주세요.';
        case 'network-request-failed':
          return '네트워크 연결을 확인해주세요.';
        case 'requires-recent-login':
          return '보안을 위해 다시 로그인해주세요.';
        case 'unavailable':
        case 'deadline-exceeded':
          return '네트워크 연결이 불안정합니다. 잠시 후 다시 시도해주세요.';
        case 'permission-denied':
          return '권한이 없습니다. 로그인 상태나 공유 설정을 확인해주세요.';
        case 'failed-precondition':
          return '필요한 데이터 인덱스가 준비되지 않았습니다. 잠시 후 다시 시도해주세요.';
        case 'not-found':
          return '요청한 데이터를 찾을 수 없습니다.';
        case 'already-exists':
          return '이미 등록된 데이터입니다.';
        case 'resource-exhausted':
          return '요청이 많습니다. 잠시 후 다시 시도해주세요.';
        case 'unauthenticated':
          return '로그인이 필요합니다.';
        default:
          return '처리 중 오류가 발생했습니다. 다시 시도해주세요.';
      }
    }
    return '처리 중 오류가 발생했습니다. 다시 시도해주세요.';
  }

  /// 오류 토스트: 카드 면 pill + 경고 아이콘. 빨간 바탕은 쓰지 않는다.
  static void showErrorSnackBar(BuildContext context, Object error) {
    _showToast(context, errorMessage(error), icon: AppIcons.warning);
  }

  /// 입력 확인·안내처럼 오류 객체가 없는 경고 문구 토스트.
  static void showWarning(BuildContext context, String message) {
    _showToast(context, message, icon: AppIcons.warning);
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    _showToast(context, message);
  }

  static void _showToast(BuildContext context, String message, {IconData? icon}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSize.icon, color: AppColors.body),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(child: Text(message, style: AppTextStyles.buttonLabel)),
            ],
          ),
        ),
      );
  }
}

/// 오류 안내: 카드 + 경고 아이콘 + 문구 + 외곽선 "다시 시도".
class AppErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AppErrorCard({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.canvasCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.warning, color: AppColors.body, size: 28),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodyMd.copyWith(color: AppColors.body)),
            const SizedBox(height: AppSpacing.base),
            AppButton(label: '다시 시도', variant: AppButtonVariant.secondary, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
