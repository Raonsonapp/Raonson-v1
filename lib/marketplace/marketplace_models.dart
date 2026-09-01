// lib/marketplace/marketplace_models.dart
// ════════════════════════════════════════════════════════════════════
//  Creator Marketplace — моделҳо.
//
//  Пул ҲАМЕША дар воҳиди хурд (диram) меояд ва ҳамчун int нигоҳ дошта
//  мешавад. double барои пул истифода НАМЕШАВАД: 0.1 + 0.2 дар double
//  0.30000000000000004 аст ва дар ҳисоби молиявӣ ин қобили қабул нест.
//  Табдил ба матн танҳо ҳангоми НАМОИШ рух медиҳад.
// ════════════════════════════════════════════════════════════════════

/// Маблағ дар воҳиди хурд.
class Money {
  final int minor;
  final String currency;
  const Money(this.minor, this.currency);

  factory Money.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const Money(0, 'TJS');
    return Money(
      (j['minor'] as num?)?.toInt() ?? 0,
      (j['currency'] ?? 'TJS').toString(),
    );
  }

  /// Матни намоиш: 150000 → "1500.00 TJS", 150000 → "1500 TJS" агар бутун.
  ///
  /// Тақсим ба 100 бо арифметикаи бутун иҷро мешавад — бе double.
  String get label {
    final whole = minor ~/ 100;
    final cents = (minor % 100).abs();
    final amount =
        cents == 0 ? '$whole' : '$whole.${cents.toString().padLeft(2, '0')}';
    return '$amount $currency';
  }

  bool get isZero => minor == 0;
}

/// Кампанияи рекламавӣ (тарафи рекламадиҳанда).
class Campaign {
  final String id;
  final String title;
  final String description;
  final String category;
  final String targetCountry;
  final Money budget;
  final String status;
  final int creatorCount;
  final int commissionBps;
  final DateTime? createdAt;

  const Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetCountry,
    required this.budget,
    required this.status,
    required this.creatorCount,
    required this.commissionBps,
    this.createdAt,
  });

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        targetCountry: (j['targetCountry'] ?? '').toString(),
        budget: Money.fromJson(j['budget'] as Map<String, dynamic>?),
        status: (j['status'] ?? 'DRAFT').toString(),
        creatorCount: (j['creatorCount'] as num?)?.toInt() ?? 1,
        commissionBps: (j['commissionBps'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      );

  /// Комиссия ҳамчун фоиз, барои намоиш.
  String get commissionLabel =>
      '${(commissionBps / 100).toStringAsFixed(commissionBps % 100 == 0 ? 0 : 2)}%';

  bool get needsPayment => status == 'DRAFT' || status == 'PENDING_PAYMENT';
  bool get isPaid => !needsPayment && !isClosed;
  bool get isClosed =>
      status == 'COMPLETED' || status == 'CANCELLED' || status == 'REFUNDED';
}

/// Даъват ба кампания (тарафи эҷодкор ва рекламадиҳанда).
class CampaignOffer {
  final String id;
  final String campaignId;
  final String creatorId;
  final String status;
  final double matchScore;
  final List<String> reasons;
  final Money agreed;

  const CampaignOffer({
    required this.id,
    required this.campaignId,
    required this.creatorId,
    required this.status,
    required this.matchScore,
    required this.reasons,
    required this.agreed,
  });

