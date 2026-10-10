import 'package:flutter_test/flutter_test.dart';
import 'package:pt_solution_v2/models/feedback.dart' as fb;
import 'package:pt_solution_v2/models/meal.dart';
import 'package:pt_solution_v2/models/user.dart';
import 'package:pt_solution_v2/services/meal_feed_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _me = 'trainer-me';
const _prev = 'trainer-prev';

AppUser _member(String uid, String name) {
  final t = DateTime(2026, 10, 1);
  return AppUser(
    uid: uid,
    email: '$uid@burnfit.kr',
    name: name,
    role: UserRole.member,
    status: UserStatus.approved,
    centerId: 'c1',
    centerName: '버닝짐 강남점',
    trainerId: _me,
    createdAt: t,
    updatedAt: t,
  );
}

Meal _meal(String id, String memberId, String date, DateTime createdAt) => Meal(
  id: id,
  centerId: 'c1',
  memberId: memberId,
  memberName: memberId,
  mealType: MealType.lunch,
  mealDate: date,
  imageUrls: const ['https://example.com/a.jpg'],
  createdAt: createdAt,
  updatedAt: createdAt,
);

fb.Feedback _fb(
  String id,
  String trainerId,
  String? targetId,
  DateTime at, {
  fb.FeedbackTargetType type = fb.FeedbackTargetType.meal,
}) => fb.Feedback(
  id: id,
  centerId: 'c1',
  trainerId: trainerId,
  trainerName: trainerId,
  memberId: 'm1',
  memberName: '김민지',
  targetType: type,
  targetId: targetId,
  content: '좋아요',
  createdAt: at,
  updatedAt: at,
);

void main() {
  final now = DateTime(2026, 10, 10, 18);
  final minji = _member('m1', '김민지');
  final seojun = _member('m2', '이서준');

  group('피드 만들기', () {
    test('식단마다 그 식단을 가리키는 식단 피드백만, 오래된 순으로 붙인다', () {
      final items = MealFeedService.buildItems(
        member: minji,
        meals: [
          _meal('a', 'm1', '2026-10-10', now),
          _meal('b', 'm1', '2026-10-09', now),
        ],
        feedbacks: [
          _fb('f2', _me, 'a', now.add(const Duration(minutes: 5))),
          _fb('f1', _prev, 'a', now),
          _fb('w', _me, 'a', now, type: fb.FeedbackTargetType.workout),
          _fb('g', _me, null, now, type: fb.FeedbackTargetType.general),
        ],
      );
      expect(items.first.feedbacks.map((f) => f.id), ['f1', 'f2']);
      expect(items.last.feedbacks, isEmpty);
    });

    test('날짜 최신순, 같은 날은 올린 시각 최신순', () {
      final items = MealFeedService.sortNewestFirst([
        MealFeedItem(
          meal: _meal('old', 'm1', '2026-10-09', now),
          member: minji,
          feedbacks: const [],
        ),
        MealFeedItem(
          meal: _meal('am', 'm2', '2026-10-10', DateTime(2026, 10, 10, 8)),
          member: seojun,
          feedbacks: const [],
        ),
        MealFeedItem(
          meal: _meal('pm', 'm1', '2026-10-10', DateTime(2026, 10, 10, 13)),
          member: minji,
          feedbacks: const [],
        ),
      ]);
      expect(items.map((i) => i.meal.id), ['pm', 'am', 'old']);
    });
  });

  group('회원 버튼 표시', () {
    final fresh = MealFeedItem(
      meal: _meal(
        'a',
        'm1',
        '2026-10-10',
        now.subtract(const Duration(hours: 1)),
      ),
      member: minji,
      feedbacks: const [],
    );
    final oldNoFeedback = MealFeedItem(
      meal: _meal(
        'b',
        'm1',
        '2026-10-08',
        now.subtract(const Duration(days: 2)),
      ),
      member: minji,
      feedbacks: const [],
    );
    final answered = MealFeedItem(
      meal: _meal(
        'c',
        'm1',
        '2026-10-10',
        now.subtract(const Duration(hours: 2)),
      ),
      member: minji,
      feedbacks: [_fb('f', _me, 'c', now)],
    );
    final onlyPrevTrainer = MealFeedItem(
      meal: _meal(
        'd',
        'm2',
        '2026-10-10',
        now.subtract(const Duration(hours: 3)),
      ),
      member: seojun,
      feedbacks: [_fb('p', _prev, 'd', now)],
    );
    final items = [fresh, oldNoFeedback, answered, onlyPrevTrainer];

    test('피드백할 수는 내가 아직 피드백하지 않은 식단 (이전 담당 피드백은 세지 않음)', () {
      final minjiBadge = MealFeedBadges.forMember(
        items,
        memberId: 'm1',
        trainerId: _me,
        lastSeen: null,
        now: now,
      );
      expect(minjiBadge.todo, 2);
      final seojunBadge = MealFeedBadges.forMember(
        items,
        memberId: 'm2',
        trainerId: _me,
        lastSeen: null,
        now: now,
      );
      expect(seojunBadge.todo, 1);
      expect(MealFeedBadges.pendingCount(items, _me), 3);
    });

    test('본 적이 없으면 하루 사이 올라온 것만 새 식단, 피드백한 것은 새 식단이 아님', () {
      bool isNew(MealFeedItem i, DateTime? seen) =>
          MealFeedBadges.isNew(i, trainerId: _me, lastSeen: seen, now: now);
      expect(isNew(fresh, null), isTrue);
      expect(isNew(oldNoFeedback, null), isFalse);
      expect(isNew(answered, null), isFalse);
      // 마지막으로 본 뒤에 올라온 것만
      expect(isNew(fresh, now.subtract(const Duration(minutes: 30))), isFalse);
      expect(isNew(fresh, now.subtract(const Duration(hours: 2))), isTrue);
    });

    test('회원 버튼을 누른 뒤(본 시각 지금)에는 새 표시가 없다', () {
      final badge = MealFeedBadges.forMember(
        items,
        memberId: 'm1',
        trainerId: _me,
        lastSeen: now,
        now: now,
      );
      expect(badge.fresh, isFalse);
      expect(badge.todo, 2);
    });
  });

  test('본 시각은 트레이너별로 기기에 저장된다', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await MealFeedSeenStore.load(_me), isEmpty);
    await MealFeedSeenStore.markSeen(_me, 'm1', now);
    await MealFeedSeenStore.markSeen(_me, 'm2', now);
    final seen = await MealFeedSeenStore.load(_me);
    expect(seen.keys, containsAll(['m1', 'm2']));
    expect(seen['m1'], now);
    expect(await MealFeedSeenStore.load(_prev), isEmpty);
  });
}
