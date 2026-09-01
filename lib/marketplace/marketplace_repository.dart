// lib/marketplace/marketplace_repository.dart
// ════════════════════════════════════════════════════════════════════
//  Creator Marketplace — қабати API.
//
//  Client ҲЕҶ ГОҲ маблағи ниҳоӣ, комиссия ё ҳолати пардохтро намефиристад:
//  ҳамаи он дар сервер ҳисоб мешавад. Ин ҷо танҳо ният фиристода мешавад
//  («ин кампанияро пардохт кун»), на натиҷа.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import '../core/api/api_client.dart';
import 'marketplace_models.dart';

class MarketplaceRepository {
  MarketplaceRepository._();
  static final MarketplaceRepository instance = MarketplaceRepository._();

  final ApiClient _api = ApiClient.instance;

  static const _base = '/marketplace';

  /// Ҷавобро мекушояд ё хатои сервериро бо матни ӯ мепартояд.
  Map<String, dynamic> _decode(dynamic res) {
    final code = res.statusCode as int;
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body as String) as Map<String, dynamic>;
    } catch (_) {
      body = {};
    }
    if (code >= 200 && code < 300) return body;
    // Матни хато аз сервер меояд — он аллакай ба забони корбар аст.
    throw MarketplaceException(
      (body['message'] ?? 'Хатои сервер').toString(),
      code,
    );
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> body, String key) =>
      ((body[key] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

  // ── Эҷодкор ────────────────────────────────────────────────────

  /// Профил + метрика + ҳамён.
  Future<CreatorDashboard> creatorDashboard() async {
    final b = _decode(await _api.get('$_base/creator/me'));
    return CreatorDashboard(
      joined: b['joined'] == true,
      profile: CreatorProfile.fromJson(
          (b['profile'] as Map?)?.cast<String, dynamic>() ?? {}),
      metrics: CreatorMetrics.fromJson(
          (b['metrics'] as Map?)?.cast<String, dynamic>() ?? {}),
      wallet:
          Wallet.fromJson((b['wallet'] as Map?)?.cast<String, dynamic>() ?? {}),
    );
  }

  /// Ба marketplace ҳамроҳ шудан ё профилро навсозӣ кардан.
  Future<CreatorProfile> saveCreatorProfile({
    required String audienceCountry,
    required String audienceLanguage,
    required List<String> categories,
    required int priceMinor,
    required String currency,
    required bool available,
  }) async {
    final b = _decode(await _api.put('$_base/creator/me', body: {
      'audienceCountry': audienceCountry,
      'audienceLanguage': audienceLanguage,
      'contentCategories': categories,
      'priceMinor': priceMinor,
      'currency': currency,
      'available': available,
    }));
    return CreatorProfile.fromJson(b);
  }

  Future<List<CampaignOffer>> myOffers({String? status}) async {
    final res = await _api.get('$_base/offers',
        query: status == null || status.isEmpty ? null : {'status': status});
    return _list(_decode(res), 'offers')
        .map(CampaignOffer.fromJson)
        .toList();
  }

  Future<CampaignOffer> respondToOffer(String offerId,
      {required bool accept}) async {
    final path = accept
        ? '$_base/offers/$offerId/accept'
        : '$_base/offers/$offerId/reject';
    return CampaignOffer.fromJson(_decode(await _api.post(path)));
  }

  /// Мӯҳтавои нашршударо ба кампания мепайвандад.
  ///
  /// Сервер тафтиш мекунад, ки мӯҳтаво воқеан аз они ҳамин эҷодкор аст.
  Future<void> submitContent(String offerId,
      {required String contentId, required String contentType}) async {
    _decode(await _api.post('$_base/offers/$offerId/content', body: {
      'contentId': contentId,
      'contentType': contentType,
    }));
  }

  Future<List<CreatorCampaign>> myCampaigns() async {
    final b = _decode(await _api.get('$_base/creator/campaigns'));
    return _list(b, 'campaigns').map(CreatorCampaign.fromJson).toList();
  }

  Future<Earnings> earnings() async =>
      Earnings.fromJson(_decode(await _api.get('$_base/creator/earnings')));

  Future<List<PayoutRecord>> payouts() async {
    final b = _decode(await _api.get('$_base/creator/payouts'));
    return _list(b, 'payouts').map(PayoutRecord.fromJson).toList();
  }

  // ── Рекламадиҳанда ─────────────────────────────────────────────

  Future<List<Campaign>> campaigns() async {
    final b = _decode(await _api.get('$_base/campaigns'));
    return _list(b, 'campaigns').map(Campaign.fromJson).toList();
  }

  Future<Campaign> createCampaign({
    required String title,
    required String description,
    required String category,
    required String targetCountry,
    required String targetLanguage,
    required int budgetMinor,
    required String currency,
    required int creatorCount,
    String campaignType = 'post',
  }) async {
    final b = _decode(await _api.post('$_base/campaigns', body: {
      'title': title,
      'description': description,
      'category': category,
      'targetCountry': targetCountry,
      'targetLanguage': targetLanguage,
      // Буҷет дар воҳиди хурд меравад; сервер онро дубора тафтиш мекунад.
      'budgetMinor': budgetMinor,
      'currency': currency,
      'creatorCount': creatorCount,
      'campaignType': campaignType,
    }));
    return Campaign.fromJson(b);
  }

  Future<CampaignDetail> campaignDetail(String id) async {
    final b = _decode(await _api.get('$_base/campaigns/$id'));
    return CampaignDetail(
      campaign: Campaign.fromJson(
          (b['campaign'] as Map?)?.cast<String, dynamic>() ?? {}),
      creators: _list(b, 'creators').map(CampaignOffer.fromJson).toList(),
    );
  }

  /// Пардохтро оғоз мекунад.
  ///
  /// Маблағ фиристода НАМЕШАВАД — сервер онро аз худи кампания мегирад.
  Future<PaymentIntent> startPayment(String campaignId) async {
    final b = _decode(await _api.post('$_base/campaigns/$campaignId/checkout',
        body: const {}));
    return PaymentIntent(
      orderId: (b['orderId'] ?? '').toString(),
      status: (b['status'] ?? '').toString(),
      redirectUrl: (b['redirectUrl'] ?? '').toString(),
      provider: (b['provider'] ?? '').toString(),
      amount: Money((b['amountMinor'] as num?)?.toInt() ?? 0,
          (b['currency'] ?? 'TJS').toString()),
    );
  }

  Future<List<CreatorMatch>> candidates(String campaignId) async {
    final b = _decode(await _api.get('$_base/campaigns/$campaignId/candidates'));
    return _list(b, 'candidates').map(CreatorMatch.fromJson).toList();
  }

  /// Матчинги худкор: сервер номзадҳоро интихоб ва даъват мекунад.
  Future<int> autoMatch(String campaignId) async {
    final b = _decode(
        await _api.post('$_base/campaigns/$campaignId/match', body: const {}));
    return _list(b, 'invited').length;
  }

  Future<CampaignOffer> invite(String campaignId, String creatorId) async {
    final b = _decode(await _api.post('$_base/campaigns/$campaignId/invite',
        body: {'creatorId': creatorId}));
    return CampaignOffer.fromJson(b);
  }

  Future<void> approveContent(String offerId) async {
    _decode(await _api.post('$_base/offers/$offerId/approve', body: const {}));
  }

  Future<void> cancelCampaign(String id) async {
    _decode(await _api.post('$_base/campaigns/$id/cancel', body: const {}));
  }

  Future<void> completeCampaign(String id) async {
    _decode(await _api.post('$_base/campaigns/$id/complete', body: const {}));
  }

  Future<CampaignAnalytics> analytics(String campaignId) async {
    final b = _decode(await _api.get('$_base/campaigns/$campaignId/metrics'));
    return CampaignAnalytics(
      perCreator:
          _list(b, 'creators').map(CampaignMetricsRow.fromJson).toList(),
      totals: CampaignMetricsRow.fromJson(
          (b['totals'] as Map?)?.cast<String, dynamic>() ?? {}),
    );
  }
}

/// Хатои сервер бо матни омодаи намоиш.
class MarketplaceException implements Exception {
  final String message;
  final int statusCode;
  const MarketplaceException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class CreatorDashboard {
  final bool joined;
  final CreatorProfile profile;
  final CreatorMetrics metrics;
  final Wallet wallet;
  const CreatorDashboard({
    required this.joined,
    required this.profile,
    required this.metrics,
    required this.wallet,
  });
}

class CampaignDetail {
  final Campaign campaign;
  final List<CampaignOffer> creators;
  const CampaignDetail({required this.campaign, required this.creators});
}

class PaymentIntent {
  final String orderId;
  final String status;
  final String redirectUrl;
  final String provider;
  final Money amount;
  const PaymentIntent({
    required this.orderId,
    required this.status,
    required this.redirectUrl,
    required this.provider,
    required this.amount,
  });
}

class CampaignAnalytics {
  final List<CampaignMetricsRow> perCreator;
  final CampaignMetricsRow totals;
  const CampaignAnalytics({required this.perCreator, required this.totals});
}
