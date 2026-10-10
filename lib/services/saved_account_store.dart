import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import '../models/user.dart';

/// 이 기기에서 마지막으로 로그인(또는 가입)한 계정.
/// 로그인 화면이 '다시 오셨네요' 카드로 보여 주고 비밀번호만 받는다.
class SavedAccount {
  final String email;
  final String centerName;
  final UserRole role;

  const SavedAccount({
    required this.email,
    required this.centerName,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
    'email': email,
    'centerName': centerName,
    'role': role.name,
  };

  /// 저장된 값이 모자라거나 알 수 없는 역할이면 null.
  static SavedAccount? fromMap(Map<String, dynamic> map) {
    final email = map['email'];
    final centerName = map['centerName'];
    final roleName = map['role'];
    if (email is! String || email.isEmpty) return null;
    if (centerName is! String || roleName is! String) return null;
    final role = UserRole.values.where((r) => r.name == roleName).firstOrNull;
    if (role == null) return null;
    return SavedAccount(email: email, centerName: centerName, role: role);
  }
}

/// 마지막 계정을 기기에만 저장한다 (테마 선택과 같은 `shared_preferences`).
///
/// 비밀번호는 저장하지 않는다. 다른 계정으로 로그인하면 덮어쓰고, 탈퇴하거나 거절된 계정을
/// 지우면 함께 지운다. 읽기·쓰기에 실패해도 로그인은 막지 않는다 (저장 없이 처음 화면으로).
class SavedAccountStore {
  SavedAccountStore._();

  static const _prefsKey = 'saved_login_account';

  static Future<SavedAccount?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return SavedAccount.fromMap(decoded);
    } catch (e) {
      AppLogger.debug('[SavedAccount] 읽기 실패: $e');
      return null;
    }
  }

  static Future<void> save(AppUser user) async {
    final account = SavedAccount(
      email: user.email,
      centerName: user.centerName,
      role: user.role,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(account.toMap()));
    } catch (e) {
      AppLogger.debug('[SavedAccount] 저장 실패: $e');
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      AppLogger.debug('[SavedAccount] 지우기 실패: $e');
    }
  }
}
