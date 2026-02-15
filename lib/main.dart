import 'package:flutter/material.dart';
import 'auth/auth_gate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RaonsonApp());
}

class RaonsonApp extends StatelessWidget {
  const RaonsonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(), // ✅ ҚАДАМИ 5 ДАР ИН ҶО
    );
  }
}
