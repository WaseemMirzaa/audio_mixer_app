import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Generated from local Firebase config (`google-services.json` + `GoogleService-Info.plist`).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android, iOS, and Web.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyALO8GXwrerH6Ni-3z37IotYo_HGB-6CoM',
    appId: '1:611674831962:android:fdccb85f647e2c43b36c63',
    messagingSenderId: '611674831962',
    projectId: 'soundaxis-7fa76',
    storageBucket: 'soundaxis-7fa76.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBEvFGNCFZJm_I9N8Q8NEHi6ep3VIYtLRQ',
    appId: '1:611674831962:ios:84100d42abdd07dab36c63',
    messagingSenderId: '611674831962',
    projectId: 'soundaxis-7fa76',
    storageBucket: 'soundaxis-7fa76.firebasestorage.app',
    iosBundleId: 'com.codetivelab.soundAxis',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: '611674831962',
    projectId: 'soundaxis-7fa76',
    storageBucket: 'soundaxis-7fa76.firebasestorage.app',
  );
}