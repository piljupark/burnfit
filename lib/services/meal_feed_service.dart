import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/app_logger.dart';
import '../models/feedback.dart' as fb;
import '../models/meal.dart';
import '../models/user.dart';
import 'firestore_service.dart';
import 'meal_service.dart';

/// 트레이너 식단 피드의 카드 하나: 식단 + 회원 + 그 식단에 달린 피드백(오래된 순).
class MealFeedItem {
  final Meal meal;
  final AppUser member;
  final List<fb.Feedback> feedbacks;

  const MealFeedItem({
    required this.meal,
    required this.member,
    required this.feedbacks,
  });

  bool hasFeedbackFrom(String trainerId) =>
      feedbacks.any((f) => f.trainerId == trainerId);

  MealFeedItem withFeedback(fb.Feedback feedback) => MealFeedItem(
    meal: meal,
    member: member,
    feedbacks: [...feedbacks, feedback],
  );
}

/// 회원 버튼 표시: 피드백할 식단 수와 새로 올라온 식단이 있는지.
typedef MealFeedBadge = ({int todo, bool fresh});

/// 트레이너 식단 피드 (식단 탭 · 회원 상세 식단 탭 공용).
///
/// 담당 회원마다 식단·피드백을 따로 불러와 합친다. 식단에 저장된 trainerId로 한 번에 모으면
/// 담당이 바뀐 뒤 예전 트레이너에게도 보이므로, 지금 담당 회원 목록과 기존 규칙(회원 기준)만 쓴다.
class MealFeedService {
  MealFeedService._();

  /// 한 번에 불러오는 기간 (식단 탭 '이전 7일 더 보기').
  static const int pageDays = 7;

  /// 회원 한 명의 최근 피드백을 몇 개까지 읽어 식단과 맞출지.
  static const int _feedbackLimit = 300;

  static final _dateKey = DateFormat('yyyy-MM-dd');

  /// [from]~[to] (날짜 포함) 사이 담당 회원들의 식단. 최신순.
  /// 한 회원을 읽지 못해도 나머지는 보여 준다 — 모두 실패하면 예외를 던진다.
  static Future<List<MealFeedItem>> load({
    required List<AppUser> members,
    required DateTime from,
    required DateTime to,
  }) async {
    final start = _dateKey.format(from);
    final end = _dateKey.format(to);
    Object? lastError;
    var failed = 0;
    final perMember = await Future.wait(
      members.map((member) async {
        try {
          final results = await Future.wait([
            MealService.getMealsByDateRange(
              member.centerId,
              member.uid,
              start,
              end,
            ),
            FirestoreService.getFeedbacksForMember(
              member.uid,
              centerId: member.centerId,
              limit: _feedbackLimit,
            ),
          ]);
          return buildItems(
            member: member,
            meals: results[0] as List<Meal>,
            feedbacks: results[1] as List<fb.Feedback>,
          );
        } catch (e) {
          AppLogger.debug('[MealFeed] ${member.uid} 식단 읽기 실패: $e');
          lastError = e;
          failed++;
          return const <MealFeedItem>[];
        }
      }),
    );
    if (members.isNotEmpty && failed == members.length) throw lastError!;
    return sortNewestFirst(perMember.expand((items) => items).toList());
  }

  /// 회원 한 명의 식단에 그 식단을 가리키는 식단 피드백을 붙인다 (피드백은 오래된 순).
  static List<MealFeedItem> buildItems({
    required AppUser member,
    required List<Meal> meals,
    required List<fb.Feedback> feedbacks,
  }) {
    final byMeal = <String, List<fb.Feedback>>{};
    for (final f in feedbacks) {
      final targetId = f.targetId;
      if (f.targetType != fb.FeedbackTargetType.meal || targetId == null) {
        continue;
      }
      byMeal.putIfAbsent(targetId, () => []).add(f);
    }
    return [
      for (final meal in meals)
        MealFeedItem(
          meal: meal,
          member: member,
          feedbacks: (byMeal[meal.id] ?? [])
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        ),
    ];
  }

