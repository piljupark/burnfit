import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pt_solution_v2/models/pt_info.dart';
import 'package:pt_solution_v2/models/user.dart';
import 'package:pt_solution_v2/models/workout.dart';
import 'package:pt_solution_v2/screens/trainer/nutrition_plan_screen.dart';
import 'package:pt_solution_v2/screens/trainer/trainer_members_screen.dart';
import 'package:pt_solution_v2/services/trainer_members_service.dart';

final _today = DateTime(2026, 10, 12);

AppUser _user(
  String uid,
  String name, {
  DateTime? createdAt,
  UserRole role = UserRole.member,
}) => AppUser(
  uid: uid,
  email: '$uid@x.kr',
  name: name,
  role: role,
  status: UserStatus.approved,
  centerId: 'c1',
  centerName: '센터',
  createdAt: createdAt ?? DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

PtInfo _pt(int remaining, {DateTime? end}) => PtInfo(
  id: 'p',
  centerId: 'c1',
  memberId: 'm',
  memberName: '',
  totalSessions: 20,
  remainingSessions: remaining,
  endDate: end,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Workout _workout(String date) => Workout(
  id: date,
  centerId: 'c1',
  memberId: 'm',
  memberName: '',
  createdById: 'm',
  createdByRole: WorkoutCreatedByRole.member,
  workoutDate: date,
  category: WorkoutCategory.chest,
  exercises: const [
    Exercise(name: '푸시업', sets: [ExerciseSet(weight: 0, reps: 10)]),
  ],
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

TrainerMemberSummary _summary({
  String name = '김민지',
  PtInfo? pt,
  List<Workout> workouts = const [],
  bool hasPlan = true,
  int pending = 0,
  DateTime? createdAt,
}) => TrainerMembersService.build(
  member: _user('m-$name', name, createdAt: createdAt),
  ptInfo: pt,
  workouts: workouts,
  hasPlan: hasPlan,
  pendingMeals: pending,
  today: _today,
);

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  group('회원 요약', () {
    test('마지막 운동 · 2주 넘게 없으면 주의', () {
      final s = _summary(
        workouts: [_workout('2026-10-09'), _workout('2026-10-01')],
      );
      expect(s.workoutLabel, '3일 전 운동');
      expect(s.idle, isFalse);
      expect(
        _summary(workouts: [_workout('2026-10-12')]).workoutLabel,
        '오늘 운동',
      );
      expect(_summary(workouts: [_workout('2026-09-20')]).idle, isTrue);
      expect(_summary().workoutLabel, '30일간 운동 없음');
      // 새 회원은 기록이 없어도 주의 표시를 하지 않는다
      expect(_summary(createdAt: DateTime(2026, 10, 11)).idle, isFalse);
    });

    test('PT 곧 끝남: 3회 이하 또는 14일 안, 끝난 PT는 아님', () {
      expect(_summary(pt: _pt(3)).ptEndingSoon, isTrue);
      expect(
        _summary(pt: _pt(10, end: DateTime(2026, 10, 20))).ptEndingSoon,
        isTrue,
      );
      expect(
        _summary(pt: _pt(10, end: DateTime(2026, 12, 1))).ptEndingSoon,
        isFalse,
      );
      expect(_summary(pt: _pt(0)).ptEndingSoon, isFalse);
      expect(_summary().ptEndingSoon, isFalse);
    });

    test('확인 필요 = 피드백할 식단 또는 가입 7일 안, 그 회원이 위로', () {
      final a = _summary(name: '가나', pending: 0);
      final b = _summary(name: '하늘', pending: 2);
      final c = _summary(name: '다라', createdAt: DateTime(2026, 10, 10));
      expect(c.isNew, isTrue);
      expect(TrainerMemberFilter.attention.matches(a), isFalse);
      final sorted = TrainerMembersService.sorted([a, b, c]);
      expect(sorted.map((s) => s.member.name), ['다라', '하늘', '가나']);
    });

    test('목표 없음 알약', () {
      expect(
        TrainerMemberFilter.noPlan.matches(_summary(hasPlan: false)),
        isTrue,
      );
      expect(TrainerMemberFilter.noPlan.matches(_summary()), isFalse);
    });
  });

  testWidgets('회원 줄: 요약 · 피드백할 식단 수 · 누르기', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainerMemberRow(
            summary: _summary(
              pt: _pt(2),
              workouts: [_workout('2026-10-11')],
              hasPlan: false,
              pending: 3,
              createdAt: DateTime(2026, 10, 11),
            ),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('김민지'), findsOneWidget);
    expect(find.text('새 회원'), findsOneWidget);
    expect(find.textContaining('PT 2회 남음'), findsOneWidget);
    expect(find.textContaining('어제 운동'), findsOneWidget);
    expect(find.textContaining('목표 없음'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('김민지'));
    expect(tapped, isTrue);
  });

  group('식단 목표 화면', () {
    Future<void> open(WidgetTester tester, {double? weight = 80}) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: NutritionPlanScreen(
            member: _user('m1', '유저1'),
            trainer: _user('t1', '박코치', role: UserRole.trainer),
            existing: null,
            weight: weight,
          ),
        ),
      );
    }

    testWidgets('새 목표는 유지 추천값으로 시작하고, 감량을 누르면 바로 바뀐다', (tester) async {
      await open(tester);
      expect(find.text('2,400'), findsOneWidget);
      await tester.tap(find.text('감량'));
      await tester.pump();
      expect(find.text('1,900'), findsOneWidget);
      expect(find.textContaining('체중 80kg 기준 추천'), findsOneWidget);
    });

    testWidgets("숫자를 고치면 '직접'으로 바뀐다", (tester) async {
      await open(tester);
      await tester.enterText(find.text('2,400'), '2100');
      await tester.pump();
      expect(find.text('2,100'), findsOneWidget);
      expect(find.textContaining('직접 정한 값이에요'), findsOneWidget);
    });

    testWidgets('체중이 없으면 선택 막대 대신 안내', (tester) async {
      await open(tester, weight: null);
      expect(find.text('감량'), findsNothing);
      expect(find.textContaining('체중을 입력하면 추천해 드려요'), findsOneWidget);
    });
  });
}
