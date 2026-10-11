import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pt_solution_v2/core/app_icons.dart';
import 'package:pt_solution_v2/core/exercise_data.dart';
import 'package:pt_solution_v2/core/exercise_guide_data.dart';
import 'package:pt_solution_v2/models/workout.dart';
import 'package:pt_solution_v2/widgets/exercise_guide_sheet.dart';

const _muscleKeys = {
  'chest', 'shoulders', 'obliques', 'abs', 'abductor', 'biceps', 'calves', //
  'forearm', 'glutes', 'harmstrings', 'lats', 'upper_back', 'quads',
  'trapezius', 'triceps', 'adductors', 'lower_back', 'neck',
};

Workout _workout(String date, List<Exercise> exercises) {
  final at = DateTime(2026, 10, 1);
  return Workout.fromMap({
    'id': 'w-$date',
    'centerId': 'c',
    'memberId': 'm',
    'createdById': 'm',
    'workoutDate': date,
    'category': 'chest',
    'exercises': exercises.map((e) => e.toMap()).toList(),
    'createdAt': Timestamp.fromDate(at),
    'updatedAt': Timestamp.fromDate(at),
  });
}

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  group('설명 자료', () {
    test('기본 운동은 모두 설명이 있고, 근육 이름은 근육 그림의 묶음 이름이다', () {
      for (final name in ExerciseData.getAll()) {
        final guide = ExerciseGuideData.of(name);
        expect(guide, isNotNull, reason: name);
        expect(guide!.primary, isNotEmpty, reason: name);
        expect(
          {...guide.primary, ...guide.secondary}.difference(_muscleKeys),
          isEmpty,
          reason: name,
        );
        expect(guide.steps.length, inInclusiveRange(3, 5), reason: name);
      }
      expect(ExerciseGuideData.guides.length, ExerciseData.getAll().length);
    });
  });

  group('지난 기록 요약', () {
    test('무게 운동: 최고 무게 · 하루 최고 볼륨 · 최근 줄부터', () {
      final history = ExerciseHistory.fromWorkouts('바벨 벤치프레스', [
        _workout('2026-10-07', [
          const Exercise(
            name: '바벨 벤치프레스',
            sets: [
              ExerciseSet(weight: 60, reps: 10),
              ExerciseSet(weight: 70, reps: 5),
            ],
          ),
        ]),
        _workout('2026-10-02', [
          const Exercise(
            name: '바벨 벤치프레스',
            sets: [ExerciseSet(weight: 50, reps: 10)],
          ),
        ]),
      ], isCardio: false);
      expect(history.kind, ExerciseHistoryKind.weighted);
      expect(history.best, ('최고 무게', '70', 'kg'));
      expect(history.bestDay.$2, '950');
      expect(history.rows.first.summary, '2세트 · 70kg × 5');
      expect(history.rows.last.value, '500kg');
    });

    test('맨몸 운동은 횟수로, 버티는 운동은 초로', () {
      final pushups = ExerciseHistory.fromWorkouts('푸시업', [
        _workout('2026-10-07', [
          const Exercise(
            name: '푸시업',
            sets: [
              ExerciseSet(weight: 0, reps: 20),
              ExerciseSet(weight: 0, reps: 15),
            ],
          ),
        ]),
      ], isCardio: false);
      expect(pushups.kind, ExerciseHistoryKind.bodyweight);
      expect(pushups.best, ('최고 횟수', '20', '회'));
      expect(pushups.bestDay.$2, '35');

      final plank = ExerciseHistory.fromWorkouts('플랭크', [
        _workout('2026-10-07', [
          const Exercise(name: '플랭크', sets: [ExerciseSet(weight: 0, reps: 60)]),
        ]),
      ], isCardio: false);
      expect(plank.best, ('최고 시간', '60', '초'));
    });

    test('기록이 없으면 비어 있다', () {
      expect(
        ExerciseHistory.fromWorkouts('스쿼트', const [], isCardio: false).isEmpty,
        isTrue,
      );
    });
  });

  group('시트', () {
    Future<void> open(
      WidgetTester tester, {
      required String name,
      WorkoutCategory category = WorkoutCategory.chest,
      ExerciseGuideSettings Function()? settings,
      int initialTab = 0,
    }) async {
      // 시트 내용이 모두 그려지도록 긴 화면 (폭은 휴대폰)
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showExerciseGuideSheet(
                context,
                name: name,
                category: category,
                history: ExerciseHistory.empty,
                settings: settings,
                initialTab: initialTab,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      // 시트가 올라오는 움직임을 끝까지 (근육 그림은 계속 움직여 settle을 쓰지 않는다)
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('설명 탭: 도구 · 난이도 · 운동 방법 · 출처, 설정 없이 열면 탭이 둘', (tester) async {
      await open(tester, name: '바벨 벤치프레스');
      expect(find.text('바벨'), findsOneWidget);
      expect(find.text('무게 · 횟수'), findsOneWidget);
      expect(find.text('운동 방법'), findsOneWidget);
      expect(find.textContaining('free-exercise-db'), findsOneWidget);
      expect(find.text('설정'), findsNothing);

      // 탭 '기록' (설명 칸에도 '기록'이 있어 첫 번째 = 탭)
      await tester.tap(find.text('기록').first);
      await tester.pump();
      expect(find.text('아직 이 종목 기록이 없어요.'), findsOneWidget);
    });

    testWidgets('직접 추가한 종목은 설명이 없다는 카드', (tester) async {
      await open(tester, name: '우리 센터 특별 운동');
      expect(find.text('직접 추가한 종목이라 설명이 없어요.'), findsOneWidget);
    });

    testWidgets('설정 탭: 휴식 시간 15초씩, 무게 칸 끄면 단위 줄이 사라지고, 빼기는 닫은 뒤 부른다', (
      tester,
    ) async {
      var rest = 90;
      var showWeight = true;
      var removed = false;
      await open(
        tester,
        name: '바벨 벤치프레스',
        initialTab: 2,
        settings: () => ExerciseGuideSettings(
          isCardio: false,
          restSeconds: rest,
          showWeight: showWeight,
          unitLabel: 'kg',
          note: '',
          onRestChanged: (s) => rest = s,
          onToggleWeight: () => showWeight = !showWeight,
          onToggleUnit: () {},
          onNoteChanged: (_) {},
          onRemove: () => removed = true,
        ),
      );
      expect(find.text('90초'), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.add));
      await tester.pump();
      expect(rest, 105);
      expect(find.text('105초'), findsOneWidget);

      expect(find.text('무게 단위'), findsOneWidget);
      await tester.tap(find.text('무게 칸'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(showWeight, isFalse);
      expect(find.text('무게 단위'), findsNothing);

      await tester.tap(find.text('이 종목 빼기'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(removed, isTrue);
      expect(find.text('이 종목 빼기'), findsNothing);
    });
  });
}
