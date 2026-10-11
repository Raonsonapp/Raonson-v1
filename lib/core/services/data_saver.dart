// lib/core/services/data_saver.dart
//
// «Сарфаи трафик» (Танзимот → Истифодаи маълумот):
//   Хомӯш — сифат аз рӯи суръат, 2 reel пешакӣ;
//   Фаъол  — ҳамеша сифати пасттарин, танҳо 1 reel пешакӣ, видеоҳои
//            Home дар интернети мобилӣ худ ба худ бозӣ намекунанд;
//   Худкор — ҳамон «Фаъол», вақте интернети мобилӣ суст аст.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../reels/playback/playback_policy.dart';
import 'network_quality.dart';

class DataSaver extends ChangeNotifier {
  DataSaver._() {
    NetworkQuality.changes.addListener(notifyListeners);
  }
  static final DataSaver instance = DataSaver._();

  static const _kMode = 'data_saver_mode';
  DataSaverMode _mode = DataSaverMode.auto;

  DataSaverMode get mode => _mode;

  Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _mode = dataSaverFromString(p.getString(_kMode) ?? 'auto');
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setMode(DataSaverMode m) async {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kMode, m.name);
    } catch (_) {}
  }

  /// Ҳоло амал мекунад? («Худкор» → вобаста ба шабака.)
  bool get active => PlaybackPolicy.dataSaverActive(
      _mode, NetworkQuality.kind, NetworkQuality.kbps);

  /// Видеоҳои Home дар интернети мобилӣ худ ба худ сар намешаванд.
  bool get blockHomeAutoplay => active && NetworkQuality.kind == NetKind.cellular;
}
