// test/places_test.dart
// «Ҷой»-и пост: муқаррарсозии номҳо (ҳамон мисолҳои backend/places),
// рӯйхати офлайн ва экрани интихоби ҷой (ҷустуҷӯ, интихоб, «Бе ҷой»,
// ҷойи дастӣ, «Ҷойи ҳозираи ман» бо GPS-и рад/хомӯш).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/core/places/device_location.dart';
import 'package:raonson/core/places/place.dart';
import 'package:raonson/core/places/place_normalize.dart';
import 'package:raonson/core/places/places_offline.dart';
import 'package:raonson/core/places/places_repository.dart';
import 'package:raonson/core/ui/app_icons.dart';
import 'package:raonson/create/location_picker/location_picker_screen.dart';
import 'package:raonson/models/post_model.dart';

const _dushanbe = Place(
    id: 'tj-dushanbe', name: 'Душанбе', region: 'Тоҷикистон', kind: 'city',
    lat: 38.5358, lon: 68.7791);
const _khujand = Place(
    id: 'tj-khujand', name: 'Хуҷанд', region: 'Вилояти Суғд, Тоҷикистон',
    kind: 'city', lat: 40.2826, lon: 69.6222);
const _varzob = Place(
    id: 'tj-varzob', name: 'Варзоб',
    region: 'Ноҳияҳои тобеи ҷумҳурӣ, Тоҷикистон', kind: 'district');

/// Манбаи сохта: ҷустуҷӯ аз рӯи ҳамон муқаррарсозӣ.
class _FakeSource implements PlacesSource {
  final List<String> queries = [];
  NearestResult nearestResult =
      const NearestResult(place: _dushanbe, nearby: [_varzob]);
  final List<({double lat, double lon})> nearestCalls = [];

  @override
  Future<PlaceSearchResult> search(String query,
      {double? lat, double? lon}) async {
    queries.add(query);
    const all = [_dushanbe, _khujand, _varzob];
    final q = normalizePlace(query);
    if (q.isEmpty) return const PlaceSearchResult(all);
    final keys = {
      'tj-dushanbe': ['Душанбе', 'Dushanbe'],
      'tj-khujand': ['Хуҷанд', 'Khujand', 'Худжанд'],
      'tj-varzob': ['Варзоб', 'Varzob'],
    };
    return PlaceSearchResult(all
        .where((p) => keys[p.id]!.any((n) => normalizePlace(n).startsWith(q)))
        .toList());
  }

  @override
  Future<NearestResult> nearest(double lat, double lon) async {
    nearestCalls.add((lat: lat, lon: lon));
    return nearestResult;
  }
}

class _FakeDevice implements DeviceLocation {
  _FakeDevice(this.outcome);
  LocationOutcome outcome;
  int calls = 0, appSettings = 0, locationSettings = 0;

  @override
  Future<LocationOutcome> current() async {
    calls++;
    return outcome;
  }

  @override
  Future<void> openAppSettings() async => appSettings++;

  @override
  Future<void> openLocationSettings() async => locationSettings++;
}

/// Picker-ро аз тугма мекушояд ва натиҷаро нигоҳ медорад.
class _Host {
  LocationPickResult? result;
  bool closed = false;

