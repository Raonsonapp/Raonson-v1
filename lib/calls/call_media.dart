// lib/calls/call_media.dart
// ════════════════════════════════════════════════════════════════════
//  Ҳолатҳои медиаи занг — мустақил аз Agora, то мантиқ бе дастгоҳ
//  санҷида шавад (роҳи садо, сифати шабака, пайвастшавӣ).
// ════════════════════════════════════════════════════════════════════

/// Садо аз куҷо мебарояд.
enum CallAudioRoute { earpiece, speaker, bluetooth, wired, unknown }

/// Ҳолати пайвасти худи мо ба канал.
enum CallNetState { idle, connecting, connected, reconnecting, failed }

/// Ҳолати гирифтани экран дар муҳаррик (Agora startScreenCapture):
///   starting — розигии система (MediaProjection) пурсида шуд;
///   active   — экран гирифта ва фиристода мешавад;
///   failed   — корбар рад кард ё гирифтан оғоз нашуд.
enum ScreenCaptureStatus { idle, starting, active, failed }

/// Сифати шабака аз рӯи шкалаи Agora (QualityType):
/// 0 номаълум, 1 аъло, 2 хуб, 3 миёна, 4 бад, 5 хеле бад, 6 нест.
class NetQuality {
  NetQuality._();

  /// Аз ин сатҳ — «Пайвасти суст».
  static const weakFrom = 4;

  static bool isWeak(int q) => q >= weakFrom && q <= 6;
}

/// Agora `onAudioRoutingChanged(int routing)` → роҳи мо.
///
/// -1 пешфарз, 0 гӯшмонак бо микрофон, 1 гӯшаки телефон, 2 гӯшмонак бе
/// микрофон, 3 баландгӯяк, 4 баландгӯяки берунӣ, 5 Bluetooth (HFP),
/// 6 USB, 12/13 Bluetooth (A2DP ва ғ.).
CallAudioRoute routeFromAgora(int routing) {
  switch (routing) {
    case 0:
    case 2:
    case 6:
      return CallAudioRoute.wired;
    case 1:
      return CallAudioRoute.earpiece;
    case 3:
    case 4:
      return CallAudioRoute.speaker;
    case 5:
    case 10:
    case 12:
    case 13:
      return CallAudioRoute.bluetooth;
    default:
      return CallAudioRoute.unknown;
  }
}

/// Рӯйхати роҳҳои интихобшаванда (барои варақаи «Садо»).
///
/// Гӯшмонаки симдор пайваст бошад, Android садоро ба гӯшаки телефон
/// намегузаронад — «Телефон» он вақт пинҳон. Аз Bluetooth ба телефон
/// гузаштан мумкин аст (Agora setRouteInCommunicationMode). Баландгӯяк
/// ҳамеша ҳаст.
List<CallAudioRoute> availableRoutes({
  required bool bluetooth,
  required bool wired,
  CallAudioRoute current = CallAudioRoute.unknown,
}) {
  final bt = bluetooth || current == CallAudioRoute.bluetooth;
  final w = wired || current == CallAudioRoute.wired;
  return [
    if (!w) CallAudioRoute.earpiece,
    if (bt) CallAudioRoute.bluetooth,
    if (w) CallAudioRoute.wired,
    CallAudioRoute.speaker,
  ];
}

/// Рақами роҳ барои Agora `setRouteInCommunicationMode` (Android).
int agoraRouteOf(CallAudioRoute r) {
  switch (r) {
    case CallAudioRoute.wired:
      return 0;
    case CallAudioRoute.earpiece:
      return 1;
    case CallAudioRoute.speaker:
      return 3;
    case CallAudioRoute.bluetooth:
      return 5;
    case CallAudioRoute.unknown:
      return -1;
  }
}
