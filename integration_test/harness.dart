// Асбобҳои умумии тестҳои эмулятор.
//
// ═══════════════════════════════════════════════════════════════════
//  Чаро ин файл пайдо шуд
//
//  Ҳар се тести эмулятор `FlutterError.onError`-ро иваз мекарданд ва
//  ба handler-и ПЕШТАРА мефиристоданд. Вале он вақт handler-и
//  пештара аллакай на аз они ТЕСТ, балки аз они БАРНОМА буд:
//  `lib/main.dart` онро иваз мекунад, то дар production экрани сурх
//  набарояд.
//
//  Натиҷа: худи тест аз хатоҳо БЕХАБАР мемонд. Баъд аввалин хатои
//  async ба assertion мерасид:
//
//    A test overrode FlutterError.onError but either failed to
//    return it to its original state, or had unexpected additional
//    errors that it could not handle.
//
//  ва тест 20 дақиқа банд мемонд, то ҳадди вақт расад.
//
//  Ҳал: handler-и ХУДИ ТЕСТ ПЕШ аз `app.main()` нигоҳ дошта мешавад
//  ва хатоҳо ба ҲАМОН фиристода мешаванд. Ҳоло тест дар ҷои дақиқи
//  хато меафтад ва stack-и пурра медиҳад — на «20 дақиқа хомӯшӣ».
// ═══════════════════════════════════════════════════════════════════

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raonson/app/app.dart';

/// Ҳамаи хатоҳои дидашуда — барои гузориш.
final List<String> errors = <String>[];

/// Қадамҳои гузашта — то маълум бошад, кадомаш шикаст.
final List<String> steps = <String>[];

FlutterExceptionHandler? _testOnError;
ui.ErrorCallback? _testAsyncOnError;

/// ПЕШ аз `app.main()` даъват мешавад.
///
/// Ин ҷо handler-и худи `flutter_test` нигоҳ дошта мешавад — пеш аз
/// он ки барнома онро иваз кунад.
void beginCapture() {
  errors.clear();
  steps.clear();
  _testOnError = FlutterError.onError;
  _testAsyncOnError = ui.PlatformDispatcher.instance.onError;
}

/// БАЪДИ `app.main()` даъват мешавад.
void installCapture() {
  FlutterError.onError = (FlutterErrorDetails d) {
    errors.add(d.exceptionAsString());
    // Ба handler-и ТЕСТ, на ба handler-и барнома. Бе ин тест аз
    // хато бехабар мемонад ва баъд ба assertion мерасад.
    _testOnError?.call(d);
  };

  ui.PlatformDispatcher.instance.onError = (Object e, StackTrace s) {
    errors.add('$e');
    // Хатои ШАБАКА тестро набояд шиканад: дар эмулятор интернет
    // ноустувор аст. Хатои ҳақиқӣ бошад — ба тест меравад.
    if (isNoise('$e')) return true;
    return _testAsyncOnError?.call(e, s) ?? true;
  };

  addTearDown(() {
    FlutterError.onError = _testOnError;
    ui.PlatformDispatcher.instance.onError = _testAsyncOnError;
  });
}

/// Хатоҳои муҳит, на барнома.
bool isNoise(String e) => const [
      'SocketException', 'ClientException', 'HandshakeException',
      'TimeoutException', 'Connection closed', 'Connection refused',
      'Failed host lookup', 'MissingPluginException', 'channel-error',
      'firebase', 'Firebase', 'google_mobile_ads', 'MobileAds', 'yandex',
      // Видеои ҳақиқӣ дар эмулятори бе GPU метавонад накушояд.
      'VideoError', 'ExoPlaybackException', 'MediaCodec',
    ].any(e.contains);

/// Хатоҳои ВОҚЕИИ барнома.
List<String> get realErrors =>
    errors.where((e) => !isNoise(e)).toList();

/// Баъди ҳар қадам: хато ҷамъ нашуд?
void checkStep(String step) {
  steps.add(step);
  expect(realErrors, isEmpty,
      reason: 'дар қадами «$step» хато партофт:\n'
          '${realErrors.join('\n')}\n'
          'қадамҳои гузашта: ${steps.join(' → ')}');
}

/// Кадрҳоро меронад.
///
/// `pumpAndSettle` кор намекунад: дар барнома аниматсияҳои
/// такроршаванда ҳастанд ва «оромӣ» ҳеҷ гоҳ намеояд.
Future<void> pumpFor(WidgetTester t, [int ms = 800]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> waitFor(WidgetTester t, Finder f,
    {Duration timeout = const Duration(seconds: 25)}) async {
  var spent = Duration.zero;
  const step = Duration(milliseconds: 100);
  while (spent < timeout) {
    await t.pump(step);
    if (f.evaluate().isNotEmpty) return true;
    spent += step;
  }
  return false;
}

/// Бозгашт бе хатари бастани барнома.
///
/// `handlePopRoute()` ҳангоми набудани роҳи бозгашт
/// `SystemNavigator.pop()` мекунад — яъне БАРНОМАРО МЕБАНДАД, ва
/// тест абадан интизори барномаи мурда мемонад.
Future<void> goBack(WidgetTester t) async {
  final nav = appNavigatorKey.currentState;
  if (nav != null && nav.canPop()) nav.pop();
  await pumpFor(t, 900);
}
