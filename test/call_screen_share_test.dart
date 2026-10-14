// test/call_screen_share_test.dart
// Намоиши экран дар занг (мисли WhatsApp): ҳолатҳо idle → requesting →
// sharing → idle, радди розигӣ, қатъ бо занг, сигнали ҳамсӯҳбат ва экран.
//
// Муҳаррик/сигнал/платформа қалбакӣ. Равзанаи розигии MediaProjection,
// хизматрасонии пешзаминаи mediaProjection ва тасвири воқеӣ танҳо дар
// телефони Android санҷида мешаванд.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raonson/calls/active_call.dart';
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

  group('ҳолати намоиш', () {
    testWidgets('idle → requesting → sharing → stopped', (tester) async {
      await startCall(tester, CallType.video);
      expect(ctl.shareState, ScreenShareState.idle);
      expect(ctl.canShareScreen, isTrue);

      await ctl.startScreenShare();
      expect(ctl.shareState, ScreenShareState.requesting);
      expect(engine.shareStarts, 1);
      expect(signal.screens, isEmpty,
          reason: 'то розигии система ҳамсӯҳбат хабар намегирад');

      engine.shareGranted();
      expect(ctl.shareState, ScreenShareState.sharing);
      expect(ctl.screenSharing, isTrue);
      expect(signal.screens, ['p1:start']);
      expect(platform.infos.last.screenSharing, isTrue,
          reason: 'огоҳинома: «Экран намоиш дода мешавад»');
      expect(platform.infos.last.labels['sharing'],
          CallStrings.t('screenSharingNotif'));

      await ctl.stopScreenShare();
      expect(ctl.shareState, ScreenShareState.idle);
      expect(engine.screenCapture, ScreenCaptureStatus.idle);
      expect(engine.shareStops, 1);
      expect(signal.screens, ['p1:start', 'p1:stop']);
      expect(platform.infos.last.screenSharing, isFalse);
      expect(ctl.isActive, isTrue, reason: 'занг идома дорад');
      await finish(tester);
    });

    testWidgets('такрори «оғоз» нодида; toggle қатъ мекунад', (tester) async {
      await startCall(tester, CallType.voice);
      await ctl.toggleScreenShare();
      await ctl.startScreenShare();
      expect(engine.shareStarts, 1);
      engine.shareGranted();
      await ctl.toggleScreenShare();
      expect(ctl.shareState, ScreenShareState.idle);
      expect(signal.screens, ['p1:start', 'p1:stop']);
      await finish(tester);
    });

    testWidgets('розигӣ рад шуд (Agora FAILED) → idle бо хабар',
        (tester) async {
      await startCall(tester, CallType.video);
      await ctl.startScreenShare();
      engine.shareFailed();
      expect(ctl.shareState, ScreenShareState.idle);
      expect(ctl.takeNotice(), CallStrings.t('screenShareFailed'));
      expect(engine.screenCapture, ScreenCaptureStatus.idle,
          reason: 'камера баргардонида шуд');
      expect(signal.screens, isEmpty);
      await finish(tester);
    });

    testWidgets('розигӣ рад шуд (равзанаи система, Android) → хабар',
        (tester) async {
      await startCall(tester, CallType.video);
      await ctl.startScreenShare();
      platform.action!(CallNativeAction.shareDenied);
      expect(ctl.shareState, ScreenShareState.idle);
      expect(ctl.takeNotice(), CallStrings.t('screenShareDenied'));
      expect(engine.shareStops, 1);
      expect(signal.screens, isEmpty);
      // Пас аз рад — аз нав кӯшиш мумкин.
      await ctl.startScreenShare();
      expect(ctl.shareState, ScreenShareState.requesting);
      await finish(tester);
    });

    testWidgets('занг тамом шуд → намоиш қатъ', (tester) async {
      await startCall(tester, CallType.video);
      await ctl.startScreenShare();
      engine.shareGranted();
      expect(ctl.screenSharing, isTrue);
      await ctl.endCall();
      expect(ctl.shareState, ScreenShareState.idle);
      expect(engine.shareStops, 1);
      expect(engine.leaves, 1);
      expect(signal.ends, ['p1']);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('ҳамсӯҳбат қатъ кард → намоиш ҳам қатъ', (tester) async {
      await startCall(tester, CallType.voice);
      await ctl.startScreenShare();
      engine.shareGranted();
      signal.ended!();
      expect(ctl.isActive, isFalse);
      expect(engine.shareStops, 1);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('система қатъ кард (чипи Android 14) → idle ва stop',
        (tester) async {
      await startCall(tester, CallType.video);
      await ctl.startScreenShare();
      engine.shareGranted();
      engine.shareStoppedBySystem();
      expect(ctl.shareState, ScreenShareState.idle);
      expect(signal.screens, ['p1:start', 'p1:stop']);
      await finish(tester);
    });

    testWidgets('тугмаи «Қатъ кардан»-и огоҳинома', (tester) async {
      await startCall(tester, CallType.video);
      await ctl.startScreenShare();
      engine.shareGranted();
      platform.action!(CallNativeAction.stopShare);
      await tester.pump();
      expect(ctl.shareState, ScreenShareState.idle);
      expect(signal.screens.last, 'p1:stop');
      await finish(tester);
    });

    testWidgets('паснамо ҳангоми намоиш камераро таваққуф намекунад',
        (tester) async {
      await startCall(tester, CallType.video);
      await ctl.startScreenShare();
      engine.shareGranted();
      ctl.onAppLifecycle(AppLifecycleState.paused);
      expect(ctl.cameraAutoPaused, isFalse);
      expect(engine.cameraPaused, isFalse);
      expect(ctl.screenSharing, isTrue);
      ctl.onAppLifecycle(AppLifecycleState.resumed);
      await finish(tester);
    });

    testWidgets('бе пайваст ё дар iOS — намоиш нест', (tester) async {
      await startCall(tester, CallType.video, connect: false);
      expect(ctl.canShareScreen, isFalse);
      await ctl.startScreenShare();
      expect(engine.shareStarts, 0);
      engine.peerJoins();
      platform.canShareScreen = false; // iOS: Broadcast Extension нест
      expect(ctl.canShareScreen, isFalse);
      await ctl.startScreenShare();
      expect(engine.shareStarts, 0);
      await finish(tester);
    });
  });

  group('экрани ҳамсӯҳбат', () {
    testWidgets('start → peerSharing, видео гирифта мешавад; stop → не',
        (tester) async {
      await startCall(tester, CallType.voice);
      expect(platform.pipEligible, isFalse);
      signal.screened!('p1', 'start');
      expect(ctl.peerSharing, isTrue);
      expect(engine.viewingRemoteScreen, isTrue);
      expect(platform.pipEligible, isTrue,
          reason: 'экрани ҳамсӯҳбат дар PiP ҳам');
      signal.screened!('p1', 'stop');
      expect(ctl.peerSharing, isFalse);
      expect(engine.viewingRemoteScreen, isFalse);
      expect(platform.pipEligible, isFalse);
      await finish(tester);
    });

    testWidgets('сигнали бегона ё нодуруст рад мешавад', (tester) async {
      await startCall(tester, CallType.video);
      signal.screened!('stranger', 'start');
      expect(ctl.peerSharing, isFalse);
      signal.screened!('p1', 'hack');
      expect(ctl.peerSharing, isFalse);
      signal.screened!('p1', 'start');
      expect(ctl.peerSharing, isTrue);
      await ctl.endCall();
      expect(ctl.peerSharing, isFalse);
      await tester.pump(const Duration(seconds: 61));
    });
  });

  group('экран', () {
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

    Future<void> tapShareInMore(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('call_more')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('more_screen_share')));
      await settle(tester);
    }

    testWidgets(
        'бинанда: экран бо contain + zoom ва «@ali экранро нишон медиҳад»',
        (tester) async {
      await open(tester, CallType.video);
      expect(find.byKey(const Key('call_peer_screen')), findsNothing);
      signal.screened!('p1', 'start');
      await tester.pump();
      expect(find.byKey(const Key('call_peer_screen')), findsOneWidget);
      expect(find.byKey(const Key('call_peer_screen_zoom')), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byKey(const Key('fake_remote_screen_fit')), findsOneWidget,
          reason: 'renderModeFit — экран бурида намешавад');
      expect(find.byKey(const Key('call_peer_sharing_label')), findsOneWidget);
      expect(find.text('@ali экранро нишон медиҳад'), findsOneWidget);

      signal.screened!('p1', 'stop');
      await tester.pump();
      expect(find.byKey(const Key('call_peer_screen')), findsNothing);
      expect(find.byKey(const Key('call_big_view')), findsOneWidget);
      await ctl.endCall();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('бинанда дар занги аудиоӣ ҳам экранро мебинад', (tester) async {
      await open(tester, CallType.voice);
      signal.screened!('p1', 'start');
      await tester.pump();
      expect(find.byKey(const Key('call_peer_screen')), findsOneWidget);
      expect(find.byKey(const Key('call_peer_sharing_label')), findsOneWidget);
      await ctl.endCall();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'намоишдиҳанда: огоҳӣ → розигӣ → баннер, тасвири худ пинҳон → «Қатъ кардан»',
        (tester) async {
      await open(tester, CallType.video);
      expect(find.byKey(const Key('call_small_view')), findsOneWidget);

      await tapShareInMore(tester);
      expect(find.byKey(const Key('screen_share_warning')), findsOneWidget);
      expect(find.text(CallStrings.t('screenShareWarn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('screen_share_confirm')));
      await settle(tester);
      expect(ctl.shareState, ScreenShareState.requesting);
      expect(find.byKey(const Key('call_share_requesting')), findsOneWidget);

      engine.shareGranted();
      await tester.pump();
      expect(find.byKey(const Key('call_sharing_banner')), findsOneWidget);
      expect(find.text(CallStrings.t('screenSharingSelf')), findsOneWidget);
      expect(find.byKey(const Key('call_small_view')), findsNothing,
          reason: 'оинаи беохир нашавад');
      expect(find.byKey(const Key('fake_local_big')), findsNothing);

      await tester.tap(find.byKey(const Key('call_sharing_stop')));
      await tester.pump();
      expect(ctl.shareState, ScreenShareState.idle);
      expect(find.byKey(const Key('call_sharing_banner')), findsNothing);
      expect(find.byKey(const Key('call_small_view')), findsOneWidget);
      expect(signal.screens, ['p1:start', 'p1:stop']);

      // Огоҳӣ дар ҳамон гуфтугӯ як бор.
      await tapShareInMore(tester);
      expect(find.byKey(const Key('screen_share_warning')), findsNothing);
      expect(ctl.shareState, ScreenShareState.requesting);

      await ctl.endCall();
      await settle(tester);
    });

    testWidgets('огоҳӣ «Бекор» → намоиш оғоз намешавад', (tester) async {
      await open(tester, CallType.voice);
      await tapShareInMore(tester);
      await tester.tap(find.byKey(const Key('screen_share_cancel')));
      await settle(tester);
      expect(ctl.shareState, ScreenShareState.idle);
      expect(engine.shareStarts, 0);
      expect(ctl.shareWarned, isFalse);
      await ctl.endCall();
      await settle(tester);
    });

    testWidgets('рад кардани розигӣ → snackbar', (tester) async {
      await open(tester, CallType.voice);
      ctl.markShareWarned();
      await tapShareInMore(tester);
      expect(ctl.shareState, ScreenShareState.requesting);
      platform.action!(CallNativeAction.shareDenied);
      await tester.pump();
      expect(find.text(CallStrings.t('screenShareDenied')), findsOneWidget);
      expect(find.byKey(const Key('call_sharing_banner')), findsNothing);
      await ctl.endCall();
      await settle(tester);
    });

    testWidgets('iOS: тугмаи «Намоиши экран» нест', (tester) async {
      platform.canShareScreen = false;
      await open(tester, CallType.video);
      await tester.tap(find.byKey(const Key('call_more')));
      await settle(tester);
      expect(find.byKey(const Key('call_more_sheet')), findsOneWidget);
      expect(find.byKey(const Key('more_screen_share')), findsNothing);
      await ctl.endCall();
      await settle(tester);
    });
  });
}
