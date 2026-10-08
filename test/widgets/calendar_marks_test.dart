import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/pt_session.dart';
import 'package:pt_solution_v2/models/workout.dart';
import 'package:pt_solution_v2/widgets/calendar_marks.dart';

PtSession _session(String id, DateTime at, PtSessionStatus status) =>
    PtSession.fromMap({
      'id': id,
      'centerId': 'c1',
      'trainerId': 't1',
      'trainerName': '트레이너',
      'memberId': 'm1',
      'memberName': '회원',
      'scheduledAt': Timestamp.fromDate(at),
      'durationMinutes': 50,
      'status': status.name,
      'createdAt': Timestamp.fromDate(at),
      'updatedAt': Timestamp.fromDate(at),
    });

Workout _workout(String id, String date, WorkoutType type) => Workout.fromMap({
  'id': id,
  'centerId': 'c1',
  'memberId': 'm1',
  'memberName': '회원',
  'workoutType': type.name,
  'createdById': type == WorkoutType.pt ? 't1' : 'm1',
  'createdByRole': type == WorkoutType.pt ? 'trainer' : 'member',
  'workoutDate': date,
  'category': 'chest',
  'exercises': [
    {
      'name': '벤치프레스',
      'sets': [
        {'weight': 60, 'reps': 10},
      ],
    },
  ],
  'createdAt': Timestamp.now(),
  'updatedAt': Timestamp.now(),
});

void main() {
  test('세션 상태와 운동 종류에 따라 PT 완료 / PT 예약 / 개인운동을 나눈다', () {
    final marks = buildCalendarMarks(
      sessions: [
        _session('s1', DateTime(2026, 10, 7, 14), PtSessionStatus.completed),
        _session('s2', DateTime(2026, 10, 9, 14), PtSessionStatus.scheduled),
        _session('s3', DateTime(2026, 10, 10, 14), PtSessionStatus.cancelled),
      ],
      workouts: [
        _workout('w1', '2026-10-05', WorkoutType.personal),
        _workout('w2', '2026-10-03', WorkoutType.pt),
      ],
    );

    expect(marks['2026-10-07'], {CalendarMark.ptDone});
    expect(marks['2026-10-09'], {CalendarMark.ptScheduled});
    expect(marks['2026-10-05'], {CalendarMark.personal});
    expect(marks['2026-10-03'], {
      CalendarMark.ptDone,
    }, reason: '세션 없이 PT 운동 기록만 있어도 PT 완료');
    expect(
      marks.containsKey('2026-10-10'),
      isFalse,
      reason: '취소된 세션은 표시하지 않는다',
    );
  });

  test('같은 날 여러 표시가 겹치면 모두 남기고, 읽는 순서는 고정이다', () {
    final marks = buildCalendarMarks(
      sessions: [
        _session('s1', DateTime(2026, 10, 7, 9), PtSessionStatus.completed),
        _session('s2', DateTime(2026, 10, 7, 19), PtSessionStatus.scheduled),
      ],
      workouts: [_workout('w1', '2026-10-07', WorkoutType.personal)],
    );

    final day = marks['2026-10-07']!;
    expect(day, {
      CalendarMark.ptDone,
      CalendarMark.ptScheduled,
      CalendarMark.personal,
    });
    expect(calendarMarksSemantics(day), 'PT 완료, PT 예약, 개인운동');
  });

  test('한 칸에 하나만 그릴 때는 PT 완료 → PT 예약 → 개인운동 순으로 고른다', () {
    expect(primaryCalendarMark(null), isNull);
    expect(primaryCalendarMark({}), isNull);
    expect(
      primaryCalendarMark({CalendarMark.personal, CalendarMark.ptScheduled}),
      CalendarMark.ptScheduled,
      reason: 'PT 예약이 개인운동 점에 가려지면 안 된다',
    );
    expect(
      primaryCalendarMark({
        CalendarMark.personal,
        CalendarMark.ptScheduled,
        CalendarMark.ptDone,
      }),
      CalendarMark.ptDone,
    );
    expect(primaryCalendarMark({CalendarMark.personal}), CalendarMark.personal);
  });
}
