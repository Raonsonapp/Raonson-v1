// test/marketplace_models_test.dart
// Санҷиши таҷзияи ҷавоби ВОҚЕИИ сервер.
//
// JSON-и ин ҷо аз сервери зинда гирифта шудааст, на дастӣ навишта —
// то тест сохтори воқеиро санҷад, на тахминро.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/marketplace/marketplace_models.dart';

void main() {
  group('Money', () {
    test('маблағ ҳамчун бутун нигоҳ дошта мешавад', () {
      const m = Money(150000, 'TJS');
      expect(m.minor, 150000);
      expect(m.label, '1500 TJS');
    });

    test('дирамҳо гум намешаванд', () {
      expect(const Money(150050, 'TJS').label, '1500.50 TJS');
      expect(const Money(1, 'TJS').label, '0.01 TJS');
      expect(const Money(99, 'TJS').label, '0.99 TJS');
    });

    test('сифр ва холӣ', () {
      expect(const Money(0, 'TJS').label, '0 TJS');
      expect(Money.fromJson(null).minor, 0);
      expect(const Money(0, 'TJS').isZero, isTrue);
    });

    test('таҷзия аз JSON', () {
      final m = Money.fromJson(
          jsonDecode('{"minor":36000,"currency":"TJS"}') as Map<String, dynamic>);
      expect(m.minor, 36000);
      expect(m.label, '360 TJS');
    });
  });

  test('кампания аз ҷавоби воқеӣ', () {
    // Ҷавоби воқеии POST /marketplace/campaigns.
    const raw = '''
    {"id":"1f00266f-ca43-4fd7-b8c3-3fa94546e74c",
     "advertiserId":"4911a45f-6fe4-4d48-81f6-faa5e0e2f346",
     "title":"Тест кампания","description":"","category":"beauty",
     "targetCountry":"TJ","budget":{"minor":100000,"currency":"TJS"},
     "status":"DRAFT","creatorCount":1,"commissionBps":1000,
     "createdAt":"2026-09-01T09:41:06.558982Z"}''';
    final c = Campaign.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(c.title, 'Тест кампания');
    expect(c.budget.minor, 100000);
    expect(c.budget.label, '1000 TJS');
    // 1000 bps = 10%.
    expect(c.commissionLabel, '10%');
    expect(c.needsPayment, isTrue);
    expect(c.isClosed, isFalse);
    expect(c.createdAt, isNotNull);
  });

  test('пешниҳод бо сабабҳои мувофиқат', () {
    const raw = '''
    {"id":"04075b8f","campaignId":"1f00266f","creatorId":"3a285f3d",
     "status":"INVITED","matchScore":55,
     "reasons":["Категория мувофиқ: beauty","Аудитория аз TJ"],
     "agreed":{"minor":40000,"currency":"TJS"}}''';
    final o = CampaignOffer.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(o.status, 'INVITED');
    expect(o.isPending, isTrue);
    expect(o.reasons.length, 2);
    expect(o.agreed.label, '400 TJS');
  });

  test('метрика бо нусхаи алгоритм', () {
    const raw = '''
    {"creatorId":"3a285f3d","followers":0,"totalViews":0,"averageViews":0,
     "likes":0,"comments":0,"shares":0,"saves":0,"engagementRate":0,
     "contentCount":1,"campaignCount":1,"successfulCampaignCount":1,
     "averageCampaignResult":1,"creatorScore":20,"scoreConfidence":0.1,
     "sampleSize":1,"scoreVersion":1,
     "scoreBreakdown":{"engagement":0,"reach":0,"audience":0,"track_record":20}}''';
    final m = CreatorMetrics.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(m.score, 20);
    expect(m.scoreVersion, 1);
    expect(m.breakdown['track_record'], 20);
    // Боварии 0.1 — интерфейс бояд огоҳ кунад.
    expect(m.isReliable, isFalse);
  });

  test('даромад', () {
    const raw = '''
    {"wallet":{"creatorId":"3a285f3d",
       "available":{"minor":36000,"currency":"TJS"},
       "pending":{"minor":36000,"currency":"TJS"}},
     "paidOut":{"minor":0,"currency":"TJS"},
     "upcoming":{"minor":0,"currency":"TJS"},
     "completedCampaigns":1}''';
    final e = Earnings.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(e.wallet.available.minor, 36000);
    expect(e.wallet.available.label, '360 TJS');
    expect(e.paidOut.isZero, isTrue);
    expect(e.completedCampaigns, 1);
  });

  test('пардохти интизори амали дастӣ SUCCEEDED нест', () {
    const raw = '''
    {"id":"83e9e537","campaignId":"1f00266f","campaignTitle":"Тест кампания",
     "amount":{"minor":36000,"currency":"TJS"},"status":"REQUIRES_ACTION",
     "provider":"manual","failureReason":"manual_transfer_required",
     "createdAt":"2026-09-01T09:47:06.751574Z"}''';
    final p = PayoutRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(p.status, 'REQUIRES_ACTION');
    // Муҳим: интиқоли дастӣ ҳамчун иҷрошуда НАМЕНАМОЯД.
    expect(p.isDone, isFalse);
    expect(p.isFailed, isFalse);
    expect(p.amount.label, '360 TJS');
  });

  test('майдонҳои нопурра ба крах намеоранд', () {
    // Сервери кӯҳна метавонад майдони наверо надиҳад.
    final c = Campaign.fromJson(<String, dynamic>{});
    expect(c.id, '');
    expect(c.budget.minor, 0);
    expect(c.creatorCount, 1);

    final m = CreatorMetrics.fromJson(<String, dynamic>{});
    expect(m.score, 0);
    expect(m.breakdown, isEmpty);

    final o = CampaignOffer.fromJson(<String, dynamic>{});
    expect(o.reasons, isEmpty);
  });
}
