// lib/core/services/region_service.dart
// Бахши «Аниме» танҳо дар Тоҷикистон фаъол мешавад. Аз рӯи IP (на забони
// телефон) муайян мекунем, то дуруст бошад. Натиҷа дар session кэш мешавад.
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RegionService {
  RegionService._();
  static final RegionService instance = RegionService._();

  final ValueNotifier<bool> isTajikistan = ValueNotifier<bool>(false);
  bool _checked = false;

  Future<bool> ensure() async {
    if (_checked) return isTajikistan.value;
    _checked = true;
    bool tj = false;
    try {
      // ipapi.co — ройгон, https, танҳо коди кишвар бармегардонад ("TJ").
      final res = await http
          .get(Uri.parse('https://ipapi.co/country/'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        tj = res.body.trim().toUpperCase() == 'TJ';
      }
    } catch (_) {
      // Fallback: коди кишвари дастгоҳ (камтар дақиқ).
      tj = PlatformDispatcher.instance.locale.countryCode == 'TJ';
    }
    isTajikistan.value = tj;
    return tj;
  }
}
