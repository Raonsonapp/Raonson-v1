import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

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

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        debugPrint('[Agora] Local joined: ${connection.channelId}');
        _localJoined = true;
        notifyListeners();
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        debugPrint('[Agora] Remote joined: $remoteUid');
        _remoteUid    = remoteUid;
        _remoteJoined = true;
        notifyListeners();
      },
      onUserOffline: (connection, remoteUid, reason) {
        debugPrint('[Agora] Remote left: $remoteUid');
        _remoteUid    = null;
        _remoteJoined = false;
        notifyListeners();
      },
      onError: (err, msg) {
        debugPrint('[Agora] Error $err: $msg');
        if (_fatal(err)) { _error = err.name; notifyListeners(); }
      },
      onConnectionStateChanged: (connection, state, reason) {
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
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine       = null;
    _localJoined  = false;
    _remoteJoined = false;
    _remoteUid    = null;
    _muted        = false;
    _cameraOff    = false;
    notifyListeners();
  }

  // ─── CONTROLS ───
  Future<void> toggleMute() async {
    _muted = !_muted;
    await _engine?.muteLocalAudioStream(_muted);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    _cameraOff = !_cameraOff;
    await _engine?.muteLocalVideoStream(_cameraOff);
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
