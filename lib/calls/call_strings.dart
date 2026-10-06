// lib/calls/call_strings.dart
// ════════════════════════════════════════════════════════════════════
//  Матнҳои занг (экрани пурра, огоҳиномаи «аздастрафта», канал).
//
//  Ҷудо аз strings.dart: ин матнҳо дар isolate-и ПАСНАМО низ лозиманд
//  (FCM ва callkit), ки он ҷо AppSettingsState бор нашудааст. Забон аз
//  SharedPreferences хонда мешавад — ҳамон калиде, ки танзимот менависад.
// ════════════════════════════════════════════════════════════════════
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_settings.dart';

class CallStrings {
  CallStrings._();

  static const _table = <String, Map<String, String>>{
    'tj': {
      'voice': 'Занги аудиоӣ',
      'video': 'Занги видеоӣ',
      'calling': 'занг мезанад…',
      'accept': 'Қабул',
      'decline': 'Рад',
      'missed': 'Занги аздастрафта',
      'missedFrom': 'Занги аздастрафта аз {name}',
      'callBack': 'Занг задан',
      'channel': 'Зангҳо',
      'channelDesc': 'Зангҳои воридотӣ ва аздастрафта',
      'unknown': 'Корбар',
      'minimize': 'Хурд кардан',
      'returnToCall': 'Бозгашт ба занг',
      'swap': 'Иваз кардан',
    },
    'ru': {
      'voice': 'Аудиозвонок',
      'video': 'Видеозвонок',
      'calling': 'звонит…',
      'accept': 'Принять',
      'decline': 'Отклонить',
      'missed': 'Пропущенный звонок',
      'missedFrom': 'Пропущенный звонок от {name}',
      'callBack': 'Перезвонить',
      'channel': 'Звонки',
      'channelDesc': 'Входящие и пропущенные звонки',
      'unknown': 'Пользователь',
      'minimize': 'Свернуть',
      'returnToCall': 'Вернуться к звонку',
      'swap': 'Поменять местами',
    },
    'en': {
      'voice': 'Voice call',
      'video': 'Video call',
      'calling': 'is calling…',
      'accept': 'Accept',
      'decline': 'Decline',
      'missed': 'Missed call',
      'missedFrom': 'Missed call from {name}',
      'callBack': 'Call back',
      'channel': 'Calls',
      'channelDesc': 'Incoming and missed calls',
      'unknown': 'User',
      'minimize': 'Minimize',
      'returnToCall': 'Return to call',
      'swap': 'Swap',
    },
  };

  /// Забони ҷорӣ. Дар isolate-и асосӣ — аз танзимот; дар паснамо —
  /// [loadLang] онро аз диск мехонад.
  static String _lang = '';

  static String get lang {
    if (_lang.isNotEmpty) return _lang;
    try {
      return AppSettingsState.instance.lang;
    } catch (_) {
      return 'tj';
    }
  }

  /// Барои isolate-и паснамо: забонро аз ҳамон калиди танзимот мехонад.
  static Future<void> loadLang() async {
    try {
      final p = await SharedPreferences.getInstance();
      _lang = p.getString('setting_lang') ?? '';
    } catch (_) {}
  }

  static String t(String key, [Map<String, String>? params]) {
    final table = _table[lang] ?? _table['tj']!;
    var out = table[key] ?? _table['tj']![key] ?? key;
    params?.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }
}
