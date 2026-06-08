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
  int _offlineStrikes = 0; // флипи офлайн танҳо баъди 2 хатои пай дар пай

  void init() {
    _sub = Connectivity().onConnectivityChanged.listen((results) async {
      if (results.contains(ConnectivityResult.none)) {
        // Дастгоҳ умуман шабака надорад → дарҳол офлайн
        _offlineStrikes = 2;
        _setOnline(false);
      } else {
        _applyCheck(await _checkInternet());
      }
    });

    // Ҳар 20 сония санҷиш
    _checkTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      _applyCheck(await _checkInternet());
    });

    // Ҳолати ибтидоӣ
    _checkInternet().then(_applyCheck);
  }

  // Дебаунс: танҳо баъди 2 хатои пай дар пай офлайн нишон медиҳем,
  // то бо як timeout-и тасодуфӣ банер начаспад.
  void _applyCheck(bool online) {
    if (online) {
      _offlineStrikes = 0;
      _setOnline(true);
    } else {
      _offlineStrikes++;
      if (_offlineStrikes >= 2) _setOnline(false);
    }
  }

  void _setOnline(bool online) {
    if (isOnlineNotifier.value != online) {
      isOnlineNotifier.value = online;
      debugPrint('[Network] ${online ? "🟢 Online" : "🔴 Offline"}');
    }
  }

  // Онлайн ҳисобида мешавад, агар ягон host ҳал шавад (на танҳо google).
  // Аввал host-и худи backend, баъд DNS-и боэътимоди ҷаҳонӣ.
  Future<bool> _checkInternet() async {
    const hosts = <String>[
      'mahmadmurodov-raonson.hf.space', // backend-и худи барнома
      'cloudflare.com',
      'one.one.one.one', // 1.1.1.1
      'google.com',
    ];
    for (final h in hosts) {
      try {
        final r = await InternetAddress.lookup(h)
            .timeout(const Duration(seconds: 6));
        if (r.isNotEmpty && r[0].rawAddress.isNotEmpty) return true;
      } catch (_) {
        // ин host нашуд — host-и навбатиро месанҷем
      }
    }
    return false;
  }

  void dispose() {
    _sub?.cancel();
    _checkTimer?.cancel();
  }
}
