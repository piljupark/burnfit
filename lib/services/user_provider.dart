import 'dart:async';

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

  /// 로그인한 사용자 문서 구독. 관리자의 승인·거절이 바로 반영되게 한다
  /// (화면 이동은 AccountStatusListener가 맡는다).
  StreamSubscription<AppUser?>? _userSub;
  String? _watchingUid;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  Future<void> loadUser() async {
    final current = AuthService.currentUser;
    if (current == null) {
      _detach();
      _user = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final loaded = await FirestoreService.getUser(current.uid);
      _user = loaded;
      if (loaded != null) {
        _attach(loaded);
      } else {
        _detach();
      }
    } catch (e) {
      AppLogger.debug('[UserProvider] 사용자 로드 실패: $e');
      _detach();
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 화면 전환 중 조용히 다시 읽는다 (로딩 표시·오류 없이). 담당 트레이너 변경 등을 반영.
  /// 실패해도 지금 사용자와 구독은 그대로 두고 false를 돌려준다.
  Future<bool> refreshQuietly() async {
    final uid = _user?.uid;
    if (uid == null) return false;
    try {
      final fresh = await FirestoreService.getUser(uid);
      if (fresh == null || _user?.uid != uid) return false;
      _user = fresh;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.debug('[UserProvider] 조용한 새로고침 실패: $e');
      return false;
    }
  }

  /// 로그인·가입 직후 호출한다. 문서 구독과 알림 토큰 저장도 여기서 시작한다.
  void setUser(AppUser user) {
    _user = user;
    _attach(user);
    notifyListeners();
  }

  void updateUserLocally(AppUser updated) {
    _user = updated;
    notifyListeners();
  }

  Future<void> signOut() async {
    final uid = _user?.uid;
    _detach();
    FcmService.clearPendingTarget();
    if (uid != null) await FcmService.removeToken(uid);
    await AuthService.signOut();
    _user = null;
    notifyListeners();
  }

  /// 계정을 탈퇴한다. 실패하면 예외를 그대로 던지고 로그인 상태는 유지된다.
  Future<void> deleteAccount(String password) async {
    final current = _user;
    final uid = current?.uid ?? AuthService.currentUser?.uid;
    if (uid == null) throw StateError('로그인 상태가 아닙니다.');
    // 서버가 사용자 문서를 지우는 동안 구독이 '문서 없음'·권한 오류를 받지 않게 먼저 끊는다.
    _detach();
    try {
      await AccountService.deleteMyAccount(uid: uid, password: password);
    } catch (_) {
      if (current != null) _attach(current);
      rethrow;
    }
    _user = null;
    notifyListeners();
  }

  void clear() {
    _detach();
    FcmService.clearPendingTarget();
    _user = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  /// [user]의 문서 구독을 시작하고 알림 토큰을 저장한다. 같은 사용자면 구독은 그대로 둔다.
  void _attach(AppUser user) {
    // 승인 대기 중에도 토큰을 저장해야 승인 알림이 푸시로 간다. 거절된 계정은 곧 로그아웃된다.
    if (user.status != UserStatus.rejected) {
      unawaited(FcmService.saveToken(user.uid));
    }
    if (_watchingUid == user.uid) return;
    _detach();
    _watchingUid = user.uid;
    _userSub = FirestoreService.watchUser(user.uid).listen(
      (fresh) {
        // 다른 계정으로 바뀌었거나, 문서가 지워지는 중(탈퇴)이면 무시한다.
        if (fresh == null || _user?.uid != fresh.uid) return;
        _user = fresh;
        notifyListeners();
      },
      onError: (Object e) {
        AppLogger.debug('[UserProvider] 사용자 문서 구독 오류: $e');
      },
    );
  }

  void _detach() {
    _userSub?.cancel();
    _userSub = null;
    _watchingUid = null;
  }
}
