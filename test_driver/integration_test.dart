import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// 화면 투어 스크린샷을 build/screen_tour/에 저장한다.
Future<void> main() {
  return integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('build/screen_tour/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
