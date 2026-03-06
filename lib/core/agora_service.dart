import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

const String kAgoraAppId = '218a590a5be54f81aa4b95e4cb9bb267';

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
  Future<void> joinCall({
    required String channelName,
    required bool   isVideo,
  }) async {
    await _requestPermissions(isVideo);

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
      onError: (err, msg) => debugPrint('[Agora] Error $err: $msg'),
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
      token:     '',
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
  static Future<void> _requestPermissions(bool isVideo) async {
    final perms = [Permission.microphone];
    if (isVideo) perms.add(Permission.camera);
    await perms.request();
  }

  /// Channel = sorted user IDs joined by "_" (same as chatId)
  static String channelName(String uid1, String uid2) =>
      ([uid1, uid2]..sort()).join('_');
}
