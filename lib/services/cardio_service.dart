import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/app_logger.dart';
import '../core/service_validator.dart';
import '../models/cardio.dart';

class CardioService {
  CardioService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  static Future<Cardio> saveCardio({
    required String centerId,
    required String memberId,
    required String memberName,
    String? trainerId,
    required String cardioDate,
    required CardioType type,
    required int durationMinutes,
    double? speed,
    int? intensity,
    String? name,
    String? note,
  }) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireText(memberName, '회원 이름');
    ServiceValidator.requireDateKey(cardioDate, '유산소 날짜');
    ServiceValidator.requirePositiveInt(durationMinutes, '유산소 시간');
    ServiceValidator.requireOptionalPositiveDouble(speed, '속도');
    ServiceValidator.requireOptionalPositiveInt(intensity, '강도');
    if (type == CardioType.other) {
      ServiceValidator.requireText(name ?? '', '유산소 이름');
    }

    final id = _uuid.v4();
    final now = DateTime.now();
    final cardio = Cardio(
      id: id,
      centerId: centerId,
      memberId: memberId,
      memberName: memberName,
      trainerId: trainerId,
      cardioDate: cardioDate,
      type: type,
      durationMinutes: durationMinutes,
      speed: speed,
      intensity: intensity,
      name: name,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await _db.collection('cardios').doc(id).set(cardio.toMap());
    return cardio;
  }

  static Future<List<Cardio>> getCardiosByDateRange(
    String centerId,
    String memberId,
    String startDate,
    String endDate,
  ) async {
    _validateDateRangeQuery(
      centerId: centerId,
      memberId: memberId,
      startDate: startDate,
      endDate: endDate,
    );

    final snap = await _db
        .collection('cardios')
        .where('centerId', isEqualTo: centerId)
        .where('memberId', isEqualTo: memberId)
        .where('cardioDate', isGreaterThanOrEqualTo: startDate)
        .where('cardioDate', isLessThanOrEqualTo: endDate)
        .get();

    final list = _parseCardioDocs(snap.docs);
    list.sort((a, b) => b.cardioDate.compareTo(a.cardioDate));
    return list;
  }

  static Future<List<Cardio>> getCardiosByDate(
    String centerId,
    String memberId,
    String date,
  ) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireDateKey(date, '유산소 날짜');

    final snap = await _db
        .collection('cardios')
        .where('centerId', isEqualTo: centerId)
        .where('memberId', isEqualTo: memberId)
        .where('cardioDate', isEqualTo: date)
        .get();
    final list = _parseCardioDocs(snap.docs);
    list.sort((a, b) => b.cardioDate.compareTo(a.cardioDate));
    return list;
  }

  static Future<void> deleteCardio(String cardioId) async {
    ServiceValidator.requireText(cardioId, '유산소 ID');

    await _db.collection('cardios').doc(cardioId).delete();
  }

  static Future<void> linkFeedback(String cardioId, String feedbackId) async {
    ServiceValidator.requireText(cardioId, '유산소 ID');
    ServiceValidator.requireText(feedbackId, '피드백 ID');

    await _db.collection('cardios').doc(cardioId).update({
      'hasFeedback': true,
      'feedbackId': feedbackId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static void _validateDateRangeQuery({
    required String centerId,
    required String memberId,
    required String startDate,
    required String endDate,
  }) {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireDateKey(startDate, '유산소 시작일');
    ServiceValidator.requireDateKey(endDate, '유산소 종료일');
    if (startDate.compareTo(endDate) > 0) {
      throw ArgumentError('유산소 시작일은 종료일보다 늦을 수 없습니다.');
    }
  }

  static List<Cardio> _parseCardioDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final cardios = <Cardio>[];
    for (final doc in docs) {
      try {
        cardios.add(Cardio.fromMap(doc.data()));
      } catch (e) {
        AppLogger.debug('[CardioService] 유산소 문서 파싱 실패(${doc.id}): $e');
      }
    }
    return cardios;
  }
}
