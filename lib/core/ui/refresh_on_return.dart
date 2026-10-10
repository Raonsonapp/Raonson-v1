// lib/core/ui/refresh_on_return.dart
//
// «Баргаштан ба экран» = навсозии хомӯш (мисли Instagram).
//
// ⚠️ Чаро лозим шуд: табҳои Home/Reels/Чат/Ҷустуҷӯ/Профил дар `Offstage`
// зинда мемонанд ва `initState` танҳо як бор иҷро мешавад. Профил як бор
// бор мешуд ва то pull-to-refresh-и дастӣ ҳамон рақамҳоро нишон медод
// (тамошо 5), дар ҳоле ки Explore ва ҷустуҷӯ рақами навро медоданд.
//
// Ин mixin [onReturn]-ро даъват мекунад, вақте экран боз намоён мешавад:
//   • саҳифае, ки болои он кушода буд, пӯшида шуд (route pop);
//   • барнома аз паснамо баргашт (resume);
//   • (барои табҳо) экран худаш [notifyShown]-ро ҳангоми иваз шудани таб
//     даъват мекунад.
// Ҳар экран худаш қарор медиҳад, ки чӣ қадар зуд навсозӣ кунад (ниг.
// [FreshnessGate]).
import 'package:flutter/widgets.dart';

import '../local_activity.dart';

/// Ба `MaterialApp.navigatorObservers` илова шудааст (ниг. app.dart).
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

/// Дебоунси навсозӣ: на зудтар аз [minInterval] ва на ду дархост якбора.
class FreshnessGate {
  FreshnessGate({this.minInterval = const Duration(seconds: 15)});

  final Duration minInterval;

  /// Барои тестҳо.
  DateTime Function() clock = DateTime.now;

  /// Амали худи корбар баъди охирин боркунӣ → интизори [minInterval]
  /// нест, танҳо ин қадар (то ду навсозии пайдарпай нашавад).
  static const activityInterval = Duration(seconds: 1);

  DateTime? _last;
  int _epochAt = -1;
  bool _busy = false;

  DateTime? get lastFetch => _last;
  bool get busy => _busy;

  /// Маълумот ҳозир аз шабака омад.
  void markFetched() {
    _last = clock();
    _epochAt = LocalActivity.epoch;
  }

  bool get isStale {
    final l = _last;
    if (l == null) return true;
    final age = clock().difference(l);
    if (age >= minInterval) return true;
    // Корбар баъди боркунӣ чизе кард (лайк, обуна…) → рақамҳо иваз шуданд.
    return _epochAt != LocalActivity.epoch && age >= activityInterval;
  }

  /// [refresh]-ро танҳо агар маълумот куҳна бошад ва дархост дар роҳ
  /// набошад иҷро мекунад. `true` — навсозӣ сар шуд.
  Future<bool> maybeRun(Future<void> Function() refresh,
      {bool force = false}) async {
    if (_busy || (!force && !isStale)) return false;
    _busy = true;
    try {
      await refresh();
    } finally {
      _busy = false;
    }
    return true;
  }
}

mixin RefreshOnReturn<T extends StatefulWidget> on State<T>
    implements RouteAware {
  ModalRoute<dynamic>? _rorRoute;
  AppLifecycleListener? _rorLifecycle;

  /// Экран ҳозир дар пеши корбар аст (масалан таби он фаъол аст).
  bool get isShownForRefresh =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  /// Экран боз намоён шуд — навсозии хомӯш (бо дебоунс).
  void onReturn();

  /// Барои табҳо: таб фаъол шуд.
  void notifyShown() {
    if (isShownForRefresh) onReturn();
  }

  @override
  void initState() {
    super.initState();
    _rorLifecycle = AppLifecycleListener(onResume: notifyShown);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _rorRoute) {
      if (_rorRoute != null) appRouteObserver.unsubscribe(this);
      _rorRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _rorLifecycle?.dispose();
    super.dispose();
  }

  @override
  void didPopNext() => notifyShown();
  @override
  void didPush() {}
  @override
  void didPop() {}
  @override
  void didPushNext() {}
}
