// lib/core/services/network_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier(true);
  bool get isOnline => isOnlineNotifier.value;

  StreamSubscription? _sub;
  Timer? _checkTimer;

  void init() {
    // Connectivity stream-ро tinglash
    _sub = Connectivity().onConnectivityChanged.listen((results) async {
      if (results.contains(ConnectivityResult.none)) {
        _setOnline(false);
      } else {
        // Connectivity bor, lekin haqiqiy internet bormi?
        final online = await _checkInternet();
        _setOnline(online);
      }
    });

    // Har 15 soniyada tekshir
    _checkTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final online = await _checkInternet();
      _setOnline(online);
    });

    // Dastlabki holat
    _checkInternet().then(_setOnline);
  }

  void _setOnline(bool online) {
    if (isOnlineNotifier.value != online) {
      isOnlineNotifier.value = online;
      debugPrint('[Network] ${online ? "🟢 Online" : "🔴 Offline"}');
    }
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _sub?.cancel();
    _checkTimer?.cancel();
  }
}
