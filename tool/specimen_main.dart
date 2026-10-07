// 글자 세로 정렬 견본 (웹 확인용, 앱에 포함되지 않음). flutter build web -t tool/specimen_main.dart
import 'package:flutter/material.dart';
import 'package:pt_solution_v2/core/app_colors.dart';
import 'package:pt_solution_v2/core/app_icons.dart';
import 'package:pt_solution_v2/core/app_theme.dart';
import 'package:pt_solution_v2/widgets/app_button.dart';
import 'package:pt_solution_v2/widgets/app_tag.dart';
import 'package:pt_solution_v2/widgets/app_text_field.dart';
import 'package:pt_solution_v2/widgets/set_input.dart';

void main() {
  final filled = TextEditingController(text: '50');
  final empty = TextEditingController();
  final email = TextEditingController(text: 'member@burnfit.test');
  runApp(
    MaterialApp(
      theme: AppTheme.current,
      home: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: SetValueField(
                      controller: filled,
                      decimal: true,
                      highlighted: false,
                      semanticLabel: 'w',
                      onChanged: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SetValueField(
                      controller: empty,
                      decimal: false,
                      highlighted: true,
                      semanticLabel: 'r',
                      onChanged: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(label: '이메일', controller: email),
              const SizedBox(height: 8),
              const AppTextField(label: '비밀번호', hint: '비밀번호'),
              const SizedBox(height: 8),
              AppTextField(
                label: '',
                hint: '이름 또는 이메일 검색',
                prefix: const Icon(AppIcons.search),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: '로그인 Login 123',
                onPressed: () {},
                fullWidth: true,
                size: AppButtonSize.lg,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  AppButton(
                    label: '기록 시작',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: '운동 추가',
                    variant: AppButtonVariant.secondary,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const AppTag('완료', strong: true),
                  const AppTag('예약'),
                  const AppTag('D-85'),
                  const AppTag('12회 남음'),
                  AppChip(label: '전체', selected: true, onTap: () {}),
                  AppChip(label: '아침', selected: false, onTap: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
