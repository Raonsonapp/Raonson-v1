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
      'connecting': 'Пайваст мешавад…',
      'ringing': 'Занг мезанад…',
      'reconnecting': 'Аз нав пайваст мешавад…',
      'peerReconnecting': 'Ҳамсӯҳбат аз нав пайваст мешавад…',
      'reconnectFailed': 'Пайваст барқарор нашуд — занг қатъ шуд.',
      'weakNetwork': 'Пайвасти суст',
      'videoFallback': 'Интернет суст — танҳо садо',
      'dataSaver': 'Видеоро хомӯш кун барои сарфаи интернет',
      'mute': 'Бесадо',
      'unmute': 'Бо садо',
      'speaker': 'Баландгӯяк',
      'speakerOff': 'Гӯшаки телефон',
      'end': 'Қатъ',
      'audio': 'Садо',
      'routeEarpiece': 'Телефон',
      'routeSpeaker': 'Баландгӯяк',
      'routeBluetooth': 'Bluetooth',
      'routeWired': 'Гӯшмонак',
      'more': 'Бештар',
      'toVideo': 'Ба видео гузаштан',
      'toVoice': 'Ба занги аудиоӣ гузаштан',
      'videoAsk': '{name} мехоҳад ба видео гузарад',
      'videoWaiting': 'Интизори розигии {name}…',
      'videoDeclined': '{name} видеоро рад кард',
      'videoNoReply': '{name} ҷавоб надод',
      'switchedToVoice': 'Занг ба аудио гузашт',
      'noiseSuppression': 'Хомӯш кардани садои атроф (AI)',
      'blur': 'Хира кардани замина',
      'beauty': 'Зебоӣ',
      'notSupported': 'Дар ин дастгоҳ дастрас нест',
      'cameraPaused': 'Камера таваққуф шуд',
      'history': 'Зангҳо',
      'historyEmpty': 'Ҳанӯз занг нест',
      'incoming': 'Воридотӣ',
      'outgoing': 'Содиротӣ',
      'missedShort': 'Аздастрафта',
      'declined': 'Радшуда',
      'cancelled': 'Бекоршуда',
      'noAnswer': 'Ҷавоб надод',
      'message': 'Паём',
      'delete': 'Нест кардан',
      'clearAll': 'Тоза кардани таърих',
      'retry': 'Аз нав',
      'loadFailed': 'Бор нашуд. Интернетро санҷед.',
      'channelOngoing': 'Гуфтугӯи ҷорӣ',
      'cancel': 'Бекор',
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
      'connecting': 'Соединение…',
      'ringing': 'Вызов…',
      'reconnecting': 'Переподключение…',
      'peerReconnecting': 'Собеседник переподключается…',
      'reconnectFailed': 'Связь не восстановилась — звонок завершён.',
      'weakNetwork': 'Слабое соединение',
      'videoFallback': 'Слабый интернет — только звук',
      'dataSaver': 'Отключить видео для экономии трафика',
      'mute': 'Без звука',
      'unmute': 'Включить звук',
      'speaker': 'Динамик',
      'speakerOff': 'Телефон',
      'end': 'Завершить',
      'audio': 'Звук',
      'routeEarpiece': 'Телефон',
      'routeSpeaker': 'Динамик',
      'routeBluetooth': 'Bluetooth',
      'routeWired': 'Наушники',
      'more': 'Ещё',
      'toVideo': 'Перейти на видео',
      'toVoice': 'Перейти на аудиозвонок',
      'videoAsk': '{name} хочет перейти на видео',
      'videoWaiting': 'Ждём согласия {name}…',
      'videoDeclined': '{name} отклонил(а) видео',
      'videoNoReply': '{name} не ответил(а)',
      'switchedToVoice': 'Звонок переведён в аудио',
      'noiseSuppression': 'Шумоподавление (AI)',
      'blur': 'Размытие фона',
      'beauty': 'Красота',
      'notSupported': 'Недоступно на этом устройстве',
      'cameraPaused': 'Камера приостановлена',
      'history': 'Звонки',
      'historyEmpty': 'Звонков пока нет',
      'incoming': 'Входящий',
      'outgoing': 'Исходящий',
      'missedShort': 'Пропущенный',
      'declined': 'Отклонён',
      'cancelled': 'Отменён',
      'noAnswer': 'Нет ответа',
      'message': 'Сообщение',
      'delete': 'Удалить',
      'clearAll': 'Очистить историю',
      'retry': 'Повторить',
      'loadFailed': 'Не загрузилось. Проверьте интернет.',
      'channelOngoing': 'Текущий звонок',
      'cancel': 'Отмена',
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
      'connecting': 'Connecting…',
      'ringing': 'Ringing…',
      'reconnecting': 'Reconnecting…',
      'peerReconnecting': 'The other person is reconnecting…',
      'reconnectFailed': 'Connection lost — call ended.',
      'weakNetwork': 'Weak connection',
      'videoFallback': 'Weak internet — audio only',
      'dataSaver': 'Turn off video to save data',
      'mute': 'Mute',
      'unmute': 'Unmute',
      'speaker': 'Speaker',
      'speakerOff': 'Phone',
      'end': 'End',
      'audio': 'Audio',
      'routeEarpiece': 'Phone',
      'routeSpeaker': 'Speaker',
      'routeBluetooth': 'Bluetooth',
      'routeWired': 'Headphones',
      'more': 'More',
      'toVideo': 'Switch to video',
      'toVoice': 'Switch to voice call',
      'videoAsk': '{name} wants to switch to video',
      'videoWaiting': 'Waiting for {name}…',
      'videoDeclined': '{name} declined video',
      'videoNoReply': "{name} didn't respond",
      'switchedToVoice': 'Switched to voice',
      'noiseSuppression': 'Noise suppression (AI)',
      'blur': 'Blur background',
      'beauty': 'Beauty',
      'notSupported': 'Not available on this device',
      'cameraPaused': 'Camera paused',
      'history': 'Calls',
      'historyEmpty': 'No calls yet',
      'incoming': 'Incoming',
      'outgoing': 'Outgoing',
      'missedShort': 'Missed',
      'declined': 'Declined',
      'cancelled': 'Cancelled',
      'noAnswer': 'No answer',
      'message': 'Message',
      'delete': 'Delete',
      'clearAll': 'Clear history',
      'retry': 'Retry',
      'loadFailed': "Couldn't load. Check your internet.",
      'channelOngoing': 'Ongoing call',
      'cancel': 'Cancel',
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
