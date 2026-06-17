// lib/core/services/vip_service.dart
// Ҳолати VIP — барои тамошои 720p/1080p. Ҳозир парчами маҳаллӣ;
// баъдан ба пардохти воқеӣ васл мешавад.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VipService {
  VipService._();
  static final VipService instance = VipService._();

  final ValueNotifier<bool> isVip = ValueNotifier<bool>(false);

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      isVip.value = p.getBool('is_vip') ?? false;
    } catch (_) {}
  }

  Future<void> setVip(bool v) async {
    isVip.value = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('is_vip', v);
    } catch (_) {}
  }
}
