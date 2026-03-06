import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/storage/token_storage.dart';

typedef OnRemoteStream = void Function(MediaStream stream);
typedef OnCallEnded = void Function();
typedef OnCallDeclined = void Function();

class WebRTCService extends ChangeNotifier {
  static final WebRTCService _i = WebRTCService._();
  factory WebRTCService() => _i;
  WebRTCService._();

  io.Socket? _socket;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  bool _muted       = false;
  bool _speakerOn   = false;
  bool _cameraOff   = false;
  bool _isConnected = false;

  bool get muted       => _muted;
  bool get speakerOn   => _speakerOn;
  bool get cameraOff   => _cameraOff;
  bool get isConnected => _isConnected;

  MediaStream? get localStream  => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  OnRemoteStream? onRemoteStream;
  OnCallEnded?    onCallEnded;
  OnCallDeclined? onCallDeclined;

  // ── STUN servers (Google free) ──
  static const _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  // ─────────────── CONNECT SOCKET ───────────────
  Future<void> connect() async {
    if (_socket?.connected == true) return;

    _socket = io.io(
      'https://raonson-v1.onrender.com',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();
    _socket!.onConnect((_) async {
      final uid = await TokenStorage.getUserId();
      if (uid != null && uid.isNotEmpty) {
        _socket!.emit('user:register', uid);
      }
    });

    // ── Incoming events ──
    _socket!.on('call:answered', (data) async {
      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );
      await _pc?.setRemoteDescription(answer);
    });

    _socket!.on('call:ice-candidate', (data) async {
      if (data['candidate'] == null) return;
      await _pc?.addCandidate(RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      ));
    });

    _socket!.on('call:ended', (_) {
      _isConnected = false;
      notifyListeners();
      onCallEnded?.call();
      dispose();
    });

    _socket!.on('call:declined', (_) {
      onCallDeclined?.call();
      dispose();
    });
  }

  // ─────────────── START CALL (caller) ───────────────
  Future<void> startCall({
    required String toUserId,
    required bool isVideo,
    required String fromUserId,
    required String fromUsername,
    required String fromAvatar,
  }) async {
    await connect();
    await _initLocalStream(isVideo);
    await _createPeerConnection();

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    _socket!.emit('call:offer', {
      'to':           toUserId,
      'from':         fromUserId,
      'fromUsername': fromUsername,
      'fromAvatar':   fromAvatar,
      'callType':     isVideo ? 'video' : 'voice',
      'offer': {
        'sdp':  offer.sdp,
        'type': offer.type,
      },
    });
  }

  // ─────────────── ANSWER CALL (callee) ───────────────
  Future<void> answerCall({
    required Map<String, dynamic> offerData,
    required String fromUserId,
    required bool isVideo,
  }) async {
    await connect();
    await _initLocalStream(isVideo);
    await _createPeerConnection();

    final offer = RTCSessionDescription(
      offerData['sdp'],
      offerData['type'],
    );
    await _pc!.setRemoteDescription(offer);

    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    _socket!.emit('call:answer', {
      'to': fromUserId,
      'answer': {
        'sdp':  answer.sdp,
        'type': answer.type,
      },
    });
  }

  // ─────────────── DECLINE ───────────────
  void declineCall(String fromUserId) {
    _socket?.emit('call:decline', {'to': fromUserId});
    dispose();
  }

  // ─────────────── END CALL ───────────────
  void endCall(String peerId) {
    _socket?.emit('call:end', {'to': peerId});
    dispose();
  }

  // ─────────────── CONTROLS ───────────────
  void toggleMute() {
    _muted = !_muted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_muted);
    notifyListeners();
  }

  void toggleCamera() {
    _cameraOff = !_cameraOff;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !_cameraOff);
    notifyListeners();
  }

  void toggleSpeaker() {
    _speakerOn = !_speakerOn;
    // platform-specific speaker toggle handled by WebRTC
    notifyListeners();
  }

  Future<void> flipCamera() async {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      await Helper.switchCamera(tracks.first);
    }
  }

  // ─────────────── PRIVATE HELPERS ───────────────
  Future<void> _initLocalStream(bool isVideo) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo
          ? {'facingMode': 'user', 'width': 640, 'height': 480}
          : false,
    });
  }

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection(_iceConfig);

    // Add local tracks
    _localStream?.getTracks().forEach((track) {
      _pc!.addTrack(track, _localStream!);
    });

    // Remote stream
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _isConnected  = true;
        notifyListeners();
        onRemoteStream?.call(_remoteStream!);
      }
    };

    // ICE candidates
    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      // We need peerId here - store it
      _socket?.emit('call:ice-candidate', {
        'to': _peerId,
        'candidate': {
          'candidate':     candidate.candidate,
          'sdpMid':        candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    _pc!.onConnectionState = (state) {
      debugPrint('[WebRTC] state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _isConnected = true;
        notifyListeners();
      }
    };
  }

  String? _peerId;
  void setPeerId(String id) => _peerId = id;

  @override
  void dispose() {
    _localStream?.dispose();
    _remoteStream?.dispose();
    _pc?.close();
    _localStream  = null;
    _remoteStream = null;
    _pc           = null;
    _isConnected  = false;
    _muted        = false;
    _cameraOff    = false;
    super.dispose();
  }
}
