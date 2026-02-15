import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not supported in this project.',
      );
    }
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyXXXXXXXXXXXX',
    appId: '1:402617742376:android:39d326fd63cd5c5f7ff11d',
    messagingSenderId: '402617742376',
    projectId: 'raonson',
    storageBucket: 'raonson.appspot.com',
  );
}
