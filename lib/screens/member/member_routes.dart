import 'package:flutter/material.dart';

import 'member_feedback_screen.dart';
import 'member_meal_log_screen.dart';

/// 회원 하위 화면으로 가는 경로를 한곳에 모은다.
/// 홈 캘린더·마이 탭·알림이 같은 화면을 같은 방식으로 열도록 한다.
class MemberRoutes {
  MemberRoutes._();

  static Future<void> openMealLog(BuildContext context, {DateTime? date}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemberMealLogScreen(initialDate: date)),
    );
  }

  static Future<void> openFeedback(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MemberFeedbackScreen()),
    );
  }
}
