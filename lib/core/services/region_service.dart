// lib/core/services/region_service.dart
// Бахши «Аниме» танҳо дар Тоҷикистон фаъол мешавад. Аз рӯи IP (на забони
// телефон) муайян мекунем. Натиҷа дар SharedPreferences кэш мешавад, то
// ҳангоми кушодани навбатӣ фавран нишон дода шавад (милт-милт накунад).
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'user_session.dart';

class RegionService {
  RegionService._();
  static final RegionService instance = RegionService._();

  final ValueNotifier<bool> isTajikistan = ValueNotifier<bool>(false);
  bool _checked = false;
  bool _cacheLoaded = false;

  bool get _isOwner =>
      (UserSession.username ?? '').trim().toLowerCase() == 'raonson';

  Future<bool> ensure() async {
    // Соҳиби барнома (@raonson) ҳамеша дастрасӣ дорад.
    if (_isOwner) {
      isTajikistan.value = true;
      return true;
    }

    // Қимати кэшшударо фавран мегузорем (то тугма милт-милт накунад).
    if (!_cacheLoaded) {
      _cacheLoaded = true;
      try {
        final p = await SharedPreferences.getInstance();
        if (p.getBool('region_tj') == true) isTajikistan.value = true;
      } catch (_) {}
    }

    if (_checked) return isTajikistan.value;
    _checked = true;

    bool tj = isTajikistan.value; // аз кэш сар мекунем
    try {
      // ipapi.co — ройгон, https, танҳо коди кишвар бармегардонад ("TJ").
      final res = await http
          .get(Uri.parse('https://ipapi.co/country/'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final code = res.body.trim().toUpperCase();
        if (code == 'TJ') tj = true;
        // Агар ҷавоб омад вале TJ набошад ва кэш true буд — true мемонад
        // (то ҳангоми хатогии лаҳзаии IP тугма нопадид нашавад).
      }
    } catch (_) {
      // Fallback: коди кишвари дастгоҳ (камтар дақиқ).
      if (PlatformDispatcher.instance.locale.countryCode == 'TJ') tj = true;
    }

    isTajikistan.value = tj;
    if (tj) {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setBool('region_tj', true);
      } catch (_) {}
    }
    return tj;
  }
}
