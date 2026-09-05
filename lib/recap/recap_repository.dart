// lib/recap/recap_repository.dart
// ════════════════════════════════════════════════════════════════════
//  Ҷамъбасти ҳафтагӣ — қабати API.
//
//  Ҳар рақам аз сервер меояд. Client ҳеҷ чизро ҳисоб намекунад ва
//  ҳеҷ рақамро «зебо» намекунад: ҷамъбасти бардурӯғ аз ҷамъбасти
//  хоксорона бадтар аст.
//
//  Моделҳои эҷодкор (overview, тавсия, мӯҳтаво, мушоҳида) аз
//  Creator Studio гирифта мешаванд — нусхаи дуюми онҳо сохта
//  намешавад.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import '../core/api/api_client.dart';
import '../creator_studio/creator_studio_repository.dart';

/// Рақам аз JSON.
///
/// Навъи ғайримунтазир (сатр, рӯйхат, null) барномаро НАМЕПАРТОЯД:
/// ҷамъбасти нопурра аз экрани афтода беҳтар аст.
int _i(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt() ?? 0;
  return 0;
}

// Рӯйхат аз JSON: навъи ғайримунтазир рӯйхати холӣ мешавад, на крах.
List<dynamic> _list(dynamic v) => v is List ? v : const [];

/// Номи мавзӯъ бо се забон.
class TopicName {
  final String tj, ru, en;
  const TopicName({this.tj = '', this.ru = '', this.en = ''});

  factory TopicName.fromJson(Map<String, dynamic> j) => TopicName(
        tj: (j['tj'] ?? '').toString(),
        ru: (j['ru'] ?? '').toString(),
        en: (j['en'] ?? '').toString(),
      );

  /// Ном барои забони ҷорӣ; агар набошад, ба забони дигар мегузарад.
  String label(String lang) {
    switch (lang) {
      case 'ru':
        return ru.isNotEmpty ? ru : (en.isNotEmpty ? en : tj);
      case 'en':
        return en.isNotEmpty ? en : (tj.isNotEmpty ? tj : ru);
      default:
        return tj.isNotEmpty ? tj : (ru.isNotEmpty ? ru : en);
    }
  }
}

/// «Ҳафтаи шумо дар Raonson» — барои бинанда.
class ViewerRecap {
  final String weekStart;
  final bool hasEnoughData;
  final int reelsWatched, postsViewed, creatorsDiscovered;
  final int followed, liked, saved, shared;
  final String topTopic;
  final TopicName? topTopicName;

  const ViewerRecap({
    required this.weekStart,
    required this.hasEnoughData,
    required this.reelsWatched,
    required this.postsViewed,
    required this.creatorsDiscovered,
    required this.followed,
    required this.liked,
    required this.saved,
    required this.shared,
    required this.topTopic,
    this.topTopicName,
  });

  factory ViewerRecap.fromJson(Map<String, dynamic> j) => ViewerRecap(
        weekStart: (j['weekStart'] ?? '').toString(),
        hasEnoughData: j['hasEnoughData'] == true,
        reelsWatched: _i(j, 'reelsWatched'),
        postsViewed: _i(j, 'postsViewed'),
        creatorsDiscovered: _i(j, 'creatorsDiscovered'),
        followed: _i(j, 'followed'),
        liked: _i(j, 'liked'),
        saved: _i(j, 'saved'),
        shared: _i(j, 'shared'),
        topTopic: (j['topTopic'] ?? '').toString(),
        topTopicName: (j['topTopicName'] is Map)
            ? TopicName.fromJson(
                (j['topTopicName'] as Map).cast<String, dynamic>())
            : null,
      );

  /// Номи мавзӯъ барои нишон додан; агар тарҷума набошад, slug.
  String topicLabel(String lang) {
    final n = topTopicName?.label(lang) ?? '';
    return n.isNotEmpty ? n : topTopic;
  }
}

/// «Ҳафтаи эҷодкории шумо».
class CreatorRecap {
  final String weekStart;
  final bool hasEnoughData;
  final CreatorOverview overview;
  final RecommendationStats recommendation;
  final List<TopContent> topContent;
  final String topTopic;
  final TopicName? topTopicName;
  final List<CreatorInsight> insights;

  const CreatorRecap({
    required this.weekStart,
    required this.hasEnoughData,
    required this.overview,
    required this.recommendation,
    required this.topContent,
    required this.topTopic,
    required this.insights,
    this.topTopicName,
  });

  factory CreatorRecap.fromJson(Map<String, dynamic> j) => CreatorRecap(
        weekStart: (j['weekStart'] ?? '').toString(),
        hasEnoughData: j['hasEnoughData'] == true,
        overview: CreatorOverview.fromJson(
            (j['overview'] as Map?)?.cast<String, dynamic>() ?? {}),
        recommendation: RecommendationStats.fromJson(
            (j['recommendation'] as Map?)?.cast<String, dynamic>() ?? {}),
        topContent: _list(j['topContent'])
            .whereType<Map>()
            .map((e) => TopContent.fromJson(e.cast<String, dynamic>()))
            .toList(),
        topTopic: (j['topTopic'] ?? '').toString(),
        topTopicName: (j['topTopicName'] is Map)
            ? TopicName.fromJson(
                (j['topTopicName'] as Map).cast<String, dynamic>())
            : null,
        insights: _list(j['insights'])
            .whereType<Map>()
            .map((e) => CreatorInsight.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

  String topicLabel(String lang) {
    final n = topTopicName?.label(lang) ?? '';
    return n.isNotEmpty ? n : topTopic;
  }
}

class RecapRepository {
  RecapRepository._();
  static final RecapRepository instance = RecapRepository._();

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

  Map<String, dynamic> _recap(Map<String, dynamic> body) =>
      (body['recap'] as Map?)?.cast<String, dynamic>() ?? {};

  /// Ҷамъбасти бинанда. Пешфарз — ҳафтаи ГУЗАШТАи пурра.
  Future<ViewerRecap> viewer({bool current = false}) async {
    final b = _decode(await _api.get('/recap/week',
        query: current ? {'week': 'current'} : null));
    return ViewerRecap.fromJson(_recap(b));
  }

  /// Ҷамъбасти эҷодкор.
  Future<CreatorRecap> creator({bool current = false}) async {
    final b = _decode(await _api.get('/creator/recap/week',
        query: current ? {'week': 'current'} : null));
    return CreatorRecap.fromJson(_recap(b));
  }
}
