import 'package:flutter/foundation.dart';
import '../core/app_logger.dart';
import '../models/user.dart';
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

  void clear() {
    FcmService.clearPendingTarget();
    _user = null;
    notifyListeners();
  }
}
