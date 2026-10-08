import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../common/register_form.dart';

/// 트레이너 등록 화면. 폼은 [RegisterForm]이 그린다.
class TrainerRegisterScreen extends StatelessWidget {
  const TrainerRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RegisterForm(title: '트레이너 등록', role: UserRole.trainer);
  }
}
