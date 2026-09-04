// lib/feed_ai/ai_feed_repository.dart
// ════════════════════════════════════════════════════════════════════
//  «Лентаи AI» — қабати API.
//
//  Client ҳеҷ холи рейтинг намефиристад ва ҳеҷ гоҳ намегӯяд, ки чӣ
//  қадар як мавзӯъ бояд боло равад: ӯ танҳо ният мефиристад
//  («монанди ин камтар») ва сервер қарор мегирад.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import '../core/api/api_client.dart';

/// Мавзӯъ бо афзалияти корбар.
class FeedTopic {
  final String slug, nameTj, nameRu, nameEn, source;
  final double score;

  const FeedTopic({
    required this.slug,
    required this.nameTj,
    required this.nameRu,
    required this.nameEn,
    required this.score,
    required this.source,
  });

  factory FeedTopic.fromJson(Map<String, dynamic> j) => FeedTopic(
        slug: (j['slug'] ?? '').toString(),
        nameTj: (j['nameTj'] ?? '').toString(),
        nameRu: (j['nameRu'] ?? '').toString(),
        nameEn: (j['nameEn'] ?? '').toString(),
        score: (j['score'] as num?)?.toDouble() ?? 0,
        source: (j['source'] ?? '').toString(),
      );

  /// Ном барои забони ҷорӣ.
  String name(String lang) {
    switch (lang) {
      case 'ru':
        return nameRu.isEmpty ? nameEn : nameRu;
      case 'en':
        return nameEn.isEmpty ? nameTj : nameEn;
      default:
        return nameTj.isEmpty ? nameEn : nameTj;
    }
  }

  /// Оё корбар инро худаш интихоб кардааст?
  bool get isExplicit => source == 'explicit';
}

/// Профили тавсияи корбар.
class FeedPrefs {
  final List<String> languages;
  final bool preferLocal, preferOriginal, preferFollowing, fewerRecs;
  final List<FeedTopic> topics;

  const FeedPrefs({
    required this.languages,
    required this.preferLocal,
    required this.preferOriginal,
    required this.preferFollowing,
    required this.fewerRecs,
    required this.topics,
  });

  factory FeedPrefs.fromJson(Map<String, dynamic> j) => FeedPrefs(
        languages: ((j['languages'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        preferLocal: j['preferLocal'] == true,
        preferOriginal: j['preferOriginal'] == true,
        preferFollowing: j['preferFollowing'] == true,
        fewerRecs: j['fewerRecommendations'] == true,
        topics: ((j['topics'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => FeedTopic.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

  static const empty = FeedPrefs(
    languages: [],
    preferLocal: false,
    preferOriginal: false,
    preferFollowing: false,
    fewerRecs: false,
    topics: [],
  );
}

/// Як сабаби «Чаро инро мебинам?».
class FeedReason {
  final String code;
  final Map<String, dynamic> params;
  const FeedReason({required this.code, required this.params});

  factory FeedReason.fromJson(Map<String, dynamic> j) => FeedReason(
        code: (j['code'] ?? '').toString(),
        params: ((j['params'] as Map?) ?? const {}).cast<String, dynamic>(),
      );
}

/// Шарҳи пурра.
class FeedExplanation {
  final List<FeedReason> reasons;
  final bool personalized;
  const FeedExplanation({required this.reasons, required this.personalized});

  factory FeedExplanation.fromJson(Map<String, dynamic> j) => FeedExplanation(
        reasons: ((j['reasons'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => FeedReason.fromJson(e.cast<String, dynamic>()))
            .toList(),
        personalized: j['personalized'] == true,
      );
}

/// Эҷодкори пешниҳодшуда.
class SuggestedPerson {
  final String userId, username, avatar, bio;
  final bool verified;
  final int followers, similarity;
  final List<String> sharedTopics;

  const SuggestedPerson({
    required this.userId,
    required this.username,
    required this.avatar,
    required this.bio,
    required this.verified,
    required this.followers,
    required this.similarity,
    required this.sharedTopics,
  });

  factory SuggestedPerson.fromJson(Map<String, dynamic> j) => SuggestedPerson(
        userId: (j['userId'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        avatar: (j['avatar'] ?? '').toString(),
        bio: (j['bio'] ?? '').toString(),
        verified: j['verified'] == true,
        followers: (j['followersCount'] as num?)?.toInt() ?? 0,
        similarity: (j['similarity'] as num?)?.toInt() ?? 0,
        sharedTopics: ((j['sharedTopics'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Хатои сервер бо матни омодаи намоиш.
class AiFeedException implements Exception {
  final String message;
  final int statusCode;
  const AiFeedException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class AiFeedRepository {
  AiFeedRepository._();
  static final AiFeedRepository instance = AiFeedRepository._();

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
    throw AiFeedException((body['message'] ?? '').toString(), code);
  }

  Future<FeedPrefs> preferences() async =>
      FeedPrefs.fromJson(_decode(await _api.get('/feed/preferences')));

  Future<void> savePreferences({
    required List<String> languages,
    required bool preferLocal,
    required bool preferOriginal,
    required bool preferFollowing,
    required bool fewerRecs,
  }) async {
    _decode(await _api.put('/feed/preferences', body: {
      'languages': languages,
      'preferLocal': preferLocal,
      'preferOriginal': preferOriginal,
      'preferFollowing': preferFollowing,
      'fewerRecommendations': fewerRecs,
    }));
  }

  Future<void> setTopicScore(String slug, double score) async {
    _decode(await _api.put('/feed/preferences/topic',
        body: {'topic': slug, 'score': score}));
  }

  Future<void> setCreatorScore(String creatorId, double score) async {
    _decode(await _api.put('/feed/preferences/creator',
        body: {'creatorId': creatorId, 'score': score}));
  }

  /// Ҳодисаи тавсия. Хато ба корбар нишон дода намешавад: агар як
  /// сигнал гум шавад, лента бояд ба кор давом диҳад.
  Future<void> feedback({
    required String event,
    String? contentType,
    String? contentId,
    String? creatorId,
  }) async {
    try {
      await _api.post('/feed/feedback', body: {
        'event': event,
        if (contentType != null) 'contentType': contentType,
        if (contentId != null) 'contentId': contentId,
        if (creatorId != null) 'creatorId': creatorId,
      });
    } catch (_) {
      // Сигнали гумшуда лентаро вайрон намекунад.
    }
  }

  /// Фармони забони табиӣ. 422 маънои «нафаҳмидам»-ро дорад.
  Future<void> applyCommand(String text) async {
    _decode(await _api.post('/feed/preferences/natural-language',
        body: {'text': text}));
  }

  Future<FeedExplanation> explain(String contentType, String contentId) async =>
      FeedExplanation.fromJson(
          _decode(await _api.get('/feed/explanation/$contentType/$contentId')));

  Future<List<SuggestedPerson>> findPeople(String text) async {
    final b = _decode(await _api.post('/feed/find-people', body: {'text': text}));
    return ((b['people'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => SuggestedPerson.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> reset({required bool keepExplicit}) async {
    _decode(await _api.post('/feed/reset', body: {'keepExplicit': keepExplicit}));
  }
}
