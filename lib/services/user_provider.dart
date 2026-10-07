import 'package:flutter/foundation.dart';
import '../core/app_logger.dart';
import '../models/user.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/firestore_service.dart';

class UserProvider extends ChangeNotifier {
  AppUser? _user;
  bool _isLoading = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  Future<void> loadUser() async {
    final current = AuthService.currentUser;
    if (current == null) {
      _user = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _user = await FirestoreService.getUser(current.uid);
      if (_user != null) {
        // 승인된 사용자만 토큰 저장
        if (_user!.isApproved) {
          await FcmService.saveToken(current.uid);
        }
      }
    } catch (e) {
      AppLogger.debug('[UserProvider] 사용자 로드 실패: $e');
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 화면 전환 중 조용히 다시 읽는다 (로딩 표시·오류 없이). 담당 트레이너 변경 등을 반영.
  Future<void> refreshQuietly() async {
    final uid = _user?.uid;
    if (uid == null) return;
    try {
      final fresh = await FirestoreService.getUser(uid);
      if (fresh == null || _user?.uid != uid) return;
      _user = fresh;
      notifyListeners();
    } catch (e) {
      AppLogger.debug('[UserProvider] 조용한 새로고침 실패: $e');
    }
  }

  void setUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  void updateUserLocally(AppUser updated) {
    _user = updated;
    notifyListeners();
  }

  Future<void> signOut() async {
    final uid = _user?.uid;
    FcmService.clearPendingTarget();
    if (uid != null) await FcmService.removeToken(uid);
    await AuthService.signOut();
    _user = null;
    notifyListeners();
  }

  /// 계정을 탈퇴한다. 실패하면 예외를 그대로 던지고 로그인 상태는 유지된다.
  Future<void> deleteAccount(String password) async {
    final uid = _user?.uid ?? AuthService.currentUser?.uid;
    if (uid == null) throw StateError('로그인 상태가 아닙니다.');
    await AccountService.deleteMyAccount(uid: uid, password: password);
    _user = null;
    notifyListeners();
  }

  void clear() {
    FcmService.clearPendingTarget();
    _user = null;
    notifyListeners();
  }
}
