import 'dart:async';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../calls/call_media.dart';
import 'api/api_client.dart';

const String kAgoraAppId = String.fromEnvironment('AGORA_APP_ID',
    defaultValue: '');

class AgoraService extends ChangeNotifier {
  static final AgoraService _i = AgoraService._();
  factory AgoraService() => _i;
  AgoraService._();

  RtcEngine? _engine;
  String _channelId = '';

  bool _localJoined  = false;
  bool _remoteJoined = false;
  bool _muted        = false;
  bool _speakerOn    = true;
  bool _cameraOff    = false;
  bool _frontCamera  = true;
  int? _remoteUid;

  // ── Ҳолати иловагии занг (шабака, садо, видео) ──
  CallNetState   _connState      = CallNetState.idle;
  int            _netQuality     = 0;
  bool           _remoteFallback = false;
  bool           _remoteDropped  = false;
  CallAudioRoute _audioRoute     = CallAudioRoute.unknown;
  bool           _videoOn        = false;
  bool           _dataSaver      = false;
  bool           _ainsOn         = false;
  bool           _blurOn         = false;
  bool           _beautyOn       = false;

  // ── Намоиши экран ──
  ScreenCaptureStatus _screen = ScreenCaptureStatus.idle;
  /// Ҳамсӯҳбат экран нишон медиҳад ва мо (дар занги аудиоӣ) видеоро
  /// барои дидани он гирифтаем.
  bool _viewingRemoteScreen = false;

  CallNetState   get connState      => _connState;
  /// Сифати шабакаи худ (Agora QualityType 0..6; бадтарини uplink/downlink).
  int            get netQuality     => _netQuality;
  /// Agora видеои ҳамсӯҳбатро бо сабаби шабака хомӯш кард (танҳо садо).
  bool           get remoteFallback => _remoteFallback;
  /// Ҳамсӯҳбат пайвастро гум кард (на «баромад»).
  bool           get remoteDropped  => _remoteDropped;
  CallAudioRoute get audioRoute     => _audioRoute;
  bool           get videoOn        => _videoOn;
  bool           get dataSaver      => _dataSaver;
  bool           get ainsOn         => _ainsOn;
  bool           get blurOn         => _blurOn;
  bool           get beautyOn       => _beautyOn;
  ScreenCaptureStatus get screenCapture => _screen;

  bool       get localJoined  => _localJoined;
  bool       get remoteJoined => _remoteJoined;
  bool       get muted        => _muted;
  bool       get speakerOn    => _speakerOn;
  bool       get cameraOff    => _cameraOff;
  bool       get frontCamera  => _frontCamera;
  int?       get remoteUid    => _remoteUid;
  RtcEngine? get engine       => _engine;
  String     get channelId    => _channelId;

  // ─── JOIN ───
  /// Хатои охирини Agora (масалан token нодуруст) — экран онро нишон медиҳад,
  /// то корбар то абад «Пайваст мешавад…» набинад.
  String? _error;
  String? get error => _error;