  factory CampaignOffer.fromJson(Map<String, dynamic> j) => CampaignOffer(
        id: (j['id'] ?? '').toString(),
        campaignId: (j['campaignId'] ?? '').toString(),
        creatorId: (j['creatorId'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        matchScore: (j['matchScore'] as num?)?.toDouble() ?? 0,
        reasons: ((j['reasons'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        agreed: Money.fromJson(j['agreed'] as Map<String, dynamic>?),
      );

  bool get isPending => status == 'INVITED';
  bool get isAccepted => status == 'ACCEPTED';
  bool get needsContent => status == 'ACCEPTED';
}

/// Номзади мувофиқ аз engine-и матчинг.
class CreatorMatch {
  final String creatorId;
  final double matchScore;
  final List<String> reasons;
  final double confidence;

  const CreatorMatch({
    required this.creatorId,
    required this.matchScore,
    required this.reasons,
    required this.confidence,
  });

  factory CreatorMatch.fromJson(Map<String, dynamic> j) => CreatorMatch(
        creatorId: (j['creatorId'] ?? '').toString(),
        matchScore: (j['matchScore'] as num?)?.toDouble() ?? 0,
        reasons: ((j['reasons'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      );
}

/// Профили тиҷоратии эҷодкор.
class CreatorProfile {
  final String creatorId;
  final String audienceCountry;
  final String audienceLanguage;
  final List<String> categories;
  final Money price;
  final bool available;
  final String verificationStatus;

  const CreatorProfile({
    required this.creatorId,
    required this.audienceCountry,
    required this.audienceLanguage,
    required this.categories,
    required this.price,
    required this.available,
    required this.verificationStatus,
  });

  factory CreatorProfile.fromJson(Map<String, dynamic> j) => CreatorProfile(
        creatorId: (j['creatorId'] ?? '').toString(),
        audienceCountry: (j['audienceCountry'] ?? '').toString(),
        audienceLanguage: (j['audienceLanguage'] ?? '').toString(),
        categories: ((j['contentCategories'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        price: Money.fromJson(j['price'] as Map<String, dynamic>?),
        available: j['available'] == true,
        verificationStatus: (j['verificationStatus'] ?? 'NONE').toString(),
      );
}

/// Метрикаи ҳисобшудаи эҷодкор.
///
/// scoreVersion нишон медиҳад, ки хол бо кадом нусхаи алгоритм ҳисоб
/// шудааст — бе он холи кӯҳна ва нав фарқ намекунанд.
class CreatorMetrics {
  final int followers;
  final int totalViews;
  final int averageViews;
  final int likes;
  final int comments;
  final double engagementRate;
  final int contentCount;
  final int campaignCount;
  final int successfulCampaigns;
  final double score;
  final double confidence;
  final int scoreVersion;
  final Map<String, double> breakdown;

  const CreatorMetrics({
    required this.followers,
    required this.totalViews,
    required this.averageViews,
    required this.likes,
    required this.comments,
    required this.engagementRate,
    required this.contentCount,
    required this.campaignCount,
    required this.successfulCampaigns,
    required this.score,
    required this.confidence,
    required this.scoreVersion,
    required this.breakdown,
  });

  factory CreatorMetrics.fromJson(Map<String, dynamic> j) {
    final raw = (j['scoreBreakdown'] as Map?) ?? const {};
    return CreatorMetrics(
      followers: (j['followers'] as num?)?.toInt() ?? 0,
      totalViews: (j['totalViews'] as num?)?.toInt() ?? 0,
      averageViews: (j['averageViews'] as num?)?.toInt() ?? 0,
      likes: (j['likes'] as num?)?.toInt() ?? 0,
      comments: (j['comments'] as num?)?.toInt() ?? 0,
      engagementRate: (j['engagementRate'] as num?)?.toDouble() ?? 0,
      contentCount: (j['contentCount'] as num?)?.toInt() ?? 0,
      campaignCount: (j['campaignCount'] as num?)?.toInt() ?? 0,
      successfulCampaigns:
          (j['successfulCampaignCount'] as num?)?.toInt() ?? 0,
      score: (j['creatorScore'] as num?)?.toDouble() ?? 0,
      confidence: (j['scoreConfidence'] as num?)?.toDouble() ?? 0,
      scoreVersion: (j['scoreVersion'] as num?)?.toInt() ?? 0,
      breakdown: raw.map((k, v) =>
          MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0)),
    );
  }

  /// Холи маълумоти кам боварибахш нест — интерфейс инро нишон медиҳад.
  bool get isReliable => confidence >= 0.5;
}

/// Тавозуни эҷодкор.
class Wallet {
  final Money available;
  final Money pending;
  const Wallet({required this.available, required this.pending});

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        available: Money.fromJson(j['available'] as Map<String, dynamic>?),
        pending: Money.fromJson(j['pending'] as Map<String, dynamic>?),
      );
}

/// Ҷамъбасти даромад.
class Earnings {
  final Wallet wallet;
  final Money paidOut;
  final Money upcoming;
  final int completedCampaigns;

  const Earnings({
    required this.wallet,
    required this.paidOut,
    required this.upcoming,
    required this.completedCampaigns,
  });

  factory Earnings.fromJson(Map<String, dynamic> j) => Earnings(
        wallet: Wallet.fromJson((j['wallet'] as Map<String, dynamic>?) ?? {}),
        paidOut: Money.fromJson(j['paidOut'] as Map<String, dynamic>?),
        upcoming: Money.fromJson(j['upcoming'] as Map<String, dynamic>?),
        completedCampaigns: (j['completedCampaigns'] as num?)?.toInt() ?? 0,
      );
}

/// Як сатри таърихи пардохт.
class PayoutRecord {
  final String id;
  final String campaignId;
  final String campaignTitle;
  final Money amount;
  final String status;
  final String provider;
  final String failureReason;
  final DateTime? createdAt;

  const PayoutRecord({
    required this.id,
    required this.campaignId,
    required this.campaignTitle,
    required this.amount,
    required this.status,
    required this.provider,
    required this.failureReason,
    this.createdAt,
  });

  factory PayoutRecord.fromJson(Map<String, dynamic> j) => PayoutRecord(
        id: (j['id'] ?? '').toString(),
        campaignId: (j['campaignId'] ?? '').toString(),
        campaignTitle: (j['campaignTitle'] ?? '').toString(),
        amount: Money.fromJson(j['amount'] as Map<String, dynamic>?),
        status: (j['status'] ?? '').toString(),
        provider: (j['provider'] ?? '').toString(),
        failureReason: (j['failureReason'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      );

  bool get isDone => status == 'SUCCEEDED';
  bool get isFailed => status == 'FAILED' || status == 'CANCELLED';
}

/// Кампанияе, ки эҷодкор дар он иштирок дорад.
class CreatorCampaign {
  final String campaignId;
  final String title;
  final String campaignStatus;
  final String offerId;
  final String offerStatus;
  final Money agreed;
  final String contentId;

  const CreatorCampaign({
    required this.campaignId,
    required this.title,
    required this.campaignStatus,
    required this.offerId,
    required this.offerStatus,
    required this.agreed,
    required this.contentId,
  });

  factory CreatorCampaign.fromJson(Map<String, dynamic> j) => CreatorCampaign(
        campaignId: (j['campaignId'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        campaignStatus: (j['campaignStatus'] ?? '').toString(),
        offerId: (j['offerId'] ?? '').toString(),
        offerStatus: (j['offerStatus'] ?? '').toString(),
        agreed: Money.fromJson(j['agreed'] as Map<String, dynamic>?),
        contentId: (j['contentId'] ?? '').toString(),
      );

  bool get needsContent => offerStatus == 'ACCEPTED';
}

/// Натиҷаи кампания барои як эҷодкор.
class CampaignMetricsRow {
  final String creatorId;
  final int impressions;
  final int views;
  final int likes;
  final int comments;
  final int saves;

  const CampaignMetricsRow({
    required this.creatorId,
    required this.impressions,
    required this.views,
    required this.likes,
    required this.comments,
    required this.saves,
  });

  factory CampaignMetricsRow.fromJson(Map<String, dynamic> j) =>
      CampaignMetricsRow(
        creatorId: (j['creatorId'] ?? '').toString(),
        impressions: (j['impressions'] as num?)?.toInt() ?? 0,
        views: (j['views'] as num?)?.toInt() ?? 0,
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        comments: (j['comments'] as num?)?.toInt() ?? 0,
        saves: (j['saves'] as num?)?.toInt() ?? 0,
      );
}
