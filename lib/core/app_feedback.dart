import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

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

  static void showErrorSnackBar(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage(error)),
        backgroundColor: AppColors.destructive,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class AppErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AppErrorCard({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.textDisabled,
                size: 28,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: const Text(
                    '다시 시도',
                    style: TextStyle(
                      color: AppColors.textOnAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