  /// 날짜 최신순, 같은 날은 올린 시각 최신순.
  static List<MealFeedItem> sortNewestFirst(List<MealFeedItem> items) {
    return items..sort((a, b) {
      final d = b.meal.mealDate.compareTo(a.meal.mealDate);
      if (d != 0) return d;
      return b.meal.createdAt.compareTo(a.meal.createdAt);
    });
  }

  /// 피드백을 하나 더 남긴다 (댓글처럼 쌓인다). 식단에 아직 피드백이 이어져 있지 않으면 잇는다.
  /// 회원에게는 서버(onFeedbackCreated)가 알림을 보낸다.
  static Future<fb.Feedback> sendFeedback({
    required AppUser trainer,
    required MealFeedItem item,
    required String content,
  }) async {
    final now = DateTime.now();
    final feedback = fb.Feedback(
      id: const Uuid().v4(),
      centerId: item.member.centerId,
      trainerId: trainer.uid,
      trainerName: trainer.name,
      memberId: item.member.uid,
      memberName: item.member.name,
      targetType: fb.FeedbackTargetType.meal,
      targetId: item.meal.id,
      targetDate: item.meal.mealDate,
      content: content.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await FirestoreService.createFeedback(feedback);
    if (!item.meal.hasFeedback) {
      await MealService.linkFeedback(item.meal.id, feedback.id);
    }
    return feedback;
  }
}

/// '새 식단' 판단과 회원 버튼 표시 (화면과 떼어 시험한다).
class MealFeedBadges {
  MealFeedBadges._();

  /// 처음 쓸 때(본 기록이 없을 때) 새 식단으로 보는 기간.
  static const Duration firstUseWindow = Duration(hours: 24);

  /// 회원 식단을 마지막으로 본 뒤 올라왔고, 아직 내가 피드백하지 않은 식단.
  static bool isNew(
    MealFeedItem item, {
    required String trainerId,
    required DateTime? lastSeen,
    required DateTime now,
  }) {
    if (item.hasFeedbackFrom(trainerId)) return false;
    final created = item.meal.createdAt;
    if (lastSeen == null) return now.difference(created) < firstUseWindow;
    return created.isAfter(lastSeen);
  }

  static MealFeedBadge forMember(
    List<MealFeedItem> items, {
    required String memberId,
    required String trainerId,
    required DateTime? lastSeen,
    required DateTime now,
  }) {
    var todo = 0;
    var fresh = false;
    for (final item in items) {
      if (item.member.uid != memberId) continue;
      if (!item.hasFeedbackFrom(trainerId)) todo++;
      if (isNew(item, trainerId: trainerId, lastSeen: lastSeen, now: now)) {
        fresh = true;
      }
    }
    return (todo: todo, fresh: fresh);
  }

  /// 내가 아직 피드백하지 않은 식단 수 (아래 탭 점).
  static int pendingCount(List<MealFeedItem> items, String trainerId) =>
      items.where((i) => !i.hasFeedbackFrom(trainerId)).length;
}

/// 트레이너가 회원 식단을 마지막으로 본 시각 (기기에만 저장 — 다른 기기와는 따로).
class MealFeedSeenStore {
  MealFeedSeenStore._();

  static String _key(String trainerId) => 'meal_feed_seen_$trainerId';

  static Future<Map<String, DateTime>> load(String trainerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(trainerId));
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, DateTime>{};
      decoded.forEach((k, v) {
        final at = v is String ? DateTime.tryParse(v) : null;
        if (k is String && at != null) result[k] = at;
      });
      return result;
    } catch (e) {
      AppLogger.debug('[MealFeedSeen] 읽기 실패: $e');
      return {};
    }
  }

  static Future<void> markSeen(
    String trainerId,
    String memberId,
    DateTime at,
  ) async {
    try {
      final current = await load(trainerId);
      current[memberId] = at;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(trainerId),
        jsonEncode(current.map((k, v) => MapEntry(k, v.toIso8601String()))),
      );
    } catch (e) {
      AppLogger.debug('[MealFeedSeen] 저장 실패: $e');
    }
  }
}
