import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/models/comment_model.dart';
import 'package:raonson/models/notification_model.dart';
import 'package:raonson/models/post_model.dart';
import 'package:raonson/models/reel_model.dart';
import 'package:raonson/models/story_model.dart';
import 'package:raonson/models/user_model.dart';

// Ҷавобҳои ВОҚЕИИ сервери маҳаллӣ (test/fixtures/live/api_dump.json) аз
// моделҳо мегузаранд. Агар сервер майдонро бо навъи дигар фиристад
// (масалан double ба ҷои int ё объект ба ҷои сатр), экран «хатои сурх»
// нишон медиҳад — ин тест онро пеш аз корбар мегирад.
void main() {
  final dump = jsonDecode(
      File('test/fixtures/live/api_dump.json').readAsStringSync()) as Map;
  dynamic body(String k) => (dump[k] as Map)['body'];
  List list(dynamic b, List<String> keys) {
    if (b is List) return b;
    for (final k in keys) {
      if (b is Map && b[k] is List) return b[k] as List;
    }
    return const [];
  }

  test('профил ва корбарон', () {
    for (final k in ['profile_me', 'profile_other']) {
      final b = body(k) as Map<String, dynamic>;
      UserModel.fromJson(b['user'] as Map<String, dynamic>);
      for (final p in list(b, ['posts'])) {
        PostModel.fromJson(p as Map<String, dynamic>);
      }
    }
    for (final k in ['user_other', 'user_me']) {
      UserModel.fromJson(body(k) as Map<String, dynamic>);
    }
    for (final k in ['followers', 'following']) {
      for (final u in list(body(k), ['followers', 'following', 'users'])) {
        UserModel.fromJson(u as Map<String, dynamic>);
      }
    }
  });

  test('постҳо дар ҳамаи экранҳо', () {
    for (final k in ['user_posts', 'tagged', 'feed', 'smart', 'saved']) {
      for (final p in list(body(k), ['posts'])) {
        PostModel.fromJson(p as Map<String, dynamic>);
      }
    }
    for (final p in list(body('explore'), ['posts'])) {
      PostModel.fromJson(p as Map<String, dynamic>);
    }
    PostModel.fromJson(body('post') as Map<String, dynamic>);
  });

  test('reels', () {
    for (final k in ['user_reels', 'reels']) {
      for (final r in list(body(k), ['reels'])) {
        ReelModel.fromJson(r as Map<String, dynamic>);
      }
    }
    for (final r in list(body('explore'), ['reels'])) {
      ReelModel.fromJson(r as Map<String, dynamic>);
    }
    ReelModel.fromJson(body('reel') as Map<String, dynamic>);
  });

  test('сторис, шарҳ, огоҳинома', () {
    for (final s in list(body('stories'), ['stories'])) {
      StoryModel.fromJson(s as Map<String, dynamic>);
    }
    for (final c in list(body('comments'), ['comments'])) {
      CommentModel.fromJson(c as Map<String, dynamic>);
    }
    for (final n in list(body('notifications'), ['notifications', 'items'])) {
      NotificationModel.fromJson(n as Map<String, dynamic>);
    }
  });
}
