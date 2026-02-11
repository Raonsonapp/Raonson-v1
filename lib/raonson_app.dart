import 'package:flutter/material.dart';
import 'core/theme/raonson_theme.dart';
import 'auth/phone_step/phone_screen.dart';

class RaonsonApp extends StatelessWidget {
  const RaonsonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Raonson',
      theme: RaonsonTheme.dark(),
      home: const PhoneScreen(),
    );
  }
}
