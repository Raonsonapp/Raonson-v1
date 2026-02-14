import 'package:flutter/material.dart';

class RaonsonApp extends StatelessWidget {
  const RaonsonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SafeHome(),
    );
  }
}

class SafeHome extends StatelessWidget {
  const SafeHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'RAONSON OK',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
