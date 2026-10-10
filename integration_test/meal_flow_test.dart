// 식단 저장 흐름 점검: 회원이 사진을 올려 식단을 저장하고, 담당 트레이너가 식단·사진을 읽는다.
// 앱이 보내는 실제 데이터가 Firestore·Storage 규칙을 통과하는지 에뮬레이터에서 확인한다.
//
// 준비: Firebase 에뮬레이터 실행 + 예시 데이터 (functions/integration/seed_screens.js)
// 실행:
//   flutter drive -d <iOS 시뮬레이터> \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/meal_flow_test.dart \
//     --dart-define=USE_FIREBASE_EMULATOR=true
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pt_solution_v2/main.dart';
import 'package:pt_solution_v2/models/meal.dart';
import 'package:pt_solution_v2/services/meal_service.dart';

const _password = 'password123';

/// 시험용 사진 한 장 (주황 사각형 PNG → 임시 파일)
Future<XFile> _samplePhoto() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 64, 64),
    Paint()..color = const Color(0xFFFF7A33),
  );
  final image = await recorder.endRecording().toImage(64, 64);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('${Directory.systemTemp.path}/meal_flow_sample.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return XFile(file.path);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('회원 식단(사진 필수) 저장 → 담당 트레이너가 읽는다', (tester) async {
    await bootstrapApp(withMessaging: false);
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;

    // ── 회원: 사진 없는 식단은 앱·규칙 모두 막는다 ──
    await auth.signOut();
    final member = await auth.signInWithEmailAndPassword(
      email: 'member@burnfit.test',
      password: _password,
    );
    final memberId = member.user!.uid;
    const centerId = 'center-gangnam';

    await expectLater(
      MealService.saveMeal(
        centerId: centerId,
        memberId: memberId,
        memberName: '이민지',
        mealType: MealType.lunch,
        mealDate: '2026-10-10',
        imageUrls: const [],
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      db.collection('meals').doc('meal-no-photo').set({
        'id': 'meal-no-photo',
        'centerId': centerId,
        'memberId': memberId,
        'memberName': '이민지',
        'trainerId': null,
        'mealType': 'lunch',
        'mealDate': '2026-10-10',
        'mealTime': '12:00',
        'imageUrls': <String>[],
        'description': '사진 없음',
        'calories': null,
        'hasFeedback': false,
        'feedbackId': null,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      }),
      throwsA(
        isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied'),
      ),
    );

    // ── 회원: 사진을 올려 저장 ──
    final urls = await MealService.uploadImages(
      files: [await _samplePhoto()],
      centerId: centerId,
      memberId: memberId,
    );
    expect(urls, hasLength(1));
    final meal = await MealService.saveMeal(
      centerId: centerId,
      memberId: memberId,
      memberName: '이민지',
      mealType: MealType.lunch,
      mealDate: '2026-10-10',
      mealTime: '12:30',
      imageUrls: urls,
      description: '닭가슴살 샐러드',
      calories: 450,
    );

    // ── 담당 트레이너: 식단과 사진을 읽는다 (공유 설정과 관계없이) ──
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: 'trainer@burnfit.test',
      password: _password,
    );
    final meals = await MealService.getMealsByDateRange(
      centerId,
      memberId,
      '2026-10-10',
      '2026-10-10',
    );
    expect(meals.map((m) => m.id), contains(meal.id));
    // 에뮬레이터 주소는 refFromURL이 해석하지 못하므로 '/o/' 뒤 경로로 연다
    // (내려받기 주소의 토큰이 아니라 저장소 규칙으로 읽기 권한을 확인한다).
    final segments = Uri.parse(urls.single).pathSegments;
    final path = segments.sublist(segments.indexOf('o') + 1).join('/');
    final photo = await FirebaseStorage.instance.ref(path).getMetadata();
    expect(photo.contentType, 'image/jpeg');

    await auth.signOut();
  });
}
