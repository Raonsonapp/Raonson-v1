// lib/core/links/pending_invite.dart
// ════════════════════════════════════════════════════════════════════
//  Коди даъвате, ки аз линк омад ва ҳанӯз истифода нашудааст.
//
//  Одам линкро мекушояд, вале дарҳол бақайд намегирад: аввал экранро
//  мебинад, шояд барномаро мепӯшад. Код бояд то БАҚАЙДГИРӢ интизор
//  шавад, вагарна даъват бе ному нишон гум мешавад.
//
//  Ин ҷо танҳо код нигоҳ дошта мешавад. Мансубият дар СЕРВЕР ҳал
//  мешавад: барнома наметавонад бигӯяд «маро фалонӣ овард».
// ════════════════════════════════════════════════════════════════════
import 'package:shared_preferences/shared_preferences.dart';

class PendingInvite {
  PendingInvite._();

  static const _key = 'pending_invite_code';

  /// Кэши хотира: SharedPreferences асинхронист ва экрани бақайдгирӣ
  /// метавонад пеш аз хондан кушода шавад.
  static String? _cached;

  /// Кодро аз линк нигоҳ медорад.
  static Future<void> save(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return;
    _cached = c;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, c);
    } catch (_) {
      // Диск дастнорас — код ҳадди ақал дар ҳамин сессия мемонад.
    }
  }

  /// Коди интизорро мегирад; холӣ агар набошад.
  static Future<String> read() async {
    if (_cached != null) return _cached!;
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString(_key) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Пас аз бақайдгирӣ код дигар лозим нест.
  ///
  /// Бе ин, коди кӯҳна ба аккаунти дуюми ҳамон телефон мечаспид.
  static Future<void> clear() async {
    _cached = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key);
    } catch (_) {}
  }
}
