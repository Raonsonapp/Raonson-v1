// lib/creator_studio/creator_studio_repository.dart
// ════════════════════════════════════════════════════════════════════
//  Студияи эҷодкор — қабати API.
//
//  Ҳар рақам аз сервер меояд ва дар client ҳисоб карда НАМЕШАВАД:
//  ҳисоби маҳаллӣ метавонад аз он чи сервер медонад фарқ кунад.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import '../core/api/api_client.dart';

/// Давраи вақт.
enum StudioWindow { today, week, month }

extension StudioWindowX on StudioWindow {
  String get value {
    switch (this) {
      case StudioWindow.today:
        return 'today';
      case StudioWindow.week:
        return '7d';
      case StudioWindow.month:
        return '30d';
    }
  }

  String get labelKey {
    switch (this) {
      case StudioWindow.today:
        return 'cs.today';
      case StudioWindow.week:
        return 'cs.7d';
      case StudioWindow.month:
        return 'cs.30d';
    }
  }
}

// Навъи ғайримунтазир (сатр, рӯйхат, null) барномаро НАМЕПАРТОЯД:
// экрани таҳлил бо рақами нопурра аз экрани афтода беҳтар аст.
int _i(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt() ?? 0;
  return 0;
}

double _d(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

// Рӯйхат аз JSON: навъи ғайримунтазир рӯйхати холӣ мешавад, на крах.
List<dynamic> _list(dynamic v) => v is List ? v : const [];

/// Рақамҳои асосӣ.
class CreatorOverview {
  final int followers, followersGained, posts, reels, views;
  final int likes, comments, saves, shares, profileVisits;
  final double engagementRate;

  const CreatorOverview({
    required this.followers,
    required this.followersGained,
    required this.posts,
    required this.reels,
    required this.views,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
    required this.profileVisits,
    required this.engagementRate,
  });

  factory CreatorOverview.fromJson(Map<String, dynamic> j) => CreatorOverview(
        followers: _i(j, 'followers'),
        followersGained: _i(j, 'followersGained'),
        posts: _i(j, 'posts'),
        reels: _i(j, 'reels'),
        views: _i(j, 'views'),
        likes: _i(j, 'likes'),
        comments: _i(j, 'comments'),
        saves: _i(j, 'saves'),
        shares: _i(j, 'shares'),
        profileVisits: _i(j, 'profileVisits'),
        engagementRate: _d(j, 'engagementRate'),
      );

  static const empty = CreatorOverview(
    followers: 0, followersGained: 0, posts: 0, reels: 0, views: 0,
    likes: 0, comments: 0, saves: 0, shares: 0, profileVisits: 0,
    engagementRate: 0,
  );
}

/// Натиҷаи «Лентаи AI».
class RecommendationStats {
  final int impressions, opens, completions, likes, saves, shares, follows;
  final double completionRate, openRate;

  const RecommendationStats({
    required this.impressions,
    required this.opens,
    required this.completions,
    required this.likes,
    required this.saves,
    required this.shares,
    required this.follows,
    required this.completionRate,
    required this.openRate,
  });

  factory RecommendationStats.fromJson(Map<String, dynamic> j) =>
      RecommendationStats(
        impressions: _i(j, 'impressions'),
        opens: _i(j, 'opens'),
        completions: _i(j, 'completions'),
        likes: _i(j, 'likes'),
        saves: _i(j, 'saves'),
        shares: _i(j, 'shares'),
        follows: _i(j, 'follows'),
        completionRate: _d(j, 'completionRate'),
        openRate: _d(j, 'openRate'),
      );

  /// Оё ягон тавсия буд? Агар не, бахш пинҳон мешавад — сифрҳои
  /// холӣ ба эҷодкор чизе намегӯянд.
  bool get hasData => impressions > 0;

  static const empty = RecommendationStats(
    impressions: 0, opens: 0, completions: 0, likes: 0, saves: 0,
    shares: 0, follows: 0, completionRate: 0, openRate: 0,
  );
}

/// Мӯҳтавои беҳтарин.
class TopContent {
  final String contentType, contentId, caption, thumbnail, topic;
  final int impressions, completions, follows, views;

  const TopContent({
    required this.contentType,
    required this.contentId,
    required this.caption,
    required this.thumbnail,
    required this.topic,
    required this.impressions,
    required this.completions,
    required this.follows,
    required this.views,
  });

  factory TopContent.fromJson(Map<String, dynamic> j) => TopContent(
        contentType: (j['contentType'] ?? '').toString(),
        contentId: (j['contentId'] ?? '').toString(),
        caption: (j['caption'] ?? '').toString(),
        thumbnail: (j['thumbnail'] ?? '').toString(),
        topic: (j['topic'] ?? '').toString(),
        impressions: _i(j, 'impressions'),
        completions: _i(j, 'completions'),
        follows: _i(j, 'follows'),
        views: _i(j, 'views'),
      );
}

/// Натиҷаи як мавзӯъ.
class TopicPerformance {
  final String topic;
  final int contentCount, views, engagement;
  final double perContent;

  const TopicPerformance({
    required this.topic,
    required this.contentCount,
    required this.views,
    required this.engagement,
    required this.perContent,
  });

  factory TopicPerformance.fromJson(Map<String, dynamic> j) => TopicPerformance(
        topic: (j['topic'] ?? '').toString(),
        contentCount: _i(j, 'contentCount'),
        views: _i(j, 'views'),
        engagement: _i(j, 'engagement'),
        perContent: _d(j, 'engagementPerContent'),
      );
}

/// Мушоҳида — рамз + рақамҳои воқеӣ. Матн дар client тарҷума мешавад.
class CreatorInsight {
  final String code;
  final Map<String, dynamic> params;
  const CreatorInsight({required this.code, required this.params});

  factory CreatorInsight.fromJson(Map<String, dynamic> j) => CreatorInsight(
        code: (j['code'] ?? '').toString(),
        params: ((j['params'] as Map?) ?? const {}).cast<String, dynamic>(),
      );
}

/// Ғояи мӯҳтаво.
class ContentIdea {
  final String title, hook, idea, format, duration, cta;
  final List<String> hashtags;

  const ContentIdea({
    required this.title,
    required this.hook,
    required this.idea,
    required this.format,
    required this.duration,
    required this.cta,
    required this.hashtags,
  });

  factory ContentIdea.fromJson(Map<String, dynamic> j) => ContentIdea(
        title: (j['title'] ?? '').toString(),
        hook: (j['hook'] ?? '').toString(),
        idea: (j['idea'] ?? '').toString(),
        format: (j['format'] ?? '').toString(),
        duration: (j['duration'] ?? '').toString(),
        cta: (j['cta'] ?? '').toString(),
        hashtags: _list(j['hashtags'])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Ҳама чиз барои экрани студия.
class StudioData {
  final CreatorOverview overview;
  final RecommendationStats recommendation;
  final List<TopContent> topContent;
  final List<TopicPerformance> topics;
  final List<CreatorInsight> insights;

  const StudioData({
    required this.overview,
    required this.recommendation,
    required this.topContent,
    required this.topics,
    required this.insights,
  });

  factory StudioData.fromJson(Map<String, dynamic> j) => StudioData(
        overview: CreatorOverview.fromJson(
            (j['overview'] as Map?)?.cast<String, dynamic>() ?? {}),
        recommendation: RecommendationStats.fromJson(
            (j['recommendation'] as Map?)?.cast<String, dynamic>() ?? {}),
        topContent: _list(j['topContent'])
            .whereType<Map>()
            .map((e) => TopContent.fromJson(e.cast<String, dynamic>()))
            .toList(),
        topics: _list(j['topics'])
            .whereType<Map>()
            .map((e) => TopicPerformance.fromJson(e.cast<String, dynamic>()))
            .toList(),
        insights: _list(j['insights'])
            .whereType<Map>()
            .map((e) => CreatorInsight.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}


/// Рақамҳои умрии эҷодкор — асоси нишонҳо ва зина.
class CreatorLifetimeStats {
  final int followers, posts, reels, views, likes, activeWeeks;

  const CreatorLifetimeStats({
    required this.followers,
    required this.posts,
    required this.reels,
    required this.views,
    required this.likes,
    required this.activeWeeks,
  });

  factory CreatorLifetimeStats.fromJson(Map<String, dynamic> j) =>
      CreatorLifetimeStats(
        followers: _i(j, 'followers'),
        posts: _i(j, 'posts'),
        reels: _i(j, 'reels'),
        views: _i(j, 'views'),
        likes: _i(j, 'likes'),
        activeWeeks: _i(j, 'activeWeeks'),
      );

  int get content => posts + reels;

  static const empty = CreatorLifetimeStats(
    followers: 0, posts: 0, reels: 0, views: 0, likes: 0, activeWeeks: 0,
  );
}

/// Шартҳои зинаи оянда.
class LevelTarget {
  final int level, followers, views, content;
  const LevelTarget({
    required this.level,
    required this.followers,
    required this.views,
    required this.content,
  });

  factory LevelTarget.fromJson(Map<String, dynamic> j) => LevelTarget(
        level: _i(j, 'level'),
        followers: _i(j, 'followers'),
        views: _i(j, 'views'),
        content: _i(j, 'content'),
      );
}

/// Зинаи эҷодкор — ҳамеша аз сервер, ҳеҷ гоҳ дар client ҳисоб намешавад.
class CreatorLevel {
  final int level;
  final CreatorLifetimeStats stats;
  /// null дар зинаи охирин.
  final LevelTarget? next;

  const CreatorLevel({
    required this.level,
    required this.stats,
    this.next,
  });

  factory CreatorLevel.fromJson(Map<String, dynamic> j) => CreatorLevel(
        level: _i(j, 'level'),
        stats: CreatorLifetimeStats.fromJson(
            (j['stats'] as Map?)?.cast<String, dynamic>() ?? {}),
        next: (j['next'] is Map)
            ? LevelTarget.fromJson((j['next'] as Map).cast<String, dynamic>())
            : null,
      );

  static const empty =
      CreatorLevel(level: 1, stats: CreatorLifetimeStats.empty);
}

/// Нишони гирифташуда.
class CreatorAchievement {
  final String code, earnedAt;
  final int value;

  const CreatorAchievement({
    required this.code,
    required this.value,
    required this.earnedAt,
  });

  factory CreatorAchievement.fromJson(Map<String, dynamic> j) =>
      CreatorAchievement(
        code: (j['code'] ?? '').toString(),
        value: _i(j, 'value'),
        earnedAt: (j['earnedAt'] ?? '').toString(),
      );
}

/// Нишонҳо + зина дар як ҷавоб.
class CreatorProgress {
  final List<CreatorAchievement> achievements;
  final CreatorLevel level;
  const CreatorProgress({required this.achievements, required this.level});

  factory CreatorProgress.fromJson(Map<String, dynamic> j) => CreatorProgress(
        achievements: _list(j['achievements'])
            .whereType<Map>()
            .map((e) => CreatorAchievement.fromJson(e.cast<String, dynamic>()))
            .toList(),
        level: CreatorLevel.fromJson(
            (j['level'] as Map?)?.cast<String, dynamic>() ?? {}),
      );
}

class StudioException implements Exception {
  final String message;
  final int statusCode;
  const StudioException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class CreatorStudioRepository {
  CreatorStudioRepository._();
  static final CreatorStudioRepository instance = CreatorStudioRepository._();

  final ApiClient _api = ApiClient.instance;

  Map<String, dynamic> _decode(dynamic res) {
    final code = res.statusCode as int;
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body as String) as Map<String, dynamic>;
    } catch (_) {
      body = {};
    }
    if (code >= 200 && code < 300) return body;
    throw StudioException((body['message'] ?? '').toString(), code);
  }

  Future<StudioData> studio(StudioWindow w) async => StudioData.fromJson(
      _decode(await _api.get('/creator/studio', query: {'window': w.value})));

  /// Нишонҳо ва зина. Сервер ҳангоми дархост нишонҳои навро сабт мекунад.
  Future<CreatorProgress> progress() async => CreatorProgress.fromJson(
      _decode(await _api.get('/creator/achievements')));

  /// Ғояҳо. Рӯйхати холӣ хато НЕСТ — AI метавонад ҷавоб надиҳад.
  Future<List<ContentIdea>> ideas({String? topic, String? format}) async {
    final b = _decode(await _api.post('/creator/ideas', body: {
      if (topic != null && topic.isNotEmpty) 'topic': topic,
      if (format != null && format.isNotEmpty) 'format': format,
    }));
    return _list(b['ideas'])
        .whereType<Map>()
        .map((e) => ContentIdea.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
