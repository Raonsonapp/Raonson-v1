import 'package:firebase_core/firebase_core.dart';

class FirebaseInit {
  static Future<void> init() async {
    await Firebase.initializeApp();
  }
}
