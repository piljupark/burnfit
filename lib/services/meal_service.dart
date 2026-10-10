import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import '../core/app_logger.dart';
import '../core/constants.dart';
import '../core/service_validator.dart';
import '../models/meal.dart';
import 'auth_service.dart';

class MealService {
  MealService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  static Future<File> compressImage(File file) async {
    final targetPath = '${file.path}_compressed.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: AppConstants.imageQuality,
      minWidth: AppConstants.imageMaxWidth,
      minHeight: AppConstants.imageMaxHeight,
      keepExif: false,
    );
    return result != null ? File(result.path) : file;
  }

  static Future<List<String>> uploadImages({
    required List<XFile> files,
    required String centerId,
    required String memberId,
  }) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    if (files.isEmpty) throw ArgumentError('사진을 1장 이상 올려 주세요.');
    ServiceValidator.requireImageCount(files.length);

    final urls = <String>[];

    try {
      for (final file in files) {
        urls.add(
          await _uploadOne(file, centerId: centerId, memberId: memberId),
        );
      }
    } catch (_) {
      // 중간에 실패하면 이미 올라간 사진을 지워 저장소에 남지 않게 한다.
      await deleteImages(urls);
      rethrow;
    }
    return urls;
  }

  static Future<String> _uploadOne(
    XFile file, {
    required String centerId,
    required String memberId,
  }) async {
    final length = await file.length();
    ServiceValidator.requireImageLength(length);
    final id = _uuid.v4();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('$centerId/meals/$memberId/${id}_$ts.jpg');

    final metadata = SettableMetadata(contentType: 'image/jpeg');
    AppLogger.debug(
      '[식단 이미지 업로드] authUid=${AuthService.currentUser?.uid}, '
      'centerId=$centerId, memberId=$memberId, bytes=$length, '
      'path=${ref.fullPath}',
    );
    if (kIsWeb) {
      await ref.putData(await file.readAsBytes(), metadata);
    } else {
      final compressed = await compressImage(File(file.path));
      await ServiceValidator.requireImageFile(compressed);
      await ref.putFile(compressed, metadata);
    }
    return ref.getDownloadURL();
  }

  static Future<void> deleteImages(List<String> urls) async {
    for (final url in urls) {
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (e) {
        AppLogger.debug('[MealService] 식단 이미지 삭제 실패: $e');
      }
    }
  }

  static Future<Meal> saveMeal({
    required String centerId,
    required String memberId,
    required String memberName,
    String? trainerId,
    required MealType mealType,
    required String mealDate,
    String? mealTime,
    required List<String> imageUrls,
    String? description,
    int? calories,
  }) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireText(memberName, '회원 이름');
    ServiceValidator.requireDateKey(mealDate, '식단 날짜');
    ServiceValidator.requireOptionalTime(mealTime, '식단 시간');
    ServiceValidator.requireNonNegativeInt(calories ?? 0, '칼로리');
    if (imageUrls.isEmpty) throw ArgumentError('사진을 1장 이상 올려 주세요.');

    final id = _uuid.v4();
    final now = DateTime.now();
    final meal = Meal(
      id: id,
      centerId: centerId,
      memberId: memberId,
      memberName: memberName,
      trainerId: trainerId,
      mealType: mealType,
      mealDate: mealDate,
      mealTime: mealTime,
      imageUrls: imageUrls,
      description: description,
      calories: calories,
      createdAt: now,
      updatedAt: now,
    );
    await _db.collection('meals').doc(id).set(meal.toMap());
    return meal;
  }

  static Future<List<Meal>> getMealsByDate(
    String centerId,
    String memberId,
    String mealDate,
  ) async {
    ServiceValidator.requireText(centerId, '센터 ID');
    ServiceValidator.requireText(memberId, '회원 ID');
    ServiceValidator.requireDateKey(mealDate, '식단 날짜');

    final snap = await _db
        .collection('meals')
        .where('centerId', isEqualTo: centerId)
        .where('memberId', isEqualTo: memberId)
        .where('mealDate', isEqualTo: mealDate)
        .get();

    final meals = _parseMealDocs(snap.docs);
    meals.sort((a, b) => (a.mealTime ?? '').compareTo(b.mealTime ?? ''));
    return meals;
  }

  static Future<List<Meal>> getMealsByDateRange(
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
        .collection('meals')
        .where('centerId', isEqualTo: centerId)
        .where('memberId', isEqualTo: memberId)
        .where('mealDate', isGreaterThanOrEqualTo: startDate)
        .where('mealDate', isLessThanOrEqualTo: endDate)
        .get();

    final meals = _parseMealDocs(snap.docs);
    meals.sort((a, b) {
      final d = b.mealDate.compareTo(a.mealDate);
      if (d != 0) return d;
      return (a.mealTime ?? '').compareTo(b.mealTime ?? '');
    });
    return meals;
  }

  static Future<void> deleteMeal(String mealId, List<String> imageUrls) async {
    ServiceValidator.requireText(mealId, '식단 ID');

    await Future.wait([
      _db.collection('meals').doc(mealId).delete(),
      deleteImages(imageUrls),
    ]);
  }

  static Future<void> linkFeedback(String mealId, String feedbackId) async {
    ServiceValidator.requireText(mealId, '식단 ID');
    ServiceValidator.requireText(feedbackId, '피드백 ID');

    await _db.collection('meals').doc(mealId).update({
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
    ServiceValidator.requireDateKey(startDate, '식단 시작일');
    ServiceValidator.requireDateKey(endDate, '식단 종료일');
    if (startDate.compareTo(endDate) > 0) {
      throw ArgumentError('식단 시작일은 종료일보다 늦을 수 없습니다.');
    }
  }

  static List<Meal> _parseMealDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final meals = <Meal>[];
    for (final doc in docs) {
      try {
        meals.add(Meal.fromMap(doc.data()));
      } catch (e) {
        AppLogger.debug('[MealService] 식단 문서 파싱 실패(${doc.id}): $e');
      }
    }
    return meals;
  }
}
