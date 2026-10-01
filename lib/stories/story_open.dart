// lib/stories/story_open.dart
// Кушодани сторисҳои як корбар аз ҳар экран (профил, чат…) — мисли
// Instagram: аватари дорои ҳалқа → сторис.
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../core/api/api_client.dart';
import '../models/story_model.dart';
import 'story_seen_sync.dart';

/// Сторисҳои [userId]-ро мекушояд. `false` — сторис нест (ҳалқа ҳам
/// дар ҳамаи экранҳо бардошта мешавад).
Future<bool> openUserStories(BuildContext context, String userId) async {
  if (userId.isEmpty) return false;
  final navigator = Navigator.of(context);
  List<StoryModel> stories = [];
  try {
    final res = await ApiClient.instance
        .get('/stories', query: {'userId': userId})
        .timeout(const Duration(seconds: 6));
    if (res.statusCode >= 400) return false;
    final body = jsonDecode(res.body);
    final List list =
        body is List ? body : (body['stories'] ?? body['data'] ?? []);
    stories = list
        .whereType<Map>()
        .map((e) => StoryModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return false;
  }
  StorySeenSync.instance.primeStories(stories, completeFor: [userId]);
  if (stories.isEmpty) return false;
  await navigator.pushNamed('/story-group-viewer', arguments: {
    'groups': <List<StoryModel>>[stories],
    'initialGroupIndex': 0,
  });
  return true;
}
