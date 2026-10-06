// test/call_minimize_test.dart
// Занги хурдшаванда (ҳубобча), пешнамоиши кашидашаванда ва иваз.
//
// Муҳаррик/сигнал/садо қалбакӣ: Agora ва сокет дар тест нестанд. Тасвири
// воқеии видео ва PiP-и система танҳо дар дастгоҳ санҷида мешаванд.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raonson/calls/active_call.dart';
import 'package:raonson/calls/minimized_call_view.dart';
import 'package:raonson/calls/snap_tile.dart';
import 'package:raonson/chat/room/call_screen.dart';
import 'package:raonson/core/ui/app_icons.dart';
import 'package:raonson/models/user_model.dart';

class FakeEngine extends ChangeNotifier implements CallEngine {
  bool joined = false;
  int joins = 0;
  int leaves = 0;
  @override
  bool configured = true;
  @override
  bool remoteJoined = false;
  @override
  int? remoteUid;
  @override
  bool muted = false;
  @override
  bool speakerOn = true;
  @override
  bool cameraOff = false;
  @override
  String? error;
  @override
  bool get hasVideo => joined;

  void peerJoins() {
    remoteJoined = true;
    remoteUid = 42;
    notifyListeners();
  }

  @override
  Future<({String channel, String token})?> credentials(String peerId) async =>
      (channel: 'ch', token: 't');
  @override
  Future<void> join(
      {required String channel,
      required String token,
      required bool isVideo}) async {
    joins++;
    joined = true;
    notifyListeners();
  }

  @override
  Future<void> leave() async {
    leaves++;
    joined = false;
    remoteJoined = false;
    remoteUid = null;
    notifyListeners();
  }

  @override
  Future<void> toggleMute() async {
    muted = !muted;
    notifyListeners();
  }

  @override
  Future<void> toggleCamera() async {
    cameraOff = !cameraOff;
    notifyListeners();
  }

  @override
  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    notifyListeners();
  }

  @override
  Future<void> flipCamera() async {}

  @override
  Widget remoteView(String tag) =>
      ColoredBox(key: Key('fake_remote_$tag'), color: const Color(0xFF00FF00));
  @override
  Widget localView(String tag) =>
      ColoredBox(key: Key('fake_local_$tag'), color: const Color(0xFF0000FF));
}

class FakeSignal implements CallSignal {
  final answered = <String>[];
  final ends = <String>[];
  VoidCallback? ended;
  VoidCallback? declined;
  @override
  void sendAnswered(String to) => answered.add(to);
  @override
  void sendEnd(String to) => ends.add(to);
  @override
  set onEnded(VoidCallback? cb) => ended = cb;
  @override
  set onDeclined(VoidCallback? cb) => declined = cb;
}

