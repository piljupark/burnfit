// firebase_options.dart
//
// 이 파일은 Firebase CLI를 통해 자동 생성됩니다.
// 아래 명령어를 실행하면 이 파일이 자동으로 채워집니다:
//
//   flutterfire configure
//
// 참고: https://firebase.google.com/docs/flutter/setup

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCjOVEfxJMCY5f6Qc4Hq1MWLsNfOd6m7qc',
    appId: '1:776063753690:web:b70c2ecce181739092b4e3',
    messagingSenderId: '776063753690',
    projectId: 'burnfit-v01',
    authDomain: 'burnfit-v01.firebaseapp.com',
    storageBucket: 'burnfit-v01.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyADtviBozTsZZIJSUEHsDIcq-qNAPUUZUo',
    appId: '1:776063753690:android:2cdd7fa4a0f46bc592b4e3',
    messagingSenderId: '776063753690',
    projectId: 'burnfit-v01',
    storageBucket: 'burnfit-v01.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAYOZOyaKE0lFPy2sWV0Xf-bWSjEhKrUBM',
    appId: '1:776063753690:ios:dd7e5302c4abd2f292b4e3',
    messagingSenderId: '776063753690',
    projectId: 'burnfit-v01',
    storageBucket: 'burnfit-v01.firebasestorage.app',
    iosBundleId: 'com.example.burnfit',
  );
}
