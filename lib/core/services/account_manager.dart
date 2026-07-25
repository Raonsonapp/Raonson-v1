// lib/core/services/account_manager.dart
// Multi-account — то 3 аккаунт дар як барнома (мисли Instagram).
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../storage/secure_storage.dart';
import '../api/api_client.dart';
import 'socket_service.dart';
import 'follow_service.dart';
import 'notification_badge_controller.dart';
import 'user_session.dart';
import '../storage/token_storage.dart';
import '../../feed/feed_repository.dart';
import '../../reels/reels_repository.dart';
import '../../stories/story_repository.dart';
import '../../chat/chat_repository.dart';

class StoredAccount {
  final String userId;
  final String username;
  final String avatar;
  final String token;
  final String refreshToken;

  StoredAccount({
    required this.userId,
    required this.username,
    required this.avatar,
    required this.token,
    required this.refreshToken,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'avatar': avatar,
        'token': token,
        'refreshToken': refreshToken,
      };

  factory StoredAccount.fromJson(Map<String, dynamic> j) => StoredAccount(
        userId: (j['userId'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        avatar: (j['avatar'] ?? '').toString(),
        token: (j['token'] ?? '').toString(),
        refreshToken: (j['refreshToken'] ?? '').toString(),
      );

  StoredAccount copyWith({String? username, String? avatar, String? token, String? refreshToken}) =>
      StoredAccount(
        userId: userId,
        username: username ?? this.username,
        avatar: avatar ?? this.avatar,
        token: token ?? this.token,
        refreshToken: refreshToken ?? this.refreshToken,
      );
}

class AccountManager {
  AccountManager._();
  static const _key = 'accounts_v1';
  static const int maxAccounts = 3;

  static final ValueNotifier<List<StoredAccount>> accounts =
      ValueNotifier<List<StoredAccount>>([]);
  static String? activeUserId;

  static bool get canAddMore => accounts.value.length < maxAccounts;

  static Future<void> load() async {
    try {
      final raw = await SecureStorage.read(_key);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => StoredAccount.fromJson(e as Map<String, dynamic>))
          .toList();
      accounts.value = list;
      activeUserId = await TokenStorage.getUserId();
    } catch (_) {}
  }

  static Future<void> _persist() async {
    await SecureStorage.write(
        _key, jsonEncode(accounts.value.map((a) => a.toJson()).toList()));
  }

  /// Аккаунти ҷориро (баъди логин) илова/навсозӣ мекунад ва фаъол мегардонад.
  static Future<void> upsertCurrent({
    required String userId,
    required String username,
    required String avatar,
    required String token,
    required String refreshToken,
  }) async {
    if (userId.isEmpty) return;
    final list = List<StoredAccount>.from(accounts.value);
    final idx = list.indexWhere((a) => a.userId == userId);
    final acc = StoredAccount(
        userId: userId, username: username, avatar: avatar,
        token: token, refreshToken: refreshToken);
    if (idx >= 0) {
      list[idx] = acc;
    } else {
      if (list.length >= maxAccounts) {
        // ҷои аввалинро холӣ мекунем (FIFO)
        list.removeAt(0);
      }
      list.add(acc);
    }
    accounts.value = list;
    activeUserId = userId;
    await _persist();
  }

  /// Гузариш ба аккаунти дигар — токенро иваз ва session-ро нав мекунад.
  static Future<bool> switchTo(String userId) async {
    final acc = accounts.value.firstWhere(
        (a) => a.userId == userId,
        orElse: () => StoredAccount(
            userId: '', username: '', avatar: '', token: '', refreshToken: ''));
    if (acc.userId.isEmpty || acc.token.isEmpty) return false;

    await TokenStorage.saveAccessToken(acc.token);
    if (acc.refreshToken.isNotEmpty) {
      await TokenStorage.saveRefreshToken(acc.refreshToken);
    }
    await TokenStorage.saveUserId(acc.userId);
    ApiClient.instance.setAuthToken(acc.token);
    ApiClient.instance.setRefreshToken(acc.refreshToken);

    // Cache-и клиенти корбари куҳнаро тоза мекунем (in-memory static).
    // Вагарна FeedScreen/ReelsScreen post-и корбари қаблиро нишон медиҳад.
    FeedRepository.clearAllCaches();
    ReelsRepository.clearAllCaches();
    // FollowService override-и обунаҳои корбари куҳнаро дошт — reset.
    FollowService.instance.clear();
    // Бейҷи огоҳиҳо-и корбари куҳнаро тоза мекунем — вагарна корбари нав
    // рақами гумшудаи корбари қаблиро мебинад.
    NotificationBadgeController.instance.reset();
    // Cache-и disk-и story/chat inbox-и корбари куҳнаро тоза мекунем.
    // Best-effort (async, fire-and-forget).
    StoryRepository.clearAllCaches();
    ChatRepository.clearAllCaches();

    // Тартиб муҳим: аввал username/avatar, охирон userId — то BottomNav-и
    // ба userIdNotifier гӯшкунанда аллакай маълумоти комил бинад.
    UserSession.username = acc.username;
    UserSession.avatar   = acc.avatar;
    UserSession.userId   = acc.userId;
    activeUserId = acc.userId;
    // Socket-и корбари куҳнаро мебандем ва бо токени нав пайваст мешавем.
    // Best-effort: агар нашавад, барномаро блок намекунад.
    SocketService.instance.reconnectAs(acc.token);
    return true;
  }

  static Future<void> remove(String userId) async {
    final list = List<StoredAccount>.from(accounts.value)
      ..removeWhere((a) => a.userId == userId);
    accounts.value = list;
    await _persist();
  }
}
