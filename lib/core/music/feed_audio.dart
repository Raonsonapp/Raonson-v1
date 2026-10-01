import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════
//  Садои лента — як маркази умумӣ.
//
//  Шикояти корбар: «музика бояд вақте пост ба хона (экран) даромад
//  худаш хонад, на ин ки ҳар бор тугмаи play ва stop заниҳ».
//
//  Барои ин ду чиз лозим аст, ва ҳеҷ кадоме набуд:
//
//   1. Пост бидонад, ки ҲОЗИР дар экран аст. (`VisibilityDetector`)
//
//   2. ЯГОН ҷое бидонад, ки кадом пост ҳозир садо дорад — вагарна
//      ҳангоми тез варақ задан ду-се суруд ҳамзамон мехонданд.
//      Маҳз барои ҳамин худкор хондан пештар умуман хомӯш карда
//      шуда буд:
//
//          «Худкор намехонад: даҳ пост дар экран = даҳ суруд
//           якбора.»
//
//      Ин ҳалли масъала набуд — ин канор рафтан аз он буд.
//
//  Ҳоло: ҳар пост ҳангоми намоён шудан садоро «талаб» мекунад.
//  Талаби нав талаби пешинаро бекор мекунад. Пас ҲАМЕША ҳадди аксар
//  ЯК суруд мехонад — маҳз ҳамон тавре ки Instagram мекунад.
//
//  Тугмаи баландгӯяк (мисли Instagram — дар тарафи РОСТИ расм)
//  садоро барои ТАМОМИ лента хомӯш мекунад, на танҳо як пост, ва
//  интихоб нигоҳ дошта мешавад: як бор хомӯш кардед — фардо ҳам
//  хомӯш мемонад.
// ══════════════════════════════════════════════════════════════════

class FeedAudio {
  FeedAudio._();
  static final FeedAudio instance = FeedAudio._();

  static const String _kMutedKey = 'feed_audio_muted';

  /// Садо барои тамоми лента хомӯш аст?
  ///
  /// Мисли Instagram, оғоз ХОМӮШ аст: барнома набояд бидуни иҷозат
  /// дар ҷои ҷамъиятӣ ба садо барояд.
  final ValueNotifier<bool> muted = ValueNotifier<bool>(true);

  /// Кадом пост ҳозир садо дорад. `null` — ҳеҷ кадом.
  final ValueNotifier<String?> owner = ValueNotifier<String?>(null);

  /// Барнома дар пеш аст (на дар замина).
  ///
  /// Бе ин суруд баъди пахши тугмаи Home ҳам мехонд — корбар
  /// телефонро дар ҷайб мегузошт ва садо давом мекард.
  final ValueNotifier<bool> foreground = ValueNotifier<bool>(true);

  bool _loaded = false;
  _Lifecycle? _hook;

  /// Интихоби пешинаи корбарро бармегардонад.
  ///
  /// Хато бартараф мешавад: набудани хотира набояд лентаро шиканад.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _hook = _Lifecycle(this);
    WidgetsBinding.instance.addObserver(_hook!);
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getBool(_kMutedKey);
      if (v != null) muted.value = v;
    } catch (_) {}
  }

  Future<void> toggleMuted() async {
    muted.value = !muted.value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kMutedKey, muted.value);
    } catch (_) {}
  }

  /// Пост садоро талаб мекунад.
  ///
  /// Талаби нав пешинаро бекор мекунад — пас ду суруд ҳеҷ гоҳ
  /// ҳамзамон намехонанд.
  void claim(String postId) {
    if (postId.isEmpty || owner.value == postId) return;
    owner.value = postId;
  }

  /// Пост аз экран рафт.
  ///
  /// Танҳо агар ҲАМОН пост соҳиб бошад: вагарна пости аз экран
  /// рафта садои пости НАВро хомӯш мекард.
  void release(String postId) {
    if (owner.value == postId) owner.value = null;
  }

  bool isOwner(String postId) => owner.value == postId;

  // ── Фокуси садо (audio focus) ─────────────────────────────────
  //
  // Шикоят: стори кушода аст — музикаи пости Home ҳам ҳамроҳи музикаи
  // стори мехонад. Пеш ҳар экран худаш медонист кай хомӯш шавад, ва
  // экранҳои пурра (стори, reel аз Home) ба лента ҳеҷ чиз намегуфтанд.
  //
  // Ҳоло ЯК қоида: садо танҳо ба саҳифаи БОЛОИИ навигатор тааллуқ
  // дорад. [AudioFocusObserver] саҳифаи болоиро (PageRoute — на
  // bottom sheet ё диалог) дар [focusRoute] нигоҳ медорад. Пост ё
  // reel-е, ки дар саҳифаи зерин аст, фокус надорад ва хомӯш мешавад;
  // вақте саҳифаи болоӣ баста шуд, фокус худкор бармегардад.

  /// Саҳифаи болоии навигатори асосӣ. `null` — номаълум (мас. дар тест).
  final ValueNotifier<Route<dynamic>?> focusRoute =
      ValueNotifier<Route<dynamic>?>(null);

  /// Садои виҷете, ки дар [route] аст, ҳозир иҷозат дорад?
  bool hasFocus(Route<dynamic>? route) {
    final top = focusRoute.value;
    return top == null || route == null || identical(top, route);
  }
}

/// Саҳифаи болоиро барои [FeedAudio.focusRoute] пайгирӣ мекунад.
///
/// Танҳо [PageRoute]-ҳо ба ҳисоб мераванд: шарҳҳо (bottom sheet) ва
/// диалогҳо садоро намегиранд — мисли Instagram.
class AudioFocusObserver extends NavigatorObserver {
  AudioFocusObserver({FeedAudio? audio}) : _audio = audio ?? FeedAudio.instance;

  final FeedAudio _audio;
  final List<Route<dynamic>> _pages = [];

  void _sync() {
    final top = _pages.isEmpty ? null : _pages.last;
    if (!identical(_audio.focusRoute.value, top)) {
      _audio.focusRoute.value = top;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _pages.add(route);
      _sync();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pages.remove(route)) _sync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pages.remove(route)) _sync();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _pages.indexOf(oldRoute);
    if (newRoute is PageRoute) {
      if (i >= 0) {
        _pages[i] = newRoute;
      } else {
        _pages.add(newRoute);
      }
    } else if (i >= 0) {
      _pages.removeAt(i);
    }
    _sync();
  }
}

class _Lifecycle extends WidgetsBindingObserver {
  final FeedAudio audio;
  _Lifecycle(this.audio);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    audio.foreground.value = state == AppLifecycleState.resumed;
  }
}
