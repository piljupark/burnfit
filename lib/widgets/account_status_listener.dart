import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_routing.dart';
import '../core/constants.dart';
import '../models/user.dart';
import '../services/user_provider.dart';
import 'app_toast.dart';

/// 로그인 중 관리자가 계정을 승인·거절하거나 승인을 취소하면 맞는 화면으로 옮긴다.
///
/// [UserProvider]가 사용자 문서를 구독하고, 이 위젯은 상태 변화만 보고 이동한다.
/// 이동할 때는 쌓인 화면을 모두 지워 권한 없는 화면으로 돌아가지 못하게 한다.
/// MaterialApp의 `builder`에서 앱 전체를 감싼다.
class AccountStatusListener extends StatefulWidget {
  final Widget child;

  const AccountStatusListener({super.key, required this.child});

  @override
  State<AccountStatusListener> createState() => _AccountStatusListenerState();
}

class _AccountStatusListenerState extends State<AccountStatusListener> {
  late final UserProvider _provider;
  AppUser? _last;

  @override
  void initState() {
    super.initState();
    _provider = context.read<UserProvider>();
    _last = _provider.user;
    _provider.addListener(_onUserChanged);
  }

  @override
  void dispose() {
    _provider.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onUserChanged() {
    final before = _last;
    final after = _provider.user;
    _last = after;
    final change = accountStatusChange(before, after);
    if (change == null || after == null) return;
    _handle(change, after);
  }

  Future<void> _handle(AccountStatusChange change, AppUser user) async {
    switch (change) {
      case AccountStatusChange.approved:
        final route = startRouteFor(user);
        if (route == null) return;
        _resetTo(route);
        AppToast.show(
          null,
          message: '가입이 승인되었어요. 지금 바로 이용할 수 있어요.',
          kind: AppToastKind.success,
        );
      case AccountStatusChange.backToPending:
        _resetTo(AppRoutes.pendingApproval);
        AppToast.show(
          null,
          message: '센터에서 계정 승인을 다시 검토하고 있어요.',
          kind: AppToastKind.wait,
        );
      case AccountStatusChange.rejected:
        await _provider.signOut();
        _resetTo(AppRoutes.memberLogin);
        AppToast.show(
          null,
          message: '가입이 거절되었습니다. 다시 로그인하면 계정을 정리하고 새로 신청할 수 있어요.',
          kind: AppToastKind.error,
        );
    }
  }

  void _resetTo(String route) {
    appNavigatorKey.currentState?.pushNamedAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
