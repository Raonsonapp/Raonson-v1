// lib/core/services/chat_lock_service.dart
// Қулфи PIN барои чат (Pro) — локалӣ (SharedPreferences).
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatLockService {
  ChatLockService._();
  static final ChatLockService instance = ChatLockService._();

  static const _kPin = 'chat_pin';
  String? _pin;
  bool _loaded = false;

  // Дар як сессия як бор кушода мешавад.
  final ValueNotifier<bool> unlocked = ValueNotifier<bool>(false);

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _pin = p.getString(_kPin);
      _loaded = true;
    } catch (_) {}
  }

  bool get hasPin => _pin != null && _pin!.isNotEmpty;
  bool get ready  => _loaded;
  int  get pinLength => _pin?.length ?? 4;

  Future<void> setPin(String? pin) async {
    _pin = (pin == null || pin.isEmpty) ? null : pin;
    unlocked.value = true; // баъди танзим кушода мемонад
    try {
      final p = await SharedPreferences.getInstance();
      if (_pin == null) {
        await p.remove(_kPin);
      } else {
        await p.setString(_kPin, _pin!);
      }
    } catch (_) {}
  }

  bool tryUnlock(String pin) {
    if (_pin == pin) {
      unlocked.value = true;
      return true;
    }
    return false;
  }

  void lock() => unlocked.value = false;
}