  Widget app({
    Place? current,
    required PlacesSource source,
    required DeviceLocation device,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () async {
                result = await Navigator.of(context).push<LocationPickResult>(
                  MaterialPageRoute(
                    builder: (_) => LocationPickerScreen(
                      current: current,
                      source: source,
                      device: device,
                    ),
                  ),
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _open(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('place-search')), text);
  await tester.pump(const Duration(milliseconds: 300)); // debounce
  await tester.pumpAndSettle();
}

void main() {
  group('normalizePlace — ҳамон мисолҳои backend/places/places_test.go', () {
    const groups = [
      ['Хуҷанд', 'Худжанд', 'Khujand', 'XUJAND', 'khudzhand'],
      ['Душанбе', 'dushanbe', 'DUSHANBE'],
      ['Варзоб', 'Varzob', 'варзоб'],
      ['Кӯлоб', 'Kulob', 'Kŭlob'],
      ['Ғафуров', 'Гафуров', 'Ghafurov', 'Gafurov'],
      ['Қубодиён', 'Qubodiyon', 'Кубодиён'],
      ['Ёвон', 'Yovon'],
      ['Мӯъминобод', "Mu'minobod", 'Mu’minobod'],
      ['Ереван', 'Yerevan'],
      ['Таллинн', 'Таллин', 'Tallinn'],
      ['Eskişehir', 'Эскишехир'],
      ['Ҳисор', 'Hisor', 'hisor'],
      ['İzmir', 'Izmir', 'Измир'],
    ];
    for (final g in groups) {
      test(g.first, () {
        final want = normalizePlace(g.first);
        expect(want, isNotEmpty);
        for (final s in g.skip(1)) {
          expect(normalizePlace(s), want, reason: s);
        }
      });
    }

    test('қиматҳои аниқ', () {
      expect(normalizePlace('Хуҷанд'), 'hujand');
      expect(normalizePlace('Khujand'), 'hujand');
      expect(normalizePlace('  Бохтар  '), 'bohtar');
      expect(normalizePlace('Ҷалолиддини Балхӣ'), 'jalolidini balhi');
      expect(normalizePlace('Rostov-on-Don'), 'rostov on don');
      expect(normalizePlace('Ёвон'), 'ovon');
      expect(normalizePlace(''), '');
    });
  });

  group('PlacesOffline (assets/places/places_tj.json)', () {
    late PlacesOffline off;
    setUpAll(() {
      off = PlacesOffline.fromJsonString(
          File('assets/places/places_tj.json').readAsStringSync());
    });

    test('ҳамаи вилоятҳо ва ноҳияҳо ҳастанд', () {
      expect(off.length, greaterThan(120));
      for (final q in ['Суғд', 'Хатлон', 'Бадахшон', 'Душанбе', 'Варзоб',
          'Рашт', 'Ишкошим', 'Спитамен', 'Шаҳритус']) {
        expect(off.search(q), isNotEmpty, reason: q);
      }
    });

    test('Хуҷанд дар се хат', () {
      for (final q in ['Хуҷанд', 'Khujand', 'Худжанд', 'хуҷ']) {
        expect(off.search(q).first.id, 'tj-khujand', reason: q);
      }
      final k = off.search('Khujand').first;
      expect(k.name, 'Хуҷанд');
      expect(k.region, 'Вилояти Суғд, Тоҷикистон');
    });

    test('Варзоб ва Душанбе', () {
      expect(off.search('Varzob').first.id, 'tj-varzob');
      expect(off.search('Варзобский').first.id, 'tj-varzob');
      expect(off.search('dushanbe').first.id, 'tj-dushanbe');
    });

    test('ҷойи наздик: маркази Душанбе → Душанбе, Хуҷанд → Хуҷанд', () {
      expect(off.nearest(38.5598, 68.7870).place?.id, 'tj-dushanbe');
      expect(off.nearest(38.58, 68.73).place?.id, 'tj-dushanbe');
      expect(off.nearest(40.28, 69.62).place?.id, 'tj-khujand');
      expect(off.nearest(38.5598, 68.7870).nearby, isNotEmpty);
      // Дур аз Тоҷикистон — ҷойи маълум нест.
      expect(off.nearest(48.85, 2.35).place, isNull);
    });

    test('ҷустуҷӯи холӣ → шаҳрҳо, Душанбе аввал', () {
      expect(off.search('').first.id, 'tj-dushanbe');
    });
  });

  test('PostModel locationId-ро мехонад ва нигоҳ медорад', () {
    final p = PostModel.fromJson(const {
      '_id': 'p1', 'caption': '', 'media': [], 'user': {'_id': 'u1'},
      'location': 'Варзоб', 'locationId': 'tj-varzob',
    });
    expect(p.location, 'Варзоб');
    expect(p.locationId, 'tj-varzob');
    expect(PostModel.fromJson(p.toJson()).locationId, 'tj-varzob');
    // Пости кӯҳна: майдон нест → холӣ.
    final old = PostModel.fromJson(const {
      '_id': 'p2', 'caption': '', 'media': [], 'user': {'_id': 'u1'},
      'location': 'Ҷое',
    });
    expect(old.locationId, '');
  });

  group('LocationPickerScreen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('ҷустуҷӯ ва интихоб', (tester) async {
      final host = _Host();
      final src = _FakeSource();
      await _open(tester, host.app(
          source: src,
          device: _FakeDevice(const LocationOutcome.fix(1, 1))));

      // Бе матн — ҷойҳои машҳур.
      expect(find.text(tr('place.popular')), findsOneWidget);
      expect(find.text('Душанбе'), findsOneWidget);

      await _type(tester, 'Khuj');
      expect(src.queries.last, 'Khuj');
      expect(find.text('Хуҷанд'), findsOneWidget);
      expect(find.text('Душанбе'), findsNothing);
      // Охирин имкон — ҷойи дастӣ.
      expect(find.byKey(const ValueKey('place-custom')), findsOneWidget);

      await tester.tap(find.text('Хуҷанд'));
      await tester.pumpAndSettle();
      expect(host.closed, isTrue);
      expect(host.result?.place?.id, 'tj-khujand');
      expect(host.result?.place?.name, 'Хуҷанд');

      // Ба «охирин» илова шуд.
      final recents = await PlaceRecents.instance.load();
      expect(recents.first.id, 'tj-khujand');
    });

    testWidgets('ҷойи дастӣ: «Илова кардани «…»»', (tester) async {
      final host = _Host();
      await _open(tester, host.app(
          source: _FakeSource(),
          device: _FakeDevice(const LocationOutcome.fix(1, 1))));
      await _type(tester, 'Чойхонаи Роҳат');
      expect(find.byKey(const ValueKey('place-empty')), findsOneWidget);
      expect(find.text(tr('place.addCustom', {'name': 'Чойхонаи Роҳат'})),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('place-custom')));
      await tester.pumpAndSettle();
      expect(host.result?.place?.isCustom, isTrue);
      expect(host.result?.place?.name, 'Чойхонаи Роҳат');
    });

    testWidgets('«Бе ҷой» ҷойро тоза мекунад', (tester) async {
      final host = _Host();
      await _open(tester, host.app(
          current: _varzob,
          source: _FakeSource(),
          device: _FakeDevice(const LocationOutcome.fix(1, 1))));
      expect(find.text(tr('place.none')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('place-none')));
      await tester.pumpAndSettle();
      expect(host.closed, isTrue);
      expect(host.result, isNotNull);
      expect(host.result!.place, isNull);
    });

    testWidgets('«Бе ҷой» нест, агар ҷой интихоб нашуда бошад; бастан = бетағйир',
        (tester) async {
      final host = _Host();
      await _open(tester, host.app(
          source: _FakeSource(),
          device: _FakeDevice(const LocationOutcome.fix(1, 1))));
      expect(find.byKey(const ValueKey('place-none')), findsNothing);
      await tester.tap(find.byIcon(AppIcons.close));
      await tester.pumpAndSettle();
      expect(host.closed, isTrue);
      expect(host.result, isNull);
    });

    testWidgets('«Ҷойи ҳозираи ман» → ҷойи наздик', (tester) async {
      final host = _Host();
      final src = _FakeSource();
      final dev = _FakeDevice(const LocationOutcome.fix(38.56, 68.79));
      await _open(tester, host.app(source: src, device: dev));
      await tester.tap(find.byKey(const ValueKey('place-gps')));
      await tester.pumpAndSettle();
      expect(dev.calls, 1);
      expect(src.nearestCalls.single.lat, 38.56);
      expect(find.text(tr('place.youAreIn', {'name': 'Душанбе'})),
          findsOneWidget);
      expect(find.text(tr('place.nearby')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('place-here')));
      await tester.pumpAndSettle();
      expect(host.result?.place?.id, 'tj-dushanbe');
      expect(host.result?.place?.name, 'Душанбе');
    });

    testWidgets('GPS: иҷозат рад шуд → паём ва «Аз нав»', (tester) async {
      final host = _Host();
      final dev =
          _FakeDevice(const LocationOutcome.failed(LocationFailure.denied));
      final src = _FakeSource();
      await _open(tester, host.app(source: src, device: dev));
      await tester.tap(find.byKey(const ValueKey('place-gps')));
      await tester.pumpAndSettle();
      expect(find.text(tr('place.gpsDenied')), findsOneWidget);
      expect(find.text(tr('place.retry')), findsOneWidget);
      expect(src.nearestCalls, isEmpty);
      // Экран баста намешавад ва ҷустуҷӯ кор мекунад.
      expect(host.closed, isFalse);

      dev.outcome = const LocationOutcome.fix(38.56, 68.79);
      await tester.tap(find.byKey(const ValueKey('place-gps-action')));
      await tester.pumpAndSettle();
      expect(dev.calls, 2);
      expect(find.text(tr('place.gpsDenied')), findsNothing);
      expect(find.byKey(const ValueKey('place-here')), findsOneWidget);
    });

    testWidgets('GPS: абадан манъ → «Танзимот» танзимоти барномаро мекушояд',
        (tester) async {
      final dev = _FakeDevice(
          const LocationOutcome.failed(LocationFailure.deniedForever));
      await _open(tester, _Host().app(source: _FakeSource(), device: dev));
      await tester.tap(find.byKey(const ValueKey('place-gps')));
      await tester.pumpAndSettle();
      expect(find.text(tr('place.gpsDeniedForever')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('place-gps-action')));
      await tester.pumpAndSettle();
      expect(dev.appSettings, 1);
      expect(dev.locationSettings, 0);
    });

    testWidgets('GPS хомӯш → «Фаъол кардан» танзимоти ҷойгиршавӣ', (tester) async {
      final dev = _FakeDevice(
          const LocationOutcome.failed(LocationFailure.serviceOff));
      await _open(tester, _Host().app(source: _FakeSource(), device: dev));
      await tester.tap(find.byKey(const ValueKey('place-gps')));
      await tester.pumpAndSettle();
      expect(find.text(tr('place.gpsServiceOff')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('place-gps-action')));
      await tester.pumpAndSettle();
      expect(dev.locationSettings, 1);
    });

    testWidgets('GPS: вақт гузашт → паём', (tester) async {
      final dev =
          _FakeDevice(const LocationOutcome.failed(LocationFailure.timeout));
      await _open(tester, _Host().app(source: _FakeSource(), device: dev));
      await tester.tap(find.byKey(const ValueKey('place-gps')));
      await tester.pumpAndSettle();
      expect(find.text(tr('place.gpsTimeout')), findsOneWidget);
    });

    testWidgets('дар наздикӣ ҷойи маълум нест', (tester) async {
      final src = _FakeSource()
        ..nearestResult = const NearestResult(place: null, nearby: []);
      await _open(tester, _Host().app(
          source: src, device: _FakeDevice(const LocationOutcome.fix(0, 0))));
      await tester.tap(find.byKey(const ValueKey('place-gps')));
      await tester.pumpAndSettle();
      expect(find.text(tr('place.gpsNoNearby')), findsOneWidget);
      expect(find.byKey(const ValueKey('place-here')), findsNothing);
    });

    testWidgets('рӯйхати офлайн — огоҳӣ', (tester) async {
      final off = PlacesOffline.fromJsonString(
          File('assets/places/places_tj.json').readAsStringSync());
      await _open(tester, _Host().app(
          source: _OfflineSource(off),
          device: _FakeDevice(const LocationOutcome.fix(1, 1))));
      expect(find.byKey(const ValueKey('place-offline')), findsOneWidget);
      await _type(tester, 'Varzob');
      expect(find.text('Варзоб'), findsWidgets);
    });
  });
}

class _OfflineSource implements PlacesSource {
  _OfflineSource(this.off);
  final PlacesOffline off;
  @override
  Future<PlaceSearchResult> search(String query, {double? lat, double? lon}) async =>
      PlaceSearchResult(off.search(query, lat: lat, lon: lon), offline: true);
  @override
  Future<NearestResult> nearest(double lat, double lon) async =>
      off.nearest(lat, lon);
}
