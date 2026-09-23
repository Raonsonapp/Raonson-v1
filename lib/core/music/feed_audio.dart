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
}

class _Lifecycle extends WidgetsBindingObserver {
  final FeedAudio audio;
  _Lifecycle(this.audio);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    audio.foreground.value = state == AppLifecycleState.resumed;
  }
}
