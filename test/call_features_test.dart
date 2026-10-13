// test/call_features_test.dart
// Занг «қавитар аз Instagram/TikTok»: паснамо/пешзамина, огоҳиномаи доимӣ,
// PiP, аз нав пайвастшавӣ, роҳи садо, аудио ↔ видео бо розигӣ.
//
// Ҳама бо муҳаррик/сигнал/платформаи қалбакӣ. Хизматрасонии пешзаминаи
// воқеӣ, PiP-и система ва Bluetooth танҳо дар телефон санҷида мешаванд.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raonson/calls/active_call.dart';
import 'package:raonson/calls/call_media.dart';
import 'package:raonson/calls/call_native.dart';
import 'package:raonson/calls/call_strings.dart';
import 'package:raonson/chat/room/call_screen.dart';

import 'support/call_fakes.dart';

void main() {
  late FakeEngine engine;
  late FakeSignal signal;
  late FakePlatform platform;
  late ActiveCallController ctl;

  setUp(() {
    engine = FakeEngine();
    signal = FakeSignal();
    platform = FakePlatform();
    ctl = ActiveCallController(
      engine: engine,
      signal: signal,
      platform: platform,
      sounds: FakeSounds.new,
      logger: (_, __) {},
      observeLifecycle: false,
    );
  });

  Future<void> startCall(WidgetTester tester, CallType type,
      {bool connect = true}) async {
    ctl.start(CallSession(peer: peer, type: type));
    await tester.pump();
    if (connect) {
      engine.peerJoins();
      await tester.pump();
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await ctl.endCall();
    await tester.pump(const Duration(seconds: 61));
  }

  group('паснамо / пешзамина', () {
    testWidgets('видео: паснамо → камера таваққуф, занг ИДОМА; бозгашт → аз нав',
        (tester) async {
      await startCall(tester, CallType.video);
      ctl.onAppLifecycle(AppLifecycleState.inactive);
      expect(engine.cameraPaused, isFalse, reason: 'inactive — гузариши кӯтоҳ');
      ctl.onAppLifecycle(AppLifecycleState.hidden);
      ctl.onAppLifecycle(AppLifecycleState.paused);
      expect(ctl.backgrounded, isTrue);
      expect(ctl.cameraAutoPaused, isTrue);
      expect(engine.cameraPaused, isTrue);
      expect(ctl.isActive, isTrue, reason: 'занг дар паснамо қатъ намешавад');
      expect(engine.leaves, 0);
      expect(signal.ends, isEmpty);

      await tester.pump(const Duration(minutes: 5));
      expect(ctl.isActive, isTrue);
      expect(ctl.seconds, greaterThanOrEqualTo(300), reason: 'вақт меравад');

      ctl.onAppLifecycle(AppLifecycleState.resumed);
      expect(ctl.cameraAutoPaused, isFalse);
      expect(engine.cameraPaused, isFalse);
      await finish(tester);
    });

    testWidgets('аудио: паснамо ба камера даст намезанад', (tester) async {
      await startCall(tester, CallType.voice);
      ctl.onAppLifecycle(AppLifecycleState.paused);
      expect(ctl.cameraAutoPaused, isFalse);
      expect(engine.cameraPaused, isFalse);
      expect(ctl.isActive, isTrue);
      await finish(tester);
    });

    testWidgets('камераи аз ҷониби корбар хомӯш — бозгашт онро намекушояд',
        (tester) async {
      await startCall(tester, CallType.video);
      await ctl.toggleCamera();
      ctl.onAppLifecycle(AppLifecycleState.paused);
      expect(ctl.cameraAutoPaused, isFalse);
      ctl.onAppLifecycle(AppLifecycleState.resumed);
      expect(engine.cameraPaused, isFalse);
      expect(engine.cameraOff, isTrue);
      await finish(tester);
    });

    testWidgets('PiP: камера кор мекунад; ҳубобча → экрани пурра', (tester) async {
      await startCall(tester, CallType.video);
      ctl.minimize();
      platform.pip.value = true;
      expect(ctl.minimized, isFalse, reason: 'дар PiP видео, на ҳубобча');
      ctl.onAppLifecycle(AppLifecycleState.paused);
      expect(ctl.cameraAutoPaused, isFalse);
      expect(engine.cameraPaused, isFalse);
      platform.pip.value = false;
      await finish(tester);
    });

    testWidgets('барнома «detached» (аз охиринҳо бароварда) — занг идома',
        (tester) async {
      await startCall(tester, CallType.voice);
      ctl.onAppLifecycle(AppLifecycleState.detached);
      await tester.pump(const Duration(seconds: 10));
      expect(ctl.isActive, isTrue);
      expect(platform.calls, isNot(contains('stop')));
      await finish(tester);
    });
  });

  group('огоҳиномаи доимӣ ва PiP (платформа)', () {
    testWidgets('оғоз → start; пайваст → вақтсанҷ; бесадо → нав; қатъ → stop',
        (tester) async {
      await startCall(tester, CallType.voice, connect: false);
      expect(platform.calls.first, 'start');
      expect(platform.infos.first.peerName, 'ali');
      expect(platform.infos.first.connectedAtMs, isNull);
      expect(platform.infos.first.labels['end'], CallStrings.t('end'));

      engine.peerJoins();
      await tester.pump();
      final live = platform.infos.last;
      expect(live.connectedAtMs, isNotNull, reason: 'Android вақтро мекашад');
      expect(live.status, isEmpty);

      final before = platform.calls.length;
      await tester.pump(const Duration(seconds: 3));
      expect(platform.calls.length, before,
          reason: 'ҳар сония огоҳинома нав намешавад');

      await ctl.toggleMute();
      expect(platform.infos.last.muted, isTrue);

      await finish(tester);
      expect(platform.calls.last, 'stop');
    });

    testWidgets('видео: PiP иҷозат; аудио: не; пас аз қатъ — не', (tester) async {
      await startCall(tester, CallType.video);
      expect(platform.pipEligible, isTrue);
      await finish(tester);
      expect(platform.pipEligible, isFalse);

      await startCall(tester, CallType.voice);
      expect(platform.pipEligible, isFalse);
      await finish(tester);
    });

    testWidgets('тугмаҳои огоҳинома: бесадо, баландгӯяк, қатъ', (tester) async {
      await startCall(tester, CallType.voice);
      engine.routed(CallAudioRoute.earpiece);
      platform.action!(CallNativeAction.mute);
      await tester.pump();
      expect(engine.muted, isTrue);
      platform.action!(CallNativeAction.speaker);
      await tester.pump();
      expect(ctl.route, CallAudioRoute.speaker);
      platform.action!(CallNativeAction.end);
      await tester.pump();
      expect(ctl.isActive, isFalse);
      expect(signal.ends, ['p1']);
      expect(platform.action, isNull, reason: 'пас аз қатъ ҷудо');
    });

    test('номи амалҳо аз Android', () {
      expect(MethodChannelCallPlatform.parseAction('end'), CallNativeAction.end);
      expect(MethodChannelCallPlatform.parseAction('open'), CallNativeAction.open);
      expect(MethodChannelCallPlatform.parseAction('hack'), isNull);
    });
  });

  group('аз нав пайвастшавӣ', () {
    testWidgets('шабакаи худ гум → «Аз нав пайваст мешавад…» → барқарор',
        (tester) async {
      await startCall(tester, CallType.voice);
      engine.setConn(CallNetState.reconnecting);
      await tester.pump();
      expect(ctl.reconnecting, isTrue);
      expect(ctl.statusText, CallStrings.t('reconnecting'));
      expect(ctl.reconnectTimerActive, isTrue);
      expect(platform.infos.last.connectedAtMs, isNull);

      await tester.pump(const Duration(seconds: 20));
      engine.setConn(CallNetState.connected);
      await tester.pump();
      expect(ctl.reconnectTimerActive, isFalse);
      expect(ctl.statusText, ctl.timeLabel);

      await tester.pump(const Duration(seconds: 40));
      expect(ctl.isActive, isTrue, reason: 'вақтсанҷи 30с бекор шуд');
      await finish(tester);
    });

    testWidgets('30с бе пайваст → қатъ бо хабари фаҳмо', (tester) async {
      await startCall(tester, CallType.video);
      final s = ctl.session!;
      engine.setConn(CallNetState.reconnecting);
      await tester.pump(const Duration(seconds: 29));
      expect(ctl.isActive, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(ctl.isActive, isFalse);
      expect(s.endMessage, CallStrings.t('reconnectFailed'));
      expect(signal.ends, ['p1']);
      expect(engine.leaves, 1);
    });

    testWidgets('ҳамсӯҳбат пайвастро гум кард → интизор; баргашт → идома',
        (tester) async {
      await startCall(tester, CallType.voice);
      engine.peerDrops();
      await tester.pump();
      expect(ctl.isActive, isTrue);
      expect(ctl.peerReconnecting, isTrue);
      expect(ctl.statusText, CallStrings.t('peerReconnecting'));
      await tester.pump(const Duration(seconds: 15));
      engine.peerJoins();
      await tester.pump();
      expect(ctl.peerReconnecting, isFalse);
      expect(ctl.reconnectTimerActive, isFalse);
      await tester.pump(const Duration(seconds: 40));
      expect(ctl.isActive, isTrue);
      await finish(tester);
    });

    testWidgets('ҳамсӯҳбат барнагашт → 30с → қатъ', (tester) async {
      await startCall(tester, CallType.voice);
      engine.peerDrops();
      await tester.pump(const Duration(seconds: 31));
      expect(ctl.isActive, isFalse);
    });

    testWidgets('ҳамсӯҳбат каналро тарк кард (бе call:end) → фавран тамом',
        (tester) async {
      await startCall(tester, CallType.voice);
      engine.peerQuits();
      await tester.pump();
      expect(ctl.isActive, isFalse);
      expect(signal.ends, isEmpty, reason: 'end-ро бар намегардонем');
    });

    testWidgets('сифати шабака: «Пайвасти суст» аз сатҳи 4', (tester) async {
      await startCall(tester, CallType.video);
      engine.setQuality(3);
      expect(ctl.weakNetwork, isFalse);
      engine.setQuality(5);
      expect(ctl.weakNetwork, isTrue);
      engine.remoteFallback = true;
      expect(ctl.videoFallback, isTrue);
      await ctl.setDataSaver(true);
      expect(engine.dataSaver, isTrue);
      await finish(tester);
      expect(ctl.weakNetwork, isFalse);
    });
  });

  group('роҳи садо', () {
    test('Agora routing → роҳ', () {
      expect(routeFromAgora(1), CallAudioRoute.earpiece);
      expect(routeFromAgora(3), CallAudioRoute.speaker);
      expect(routeFromAgora(5), CallAudioRoute.bluetooth);
      expect(routeFromAgora(0), CallAudioRoute.wired);
      expect(routeFromAgora(-1), CallAudioRoute.unknown);
      expect(agoraRouteOf(CallAudioRoute.bluetooth), 5);
      expect(agoraRouteOf(CallAudioRoute.earpiece), 1);
    });

    test('рӯйхати роҳҳо', () {
      expect(availableRoutes(bluetooth: false, wired: false),
          [CallAudioRoute.earpiece, CallAudioRoute.speaker]);
      expect(availableRoutes(bluetooth: true, wired: false), [
        CallAudioRoute.earpiece,
        CallAudioRoute.bluetooth,
        CallAudioRoute.speaker,
      ]);
      expect(availableRoutes(bluetooth: false, wired: true),
          [CallAudioRoute.wired, CallAudioRoute.speaker],
          reason: 'бо гӯшмонаки симдор гӯшаки телефон нест');
      expect(
          availableRoutes(
              bluetooth: false, wired: false, current: CallAudioRoute.bluetooth),
          contains(CallAudioRoute.bluetooth));
    });

    testWidgets('баландгӯяк ↔ Bluetooth; интихоби дастӣ', (tester) async {
      platform.devices = const AudioDevices(bluetooth: true);
      await startCall(tester, CallType.voice);
      engine.routed(CallAudioRoute.earpiece);
      expect(ctl.routes, [
        CallAudioRoute.earpiece,
        CallAudioRoute.bluetooth,
        CallAudioRoute.speaker,
      ]);
      await ctl.toggleSpeaker();
      expect(ctl.route, CallAudioRoute.speaker);
      await ctl.toggleSpeaker();
      expect(ctl.route, CallAudioRoute.bluetooth,
          reason: 'аз баландгӯяк ба Bluetooth, на ба гӯшак');
      await ctl.selectRoute(CallAudioRoute.earpiece);
      expect(ctl.route, CallAudioRoute.earpiece);
      expect(engine.routeCalls, [
        CallAudioRoute.speaker,
        CallAudioRoute.bluetooth,
        CallAudioRoute.earpiece,
      ]);
      await finish(tester);
    });
  });

  group('аудио ↔ видео бо розигӣ', () {
    testWidgets('дархост → розигӣ → видео (+ баландгӯяк, PiP)', (tester) async {
      await startCall(tester, CallType.voice);
      engine.routed(CallAudioRoute.earpiece);
      ctl.requestVideo();
      expect(ctl.switchState, CallSwitchState.requesting);
      expect(signal.switches, ['p1:video:request']);
      expect(ctl.type, CallType.voice, reason: 'бе розигӣ камера намекушояд');
      expect(engine.videoOn, isFalse);

      signal.switched!('p1', 'video', 'accept');
      await tester.pump();
      expect(ctl.type, CallType.video);
      expect(engine.videoOn, isTrue);
      expect(ctl.switchState, CallSwitchState.idle);
      expect(platform.pipEligible, isTrue);
      expect(ctl.route, CallAudioRoute.speaker);
      await finish(tester);
    });

    testWidgets('рад → хабар; аудио мемонад', (tester) async {
      await startCall(tester, CallType.voice);
      ctl.requestVideo();
      signal.switched!('p1', 'video', 'decline');
      expect(ctl.type, CallType.voice);
      expect(ctl.takeNotice(), CallStrings.t('videoDeclined', {'name': 'ali'}));
      expect(ctl.takeNotice(), isNull);
      await finish(tester);
    });

    testWidgets('бе ҷавоб 30с → бекор (cancel ба ҳамсӯҳбат)', (tester) async {
      await startCall(tester, CallType.voice);
      ctl.requestVideo();
      await tester.pump(const Duration(seconds: 31));
      expect(ctl.switchState, CallSwitchState.idle);
      expect(signal.switches.last, 'p1:video:cancel');
      expect(ctl.takeNotice(), isNotNull);
      await finish(tester);
    });

    testWidgets('дархости ҳамсӯҳбат: қабул / рад', (tester) async {
      await startCall(tester, CallType.voice);
      signal.switched!('p1', 'video', 'request');
      expect(ctl.switchState, CallSwitchState.incoming);
      await ctl.answerVideoRequest(false);
      expect(signal.switches.last, 'p1:video:decline');
      expect(ctl.type, CallType.voice);

      signal.switched!('p1', 'video', 'request');
      await ctl.answerVideoRequest(true);
      expect(signal.switches.last, 'p1:video:accept');
      expect(ctl.type, CallType.video);
      await finish(tester);
    });

    testWidgets('ҳамсӯҳбат дархостро бекор кард', (tester) async {
      await startCall(tester, CallType.voice);
      signal.switched!('p1', 'video', 'request');
      signal.switched!('p1', 'video', 'cancel');
      expect(ctl.switchState, CallSwitchState.idle);
      await finish(tester);
    });

    testWidgets('ҳарду ҳамзамон пурсиданд → видео', (tester) async {
      await startCall(tester, CallType.voice);
      ctl.requestVideo();
      signal.switched!('p1', 'video', 'request');
      await tester.pump();
      expect(ctl.type, CallType.video);
      expect(signal.switches.last, 'p1:video:accept');
      await finish(tester);
    });

    testWidgets('видео → аудио: бе розигӣ, ҳамсӯҳбат хабар мегирад',
        (tester) async {
      await startCall(tester, CallType.video);
      await ctl.switchToVoice();
      expect(signal.switches, ['p1:voice:apply']);
      expect(ctl.type, CallType.voice);
      expect(engine.videoOn, isFalse);
      expect(platform.pipEligible, isFalse);
      await finish(tester);
    });

    testWidgets('ҳамсӯҳбат ба аудио гузашт → мо ҳам', (tester) async {
      await startCall(tester, CallType.video);
      signal.switched!('p1', 'voice', 'apply');
      await tester.pump();
      expect(ctl.type, CallType.voice);
      expect(ctl.takeNotice(), CallStrings.t('switchedToVoice'));
      await finish(tester);
    });

    testWidgets('сигнали бегона (on дигар) рад мешавад', (tester) async {
      await startCall(tester, CallType.voice);
      signal.switched!('stranger', 'video', 'request');
      expect(ctl.switchState, CallSwitchState.idle);
      await finish(tester);
    });

    testWidgets('дархости такрорӣ нодида гирифта мешавад',
        (tester) async {
      // Дархост дар аудио танҳо як бор; такрор — нодида.
      await startCall(tester, CallType.voice);
      ctl.requestVideo();
      ctl.requestVideo();
      expect(signal.switches, ['p1:video:request']);
      await finish(tester);
    });
  });

  group('экран', () {
    // Аватар доимо «мезанад» (аниматсия) — pumpAndSettle анҷом намеёбад.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> open(WidgetTester tester, CallType type) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final nav = GlobalKey<NavigatorState>();
      ctl.navigatorKey = nav;
      await tester.pumpWidget(MaterialApp(
          navigatorKey: nav, home: const Scaffold(body: Text('home'))));
      nav.currentState!.push(MaterialPageRoute(
          builder: (_) =>
              CallScreen(peer: peer, callType: type, controller: ctl)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      engine.peerJoins();
      await tester.pump();
    }

    testWidgets('PiP: танҳо видеои ҳамсӯҳбат, тасвири худ пинҳон',
        (tester) async {
      await open(tester, CallType.video);
      expect(find.byKey(const Key('call_small_view')), findsOneWidget);
      platform.pip.value = true;
      await tester.pump();
      expect(find.byKey(const Key('call_pip_mode')), findsOneWidget);
      expect(find.byKey(const Key('fake_remote_pipwin')), findsOneWidget);
      expect(find.byKey(const Key('call_small_view')), findsNothing);
      expect(find.byKey(const Key('call_minimize')), findsNothing);
      platform.pip.value = false;
      await tester.pump();
      expect(find.byKey(const Key('call_small_view')), findsOneWidget);
      await ctl.endCall();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('баннери дархости видео → «Қабул» экранро видео мекунад',
        (tester) async {
      await open(tester, CallType.voice);
      expect(find.byKey(const Key('call_big_view')), findsNothing);
      signal.switched!('p1', 'video', 'request');
      await tester.pump();
      expect(find.byKey(const Key('call_video_request')), findsOneWidget);
      await tester.tap(find.byKey(const Key('call_video_accept')));
      await tester.pump();
      expect(find.byKey(const Key('call_video_request')), findsNothing);
      expect(find.byKey(const Key('call_big_view')), findsOneWidget);
      expect(signal.switches.last, 'p1:video:accept');
      await ctl.endCall();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('«Пайвасти суст» + «Видеоро хомӯш кун»', (tester) async {
      await open(tester, CallType.video);
      engine.setQuality(5);
      await tester.pump();
      expect(find.byKey(const Key('call_weak_network')), findsOneWidget);
      await tester.tap(find.text(CallStrings.t('dataSaver')));
      await tester.pump();
      expect(engine.dataSaver, isTrue);
      await ctl.endCall();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('варақаи садо бо Bluetooth', (tester) async {
      platform.devices = const AudioDevices(bluetooth: true);
      await open(tester, CallType.voice);
      await tester.tap(find.byKey(const Key('call_route')));
      await settle(tester);
      expect(find.byKey(const Key('call_route_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('route_bluetooth')));
      await settle(tester);
      expect(ctl.route, CallAudioRoute.bluetooth);
      await ctl.endCall();
      await settle(tester);
    });

    testWidgets('«Бештар»: AI-хомӯшкунӣ ва гузариш ба видео', (tester) async {
      await open(tester, CallType.voice);
      await tester.tap(find.byKey(const Key('call_more')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('more_ains')));
      await settle(tester);
      expect(engine.noiseSuppression, isTrue);
      await tester.tap(find.byKey(const Key('more_to_video')));
      await settle(tester);
      expect(ctl.switchState, CallSwitchState.requesting);
      expect(find.byKey(const Key('call_video_waiting')), findsOneWidget);
      await ctl.endCall();
      await settle(tester);
    });
  });
}
