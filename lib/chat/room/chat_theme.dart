// lib/chat/room/chat_theme.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Мавзӯи чат (мисли Instagram) — ранги паёми ман + фони чат.
class ChatTheme {
  final String id, name;
  final Color bubble;        // ранги паёми ман
  final List<Color>? bg;     // фони чат (gradient); null = пешфарз
  const ChatTheme(this.id, this.name, this.bubble, [this.bg]);
}

class ChatThemes {
  static const List<ChatTheme> all = [
    ChatTheme('default', 'Пешфарз', Color(0xFF3797F0)),
    ChatTheme('purple', 'Бунафш', Color(0xFF8A3FFC),
        [Color(0xFF2A1B3D), Color(0xFF0A0A0A)]),
    ChatTheme('sunset', 'Ғуруб', Color(0xFFFF6B6B),
        [Color(0xFF3D1B1B), Color(0xFF0A0A0A)]),
    ChatTheme('ocean', 'Уқёнус', Color(0xFF00B4D8),
        [Color(0xFF0B2A3D), Color(0xFF0A0A0A)]),
    ChatTheme('green', 'Сабз', Color(0xFF2ECC71),
        [Color(0xFF13301F), Color(0xFF0A0A0A)]),
    ChatTheme('pink', 'Гулобӣ', Color(0xFFE84393),
        [Color(0xFF3D1B30), Color(0xFF0A0A0A)]),
    ChatTheme('gold', 'Тиллоӣ', Color(0xFFF1C40F),
        [Color(0xFF3A3212), Color(0xFF0A0A0A)]),
  ];

  static ChatTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);

  static Future<ChatTheme> load(String chatId) async {
    try {
      final p = await SharedPreferences.getInstance();
      return byId(p.getString('chat_theme_$chatId') ?? 'default');
    } catch (_) {
      return all.first;
    }
  }

  static Future<void> save(String chatId, String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('chat_theme_$chatId', id);
    } catch (_) {}
  }
}
