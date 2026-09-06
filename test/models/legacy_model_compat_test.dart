import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/cardio.dart';
import 'package:pt_solution_v2/models/feedback.dart' as fb;
import 'package:pt_solution_v2/models/meal.dart';
import 'package:pt_solution_v2/models/workout.dart';

void main() {
  group('legacy model compatibility', () {
    test('Meal은 과거 식단 타입 alias와 숫자 칼로리를 읽는다', () {
      final meal = Meal.fromMap({
        'id': 'meal-1',
        'centerId': 'center-1',
        'memberId': 'member-1',
        'memberName': '회원',
        'mealType': '아침',
        'mealDate': '2026-07-20',
        'imageUrls': [' https://example.com/a.jpg ', '', 1],
        'calories': 321.4,
        'createdAt': '2026-07-20T10:00:00',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 7, 20, 10)),
      });

      expect(meal.mealType, MealType.breakfast);
      expect(meal.imageUrls, ['https://example.com/a.jpg']);
      expect(meal.calories, 321);
    });

    test('Feedback은 targetType 누락과 대상 ID 누락을 읽는다', () {
      final feedback = fb.Feedback.fromMap({
        'id': 'feedback-1',
        'centerId': 'center-1',
        'trainerId': 'trainer-1',
        'memberId': 'member-1',
        'content': '좋습니다.',
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 20, 10)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 7, 20, 10)),
      });

      expect(feedback.targetType, fb.FeedbackTargetType.general);
      expect(feedback.targetId, isNull);
    });

    test('Cardio는 과거 타입 alias와 num 값을 읽는다', () {
      final cardio = Cardio.fromMap({
        'id': 'cardio-1',
        'centerId': 'center-1',
        'memberId': 'member-1',
        'memberName': '회원',
        'cardioDate': '2026-07-20',
        'type': '싸이클',
        'durationMinutes': 30.2,
        'intensity': 5.4,
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 20, 10)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 7, 20, 10)),
      });

      expect(cardio.type, CardioType.cycle);
      expect(cardio.durationMinutes, 30);
      expect(cardio.intensity, 5);
    });

    test('Workout은 과거 한글 카테고리를 읽는다', () {
      final now = Timestamp.fromDate(DateTime(2026, 7, 20, 10));
      final workout = Workout.fromMap({
        'id': 'workout-1',
        'centerId': 'center-1',
        'memberId': 'member-1',
        'memberName': '회원',
        'workoutType': 'personal',
        'createdById': 'member-1',
        'createdByRole': 'member',
        'workoutDate': '2026-07-20',
        'category': '하체',
        'exercises': [
          {
            'name': '스쿼트',
            'sets': [
              {'weight': 80, 'reps': 8},
            ],
          },
        ],
        'createdAt': now,
        'updatedAt': now,
      });

      expect(workout.category, WorkoutCategory.lower);
    });
  });
}