  Future<void> joinCall({
    required String channelName,
    required bool   isVideo,
    String          token = '',
  }) async {
    _error = null;
    if (kAgoraAppId.isEmpty) {
      debugPrint('[Agora] ERROR: AGORA_APP_ID is not set. Build with --dart-define=AGORA_APP_ID=your_id');
      _error = 'AGORA_APP_ID';
      notifyListeners();
      return;
    }
    await _requestPermissions(isVideo);

    if (_engine != null) {
      try { await _engine!.release(); } catch (_) {}
      _engine = null;
    }
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(appId: kAgoraAppId));
    _connState      = CallNetState.connecting;
    _netQuality     = 0;
    _remoteFallback = false;
    _remoteDropped  = false;
    _audioRoute     = CallAudioRoute.unknown;
    _videoOn        = isVideo;
    _dataSaver      = false;
    _blurOn         = false;
    _beautyOn       = false;
    _screen         = ScreenCaptureStatus.idle;
    _viewingRemoteScreen = false;
    // Мисли WhatsApp: аудио — гӯшаки телефон, видео — баландгӯяк.
    _speakerOn      = isVideo;

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        debugPrint('[Agora] Local joined: ${connection.channelId}');
        _localJoined = true;
        _connState   = CallNetState.connected;
        notifyListeners();
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        debugPrint('[Agora] Remote joined: $remoteUid');
        _remoteUid     = remoteUid;
        _remoteJoined  = true;
        _remoteDropped = false;
        notifyListeners();
      },
      onUserOffline: (connection, remoteUid, reason) {
        debugPrint('[Agora] Remote left: $remoteUid ($reason)');
        _remoteUid     = null;
        _remoteJoined  = false;
        _remoteDropped = reason == UserOfflineReasonType.userOfflineDropped;
        notifyListeners();
      },
      onNetworkQuality: (connection, remoteUid, tx, rx) {
        // uid 0 — худи мо.
        if (remoteUid != 0) return;
        final q = _q(tx) > _q(rx) ? _q(tx) : _q(rx);
        if (q != _netQuality) {
          _netQuality = q;
          notifyListeners();
        }
      },
      onRemoteSubscribeFallbackToAudioOnly: (uid, isFallbackOrRecover) {
        _remoteFallback = isFallbackOrRecover;
        notifyListeners();
      },
      onLocalVideoStateChanged: (source, state, reason) {
        if (source == VideoSourceType.videoSourceScreen ||
            source == VideoSourceType.videoSourceScreenPrimary) {
          _onScreenState(state, reason);
        }
      },
      onAudioRoutingChanged: (routing) {
        _audioRoute = routeFromAgora(routing);
        _speakerOn  = _audioRoute == CallAudioRoute.speaker;
        notifyListeners();
      },
      onError: (err, msg) {
        debugPrint('[Agora] Error $err: $msg');
        if (_fatal(err)) { _error = err.name; notifyListeners(); }
      },
      onConnectionStateChanged: (connection, state, reason) {
        _connState = switch (state) {
          ConnectionStateType.connectionStateConnecting   => CallNetState.connecting,
          ConnectionStateType.connectionStateConnected    => CallNetState.connected,
          ConnectionStateType.connectionStateReconnecting => CallNetState.reconnecting,
          ConnectionStateType.connectionStateFailed       => CallNetState.failed,
          ConnectionStateType.connectionStateDisconnected => CallNetState.idle,
        };
        notifyListeners();
        if (state == ConnectionStateType.connectionStateFailed ||
            reason == ConnectionChangedReasonType.connectionChangedInvalidToken ||
            reason == ConnectionChangedReasonType.connectionChangedTokenExpired ||
            reason == ConnectionChangedReasonType.connectionChangedInvalidAppId ||
            reason == ConnectionChangedReasonType.connectionChangedInvalidChannelName ||
            reason == ConnectionChangedReasonType.connectionChangedBannedByServer) {
          _error = reason.name;
          notifyListeners();
        }
      },
    ));

    if (isVideo) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.enableAudio();
      await _engine!.disableVideo();
    }

    await _engine!.setDefaultAudioRouteToSpeakerphone(_speakerOn);

    // Шабакаи суст: ҳамсӯҳбат видеои сифати пастро мегирад, баъд танҳо
    // садо — занг қатъ намешавад. Видеои худ ду ҷараён (баланд/паст).
    try {
      await _engine!.enableDualStreamMode(enabled: true);
      await _engine!.setRemoteSubscribeFallbackOption(
          StreamFallbackOptions.streamFallbackOptionAudioOnly);
    } catch (e) {
      debugPrint('[Agora] fallback setup: $e');
    }
    if (_ainsOn) await setNoiseSuppression(true);

    _channelId = channelName;
    await _engine!.joinChannel(
      token:     token,
      channelId: channelName,
      uid:       0,
      options: ChannelMediaOptions(
        channelProfile:           ChannelProfileType.channelProfileCommunication,
        clientRoleType:           ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack:   true,
        publishCameraTrack:       isVideo,
        autoSubscribeAudio:       true,
        autoSubscribeVideo:       isVideo,
      ),
    );
  }

  // ─── LIVE (broadcast: host стрим мекунад, дигарон тамошо) ───
  Future<void> joinLive({
    required String channelName,
    required bool   asHost,
    String          token = '',
  }) async {
    _error = null;
    if (asHost) await _requestPermissions(true); // host: камера+микрофон

    if (_engine != null) {
      try { await _engine!.release(); } catch (_) {}
      _engine = null;
    }
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(appId: kAgoraAppId));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        _localJoined = true;
        notifyListeners();
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        _remoteUid    = remoteUid;
        _remoteJoined = true;
        notifyListeners();
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (_remoteUid == remoteUid) {
          _remoteUid    = null;
          _remoteJoined = false;
          notifyListeners();
        }
      },
      onError: (err, msg) => debugPrint('[AgoraLive] Error $err: $msg'),
    ));

    await _engine!.enableVideo();
    if (asHost) await _engine!.startPreview();

    _channelId = channelName;
    await _engine!.joinChannel(
      token:     token,
      channelId: channelName,
      uid:       0,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: asHost
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
        publishMicrophoneTrack: asHost,
        publishCameraTrack:     asHost,
        autoSubscribeAudio:     true,
        autoSubscribeVideo:     true,
      ),
    );
  }

  // ─── LEAVE ───
  Future<void> leaveCall() async {
    // Гирифтани экран бо занг тамом мешавад (MediaProjection озод).
    if (_screen == ScreenCaptureStatus.starting ||
        _screen == ScreenCaptureStatus.active) {
      try { await _engine?.stopScreenCapture(); } catch (_) {}
    }
    _screen = ScreenCaptureStatus.idle;
    _viewingRemoteScreen = false;
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine       = null;
    _localJoined  = false;
    _remoteJoined = false;
    _remoteUid    = null;
    _muted        = false;
    _cameraOff    = false;
    _connState      = CallNetState.idle;
    _netQuality     = 0;
    _remoteFallback = false;
    _remoteDropped  = false;
    _audioRoute     = CallAudioRoute.unknown;
    _videoOn        = false;
    _dataSaver      = false;
    _blurOn         = false;
    _beautyOn       = false;
    notifyListeners();
  }

  // ─── ЗАНГ: ИЛОВАГӢ ───

  /// Аудио ↔ видео дар ҳамон канал (бе аз нав пайвастшавӣ).
  Future<void> setVideoEnabled(bool on) async {
    final e = _engine;
    if (e == null || on == _videoOn) return;
    if (on) await _requestPermissions(true);
    _videoOn = on;
    final sharing = _screen == ScreenCaptureStatus.active;
    try {
      if (on) {
        await e.enableVideo();
        // Шояд ҳангоми намоиши экран дар занги аудиоӣ хомӯш шуда бошад.
        await e.enableLocalVideo(true);
        await e.startPreview();
        _cameraOff = false;
        await e.muteLocalVideoStream(false);
      }
      // Ҳангоми намоиши экран камера нашр намешавад (як ҷараёни видео).
      await e.updateChannelMediaOptions(ChannelMediaOptions(
        publishCameraTrack: on && !sharing,
        autoSubscribeVideo: on || _viewingRemoteScreen,
      ));
      if (!on) {
        await e.stopPreview();
        // Модули видео барои экран (худ ё ҳамсӯҳбат) лозим аст.
        if (_screen == ScreenCaptureStatus.idle && !_viewingRemoteScreen) {
          await e.disableVideo();
        } else {
          await e.enableLocalVideo(false);
        }
      }
    } catch (err) {
      debugPrint('[Agora] setVideoEnabled($on): $err');
    }
    notifyListeners();
  }

  /// Камера дар паснамо таваққуф (бе тағйири интихоби корбар).
  Future<void> setCameraPaused(bool paused) async {
    try {
      await _engine?.enableLocalVideo(!paused);
    } catch (_) {}
  }

  /// Сарфаи интернет: видеои ҳамсӯҳбатро нагирифтан.
  Future<void> setDataSaver(bool on) async {
    _dataSaver = on;
    try {
      await _engine?.muteAllRemoteVideoStreams(on);
    } catch (_) {}
    notifyListeners();
  }

  /// Роҳи садо. Android — setRouteInCommunicationMode (Bluetooth →
  /// телефон ҳам); дигар ҷо — танҳо баландгӯяк ҳа/не.
  Future<void> setAudioRoute(CallAudioRoute r) async {
    final e = _engine;
    _speakerOn = r == CallAudioRoute.speaker;
    if (e != null) {
      try {
        if (defaultTargetPlatform == TargetPlatform.android &&
            r != CallAudioRoute.unknown) {
          await e.setRouteInCommunicationMode(agoraRouteOf(r));
        } else {
          await e.setEnableSpeakerphone(_speakerOn);
        }
      } catch (err) {
        debugPrint('[Agora] route: $err');
        try { await e.setEnableSpeakerphone(_speakerOn); } catch (_) {}
      }
    }
    notifyListeners();
  }

  /// AI-хомӯшкунии садои атроф (дар full-sdk ҳаст, калид намехоҳад).
  Future<bool> setNoiseSuppression(bool on) async {
    _ainsOn = on;
    var ok = true;
    try {
      await _engine?.setAINSMode(enabled: on, mode: AudioAinsMode.ainsModeBalanced);
    } catch (err) {
      debugPrint('[Agora] AINS: $err');
      ok = false;
      _ainsOn = false;
    }
    notifyListeners();
    return ok;
  }

  /// Хира кардани замина (virtual background, blur). Дастгоҳи заиф —
  /// false (Agora худаш намедиҳад).
  Future<bool> setBackgroundBlur(bool on) async {
    final e = _engine;
    if (e == null) return false;
    try {
      if (on && !await e.isFeatureAvailableOnDevice(
          FeatureType.videoVirtualBackground)) {
        return false;
      }
      await e.enableVirtualBackground(
        enabled: on,
        backgroundSource: const VirtualBackgroundSource(
          backgroundSourceType: BackgroundSourceType.backgroundBlur,
          blurDegree: BackgroundBlurDegree.blurDegreeHigh,
        ),
        segproperty: const SegmentationProperty(),
      );
      _blurOn = on;
      notifyListeners();
      return true;
    } catch (err) {
      debugPrint('[Agora] blur: $err');
      return false;
    }
  }

  /// Зебоии сабук (ҳамворӣ/равшанӣ) — дохили SDK, бе калид.
  Future<bool> setBeauty(bool on) async {
    final e = _engine;
    if (e == null) return false;
    try {
      if (on && !await e.isFeatureAvailableOnDevice(
          FeatureType.videoBeautyEffect)) {
        return false;
      }
      await e.setBeautyEffectOptions(
        enabled: on,
        options: const BeautyOptions(
          lighteningLevel: 0.5,
          smoothnessLevel: 0.5,
          rednessLevel: 0.1,
          sharpnessLevel: 0.2,
        ),
      );
      _beautyOn = on;
      notifyListeners();
      return true;
    } catch (err) {
      debugPrint('[Agora] beauty: $err');
      return false;
    }
  }

  // ─── НАМОИШИ ЭКРАН ───
  //
  // Android: Agora (full-screen-sharing) худаш равзанаи розигии система
  // (MediaProjection)-ро мекушояд, ПАС аз розигӣ хизматрасонии пешзаминаи
  // навъи mediaProjection-и худро (LocalScreenSharingService) оғоз мекунад
  // ва танҳо баъд гирифтанро сар мекунад — тартиби Android 14.
  // Огоҳиномаи он хизматрасонӣ аз MainActivity/ScreenShareNative меояд.
  //
  // Камера то оғози воқеии гирифтан нашр мешавад (ҳамсӯҳбат ҳангоми
  // равзанаи розигӣ экрани сиёҳ намебинад).

  /// Оғоз: розигии система → гирифтан. Натиҷа дар [screenCapture].
  Future<void> startScreenShare() async {
    final e = _engine;
    if (e == null ||
        _screen == ScreenCaptureStatus.starting ||
        _screen == ScreenCaptureStatus.active) {
      return;
    }
    _screen = ScreenCaptureStatus.starting;
    notifyListeners();
    try {
      if (!_videoOn) {
        // Занги аудиоӣ: модули видео барои ҷараёни экран лозим, камера — не.
        await e.enableVideo();
        await e.enableLocalVideo(false);
      }
      await e.startScreenCapture(const ScreenCaptureParameters2(
        captureVideo: true,
        captureAudio: false,
        videoParams: ScreenVideoParameters(
          dimensions: VideoDimensions(width: 720, height: 1280),
          frameRate: 15,
          contentHint: VideoContentHint.contentHintDetails,
        ),
      ));
    } catch (err) {
      debugPrint('[Agora] startScreenCapture: $err');
      _screen = ScreenCaptureStatus.failed;
      notifyListeners();
      unawaited(_restoreAfterScreen());
    }
  }

  /// Қатъ ва баргардонидани камера (агар занги видеоӣ бошад).
  Future<void> stopScreenShare() async {
    final e = _engine;
    final was = _screen;
    if (was == ScreenCaptureStatus.idle) return;
    _screen = ScreenCaptureStatus.idle;
    notifyListeners();
    if (e == null) return;
    if (was == ScreenCaptureStatus.starting ||
        was == ScreenCaptureStatus.active) {
      try {
        await e.stopScreenCapture();
      } catch (err) {
        debugPrint('[Agora] stopScreenCapture: $err');
      }
    }
    await _restoreAfterScreen();
  }

  /// Ҳамсӯҳбат экран нишон медиҳад: дар занги аудиоӣ видеоро мегирем
  /// (камераи худ хомӯш), сарфаи интернет барои экран муваққатан не.
  Future<void> setRemoteScreenViewing(bool on) async {
    final e = _engine;
    if (e == null || on == _viewingRemoteScreen) return;
    _viewingRemoteScreen = on;
    try {
      if (on) {
        if (!_videoOn && _screen == ScreenCaptureStatus.idle) {
          await e.enableVideo();
          await e.enableLocalVideo(false);
        }
        await e.updateChannelMediaOptions(
            const ChannelMediaOptions(autoSubscribeVideo: true));
        final uid = _remoteUid;
        if (uid != null) {
          await e.muteRemoteVideoStream(uid: uid, mute: false);
        }
        if (_dataSaver) await e.muteAllRemoteVideoStreams(false);
      } else {
        if (_dataSaver) await e.muteAllRemoteVideoStreams(true);
        if (!_videoOn) {
          await e.updateChannelMediaOptions(
              const ChannelMediaOptions(autoSubscribeVideo: false));
          if (_screen == ScreenCaptureStatus.idle) {
            await e.disableVideo();
            await e.enableLocalVideo(true);
          }
        }
      }
    } catch (err) {
      debugPrint('[Agora] remote screen($on): $err');
    }
    notifyListeners();
  }

  void _onScreenState(LocalVideoStreamState state, LocalVideoStreamReason reason) {
    debugPrint('[Agora] screen: ${state.name} (${reason.name})');
    if (state == LocalVideoStreamState.localVideoStreamStateCapturing ||
        state == LocalVideoStreamState.localVideoStreamStateEncoding) {
      if (_screen != ScreenCaptureStatus.starting) return;
      _screen = ScreenCaptureStatus.active;
      unawaited(_publishScreen());
      notifyListeners();
    } else if (state == LocalVideoStreamState.localVideoStreamStateFailed) {
      // Android: корбар розигиро рад кард ё MediaProjection оғоз нашуд.
      if (_screen != ScreenCaptureStatus.starting &&
          _screen != ScreenCaptureStatus.active) {
        return;
      }
      _screen = ScreenCaptureStatus.failed;
      unawaited(_restoreAfterScreen());
      notifyListeners();
    } else if (state == LocalVideoStreamState.localVideoStreamStateStopped) {
      // Система қатъ кард (масалан чипи «Қатъи намоиш»-и Android 14+).
      if (_screen != ScreenCaptureStatus.active) return;
      _screen = ScreenCaptureStatus.idle;
      unawaited(_restoreAfterScreen());
      notifyListeners();
    }
  }

  Future<void> _publishScreen() async {
    final e = _engine;
    if (e == null) return;
    try {
      // Камераи хомӯш (muteLocalVideoStream) экранро ҳам пинҳон мекард.
      if (_cameraOff) await e.muteLocalVideoStream(false);
      await e.updateChannelMediaOptions(const ChannelMediaOptions(
        publishScreenCaptureVideo: true,
        publishCameraTrack: false,
      ));
    } catch (err) {
      debugPrint('[Agora] publish screen: $err');
    }
  }

  Future<void> _restoreAfterScreen() async {
    final e = _engine;
    if (e == null) return;
    try {
      await e.updateChannelMediaOptions(ChannelMediaOptions(
        publishScreenCaptureVideo: false,
        publishCameraTrack: _videoOn,
      ));
      if (_videoOn) {
        await e.muteLocalVideoStream(_cameraOff);
      } else if (!_viewingRemoteScreen) {
        await e.disableVideo();
        await e.enableLocalVideo(true);
      }
    } catch (err) {
      debugPrint('[Agora] restore camera: $err');
    }
  }

  static int _q(QualityType q) => switch (q) {
        QualityType.qualityExcellent => 1,
        QualityType.qualityGood      => 2,
        QualityType.qualityPoor      => 3,
        QualityType.qualityBad       => 4,
        QualityType.qualityVbad      => 5,
        QualityType.qualityDown      => 6,
        _                            => 0,
      };

  // ─── CONTROLS ───
  Future<void> toggleMute() async {
    _muted = !_muted;
    await _engine?.muteLocalAudioStream(_muted);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    _cameraOff = !_cameraOff;
    // Ҳангоми намоиши экран muteLocalVideoStream экранро ҳам пинҳон
    // мекард — интихоб баъди қатъи намоиш татбиқ мешавад.
    if (_screen != ScreenCaptureStatus.active) {
      await _engine?.muteLocalVideoStream(_cameraOff);
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await _engine?.setEnableSpeakerphone(_speakerOn);
    notifyListeners();
  }

  Future<void> flipCamera() async {
    _frontCamera = !_frontCamera;
    await _engine?.switchCamera();
    notifyListeners();
  }

  // ─── HELPERS ───
  static bool _fatal(ErrorCodeType e) =>
      e == ErrorCodeType.errInvalidToken ||
      e == ErrorCodeType.errTokenExpired ||
      e == ErrorCodeType.errInvalidAppId ||
      e == ErrorCodeType.errInvalidChannelName ||
      e == ErrorCodeType.errJoinChannelRejected;

  static Future<void> _requestPermissions(bool isVideo) async {
    final perms = [Permission.microphone];
    if (isVideo) perms.add(Permission.camera);
    await perms.request();
  }

  /// Канал ва token-и занг аз сервер (POST /calls/token).
  ///
  /// Пештар канал "uuid_uuid" (73 аломат) буд — Agora танҳо то 64 байт
  /// қабул мекунад, бинобар ин занг ҳеҷ гоҳ пайваст намешуд. Номи
  /// кӯтоҳ ва token-ро (агар App Certificate фаъол бошад) сервер медиҳад.
  static Future<({String channel, String token})?> callCredentials(
      String peerId) async {
    try {
      final r = await ApiClient.instance.post('/calls/token',
          body: {'peerId': peerId});
      if (r.statusCode >= 400) return null;
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      final ch = (b['channel'] ?? '').toString();
      if (ch.isEmpty) return null;
      return (channel: ch, token: (b['token'] ?? '').toString());
    } catch (_) {
      return null;
    }
  }

  /// Token-и Live (ҳост — publisher, дигарон — тамошобин).
  static Future<String> liveToken(String streamId) async {
    try {
      final r = await ApiClient.instance.post('/live/$streamId/token');
      if (r.statusCode >= 400) return '';
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      return (b['token'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }
}
