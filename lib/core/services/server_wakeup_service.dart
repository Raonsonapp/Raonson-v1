// lib/core/services/server_wakeup_service.dart
// ──────────────────────────────────────────────────────────────
// Render.com free tier: сервер ҳар 15 дақиқа "хобида" мемонад.
// Ин сервис барномаро кушодан пеш серверро бедор мекунад.
// ──────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ServerWakeupService {
  ServerWakeupService._();
  static final instance = ServerWakeupService._();

  static const _serverUrl = 'https://raonson-v1-go.onrender.com';
  static const _healthPath = '/health';
  static const _pingPath = '/ping';

  bool _isAwake = false;
  bool get isAwake => _isAwake;

  /// Серверро бедор кун — background-да
  /// Вақте корбар барномаро кушояд, сервер аллакай тайёр аст
  Future<void> wakeUp() async {
    if (_isAwake) return;
    debugPrint('[ServerWakeup] Pinging server...');

    // Якбора ping кун — timeout кӯтоҳ
    for (final path in [_healthPath, _pingPath, '/']) {
      try {
        final res = await http.get(
          Uri.parse('$_serverUrl$path'),
          headers: {'Connection': 'keep-alive'},
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode < 500) {
          _isAwake = true;
          debugPrint('[ServerWakeup] ✅ Server is awake!');
          return;
        }
      } catch (_) {}
    }

    // Сервер ҳали хобида — дар background бедор кун
    _wakeUpInBackground();
  }

  void _wakeUpInBackground() {
    Future.delayed(const Duration(seconds: 3), () async {
      for (int i = 0; i < 5; i++) {
        try {
          final res = await http.get(
            Uri.parse('$_serverUrl/health'),
          ).timeout(const Duration(seconds: 10));

          if (res.statusCode < 500) {
            _isAwake = true;
            debugPrint('[ServerWakeup] ✅ Server woke up after ${i + 1} tries');
            return;
          }
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 5));
      }
    });
  }

  /// Keep-alive: har 10 daqiqa ping
  void startKeepAlive() {
    Timer.periodic(const Duration(minutes: 10), (_) async {
      try {
        await http.get(
          Uri.parse('$_serverUrl/health'),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    });
  }
}