class FakeSounds implements CallSounds {
  @override
  Future<void> playRingback() async {}
  @override
  Future<void> playConnected() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

final peer = UserModel(
  id: 'p1',
  username: 'ali',
  avatar: '',
  verified: false,
  isPrivate: false,
  postsCount: 0,
  followersCount: 0,
  followingCount: 0,
);

void main() {
  group('TileSnap (математика)', () {
    const area = Size(400, 800);
    const tile = Size(100, 140);
    const insets = EdgeInsets.fromLTRB(16, 72, 16, 188);
    final b = TileSnap.bounds(area, tile, insets);

    test('майдон safe area ва панели тугмаҳоро эҳтиром мекунад', () {
      expect(b, const Rect.fromLTRB(16, 72, 284, 472));
      expect(TileSnap.offsetOf(SnapCorner.topLeft, b), const Offset(16, 72));
      expect(TileSnap.offsetOf(SnapCorner.bottomRight, b),
          const Offset(284, 472));
    });

    test('ҷой нарасад — майдон манфӣ намешавад', () {
      final tight = TileSnap.bounds(
          const Size(100, 100), tile, const EdgeInsets.all(10));
      expect(tight.width, 0);
      expect(tight.height, 0);
      expect(tight.topLeft, const Offset(10, 10));
    });

    test('clamp дар дохили майдон нигоҳ медорад', () {
      expect(TileSnap.clamp(const Offset(-50, 900), b), const Offset(16, 472));
      expect(TileSnap.clamp(const Offset(100, 200), b), const Offset(100, 200));
    });

    test('кунҷи наздиктарин', () {
      expect(TileSnap.nearest(const Offset(20, 80), b), SnapCorner.topLeft);
      expect(TileSnap.nearest(const Offset(200, 100), b), SnapCorner.topRight);
      expect(TileSnap.nearest(const Offset(100, 400), b), SnapCorner.bottomLeft);
      expect(TileSnap.nearest(const Offset(250, 300), b),
          SnapCorner.bottomRight);
    });

    test('партофтан (velocity) кунҷро иваз мекунад', () {
      // Каме чап аз марказ, вале зуд ба рост партофта шуд.
      const p = Offset(140, 100);
      expect(TileSnap.nearest(p, b), SnapCorner.topLeft);
      expect(TileSnap.nearest(p, b, velocity: const Offset(1500, 0)),
          SnapCorner.topRight);
      expect(TileSnap.snap(p, b, velocity: const Offset(0, 4000)),
          const Offset(16, 472));
    });
  });

  group('SnapTile (widget)', () {
    testWidgets('кашидан → ба кунҷ бо аниматсия мечаспад', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var taps = 0;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: SnapTile(
          size: const Size(100, 140),
          insets: const EdgeInsets.fromLTRB(16, 72, 16, 188),
          onTap: () => taps++,
          child: const SizedBox.expand(key: Key('t')),
        ),
      ));
      expect(tester.getTopLeft(find.byKey(const Key('t'))),
          const Offset(284, 72));

      await tester.timedDrag(find.byKey(const Key('t')),
          const Offset(-200, 300), const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 50));
      // Ҳанӯз дар роҳ — на дар кунҷ.
      expect(tester.getTopLeft(find.byKey(const Key('t'))),
          isNot(const Offset(16, 472)));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const Key('t'))),
          const Offset(16, 472));
      final st = tester.state<SnapTileState>(find.byType(SnapTile));
      expect(st.corner, SnapCorner.bottomLeft);

      await tester.tap(find.byKey(const Key('t')));
      expect(taps, 1);
    });
  });

  group('ActiveCallController + ҳубобча', () {
    late FakeEngine engine;
    late FakeSignal signal;
    late ActiveCallController ctl;
    late GlobalKey<NavigatorState> navKey;
    final logs = <String>[];

    setUp(() {
      engine = FakeEngine();
      signal = FakeSignal();
      logs.clear();
      navKey = GlobalKey<NavigatorState>();
      ctl = ActiveCallController(
        engine: engine,
        signal: signal,
        sounds: FakeSounds.new,
        logger: (_, t) => logs.add(t),
      )..navigatorKey = navKey;
    });

    Future<void> openCall(WidgetTester tester, CallType type,
        {bool incoming = false}) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('home')),
      ));
      navKey.currentState!.push(MaterialPageRoute(
        builder: (_) => CallScreen(
            peer: peer,
            callType: type,
            isIncoming: incoming,
            controller: ctl),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('minimize → ҳубобча; restore → экрани пурра; end → нест',
        (tester) async {
      await openCall(tester, CallType.voice);
      expect(find.byType(CallScreen), findsOneWidget);
      expect(engine.joins, 1);

      await tester.tap(find.byKey(const Key('call_minimize')));
      await settle(tester);
      expect(find.byType(CallScreen), findsNothing);
      expect(find.byType(MinimizedCallView), findsOneWidget);
      expect(ctl.overlayShown, isTrue);
      expect(ctl.isActive, isTrue, reason: 'занг набояд қатъ шавад');
      expect(engine.leaves, 0);
      expect(signal.ends, isEmpty);

      // Корбар ба экрани дигар меравад — ҳубобча дар боло мемонад.
      navKey.currentState!.push(MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('profile'))));
      await settle(tester);
      expect(find.text('profile'), findsOneWidget);
      expect(find.byType(MinimizedCallView), findsOneWidget);

      // Вақт дар ҳубобча идома дорад.
      engine.peerJoins();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('00:03'), findsOneWidget);

      await tester.tap(find.byKey(const Key('call_pip')));
      await settle(tester);
      expect(find.byType(CallScreen), findsOneWidget);
      expect(find.byType(MinimizedCallView), findsNothing);
      expect(engine.joins, 1, reason: 'бе пайвасти нав');
      expect(ctl.seconds, greaterThanOrEqualTo(3));

      // Ишораи «ақиб»-и Android → боз хурд.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(CallScreen), findsNothing);
      expect(find.byType(MinimizedCallView), findsOneWidget);
      expect(find.text('profile'), findsOneWidget);

      final idle = ctl.whenIdle();
      var idleDone = false;
      idle.then((_) => idleDone = true);

      final secs = ctl.seconds;
      await tester.tap(find.byKey(const Key('call_pip_end')));
      await settle(tester);
      expect(find.byType(MinimizedCallView), findsNothing);
      expect(ctl.overlayShown, isFalse);
      expect(ctl.isActive, isFalse);
      expect(engine.leaves, 1);
      expect(signal.ends, ['p1']);
      expect(idleDone, isTrue);
      expect(logs, ['ended:audio:$secs']);
      // Вақтсанҷ қатъ шуд.
      await tester.pump(const Duration(seconds: 2));
      expect(ctl.seconds, secs);
    });

    testWidgets('ҳамсӯҳбат қатъ кард, вақте хурд аст → ҳубобча нест',
        (tester) async {
      await openCall(tester, CallType.video);
      await tester.tap(find.byKey(const Key('call_minimize')));
      await settle(tester);
      expect(find.byType(MinimizedCallView), findsOneWidget);

      signal.ended!();
      await settle(tester);
      expect(find.byType(MinimizedCallView), findsNothing);
      expect(ctl.isActive, isFalse);
      expect(signal.ends, isEmpty, reason: 'end-ро бар намегардонем');
      expect(engine.leaves, 1);
    });

    testWidgets('ҳамсӯҳбат қатъ кард дар экрани пурра → экран пӯшида',
        (tester) async {
      await openCall(tester, CallType.voice, incoming: true);
      expect(signal.answered, ['p1']);
      signal.ended!();
      await settle(tester);
      expect(find.byType(CallScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(MinimizedCallView), findsNothing);
      expect(logs, isEmpty, reason: 'қабулкунанда сабт намекунад');
    });

    testWidgets('тугмаи «қатъ» дар экрани пурра', (tester) async {
      await openCall(tester, CallType.voice);
      await tester.tap(find.byIcon(AppIcons.call_end_rounded));
      await settle(tester);
      expect(find.byType(CallScreen), findsNothing);
      expect(ctl.isActive, isFalse);
      expect(signal.ends, ['p1']);
      expect(logs, ['missed:audio:0']);
    });

    testWidgets('видео: пахши тасвири хурд — иваз (худ калон) ва бозгашт',
        (tester) async {
      await openCall(tester, CallType.video);
      engine.peerJoins();
      await tester.pump();

      Finder inBig(String k) => find.descendant(
          of: find.byKey(const Key('call_big_view')),
          matching: find.byKey(Key(k)));
      Finder inSmall(String k) => find.descendant(
          of: find.byKey(const Key('call_small_view')),
          matching: find.byKey(Key(k)));

      expect(inBig('fake_remote_big'), findsOneWidget);
      expect(inSmall('fake_local_small'), findsOneWidget);
      expect(ctl.selfIsBig, isFalse);

      await tester.tap(find.byKey(const Key('call_small_view')));
      await tester.pump();
      expect(ctl.selfIsBig, isTrue);
      expect(inBig('fake_local_big'), findsOneWidget);
      expect(inSmall('fake_remote_small'), findsOneWidget);

      await tester.tap(find.byKey(const Key('call_small_view')));
      await tester.pump();
      expect(ctl.selfIsBig, isFalse);
      expect(inBig('fake_remote_big'), findsOneWidget);

      await ctl.endCall();
      await settle(tester);
    });

    testWidgets('видео: тасвири худ кашида мешавад ва ба кунҷ мечаспад',
        (tester) async {
      await openCall(tester, CallType.video);
      final tile = find.byKey(const Key('call_small_view'));
      // Пешфарз: боло-рост, зери сарлавҳа.
      expect(tester.getTopLeft(tile), const Offset(400 - 16 - 100, 72));

      await tester.timedDrag(
          tile, const Offset(-250, 280), const Duration(milliseconds: 600));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // Поён-чап, болои панели тугмаҳо (180 + 8).
      expect(tester.getTopLeft(tile), const Offset(16, 800 - 188 - 140));
      expect(ctl.selfIsBig, isFalse, reason: 'кашидан иваз нест');

      await ctl.endCall();
      await settle(tester);
    });

    testWidgets('видео хурдшуда: тугмаи бесадо дар ҳубобча', (tester) async {
      await openCall(tester, CallType.video);
      engine.peerJoins();
      await tester.tap(find.byKey(const Key('call_minimize')));
      await settle(tester);
      expect(find.byKey(const Key('fake_remote_pip')), findsOneWidget);
      await tester.tap(find.byKey(const Key('call_pip_mute')));
      await tester.pump();
      expect(engine.muted, isTrue);
      expect(find.byType(MinimizedCallView), findsOneWidget);
      await ctl.endCall();
      await settle(tester);
      expect(find.byType(MinimizedCallView), findsNothing);
    });

    testWidgets('экран бе «хурд кардан» баста шуд → занг қатъ', (tester) async {
      await openCall(tester, CallType.voice);
      final route = ModalRoute.of(tester.element(find.byType(CallScreen)))!;
      navKey.currentState!.removeRoute(route);
      await settle(tester);
      expect(ctl.isActive, isFalse);
      expect(engine.leaves, 1);
      expect(find.byType(MinimizedCallView), findsNothing);
    });

    testWidgets('AGORA_APP_ID нест → экран пӯшида', (tester) async {
      engine.configured = false;
      await openCall(tester, CallType.voice);
      await settle(tester);
      expect(find.byType(CallScreen), findsNothing);
      expect(ctl.isActive, isFalse);
      expect(engine.joins, 0);
    });
  });
}
