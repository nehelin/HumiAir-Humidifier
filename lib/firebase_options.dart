import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can use the Firebase Console to configure them.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can use the Firebase Console to configure them.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can use the Firebase Console to configure them.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can use the Firebase Console to configure them.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDuc4rnzo9BZFBR35qiNx7GKVu2xROwsmk',
    appId: '1:962698179616:android:1eaa7d53ef9e9539887845',
    messagingSenderId: '962698179616',
    projectId: 'humiair-humidifier',
    storageBucket: 'humiair-humidifier.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAWzJ1-32cDdS8WbBRfvJI83F9Qo29gYEs',
    appId: '1:962698179616:ios:04d4979383455541887845',
    messagingSenderId: '962698179616',
    projectId: 'humiair-humidifier',
    storageBucket: 'humiair-humidifier.firebasestorage.app',
    iosBundleId: 'com.humidifier.HumiAir',
  );
}
