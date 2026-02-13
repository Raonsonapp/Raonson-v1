import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData dark() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      primaryColor: Colors.white,
    );
  }
}
