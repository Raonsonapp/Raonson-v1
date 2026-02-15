import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Android-only Firebase init (NO firebase_options.dart)
  await Firebase.initializeApp();

  runApp(const RaonsonApp());
}
