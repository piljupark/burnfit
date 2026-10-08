import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../common/register_form.dart';

/// 회원가입 화면. 폼은 [RegisterForm]이 그린다.
class MemberRegisterScreen extends StatelessWidget {
  const MemberRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RegisterForm(title: '회원가입', role: UserRole.member);
  }
}
