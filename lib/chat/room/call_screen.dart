import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../app/app_theme.dart';
import '../../models/user_model.dart';
import '../../widgets/avatar.dart';
import '../../core/webrtc_service.dart';
import '../../core/storage/token_storage.dart';

enum CallType { voice, video }

enum CallState { calling, connected, ended }

class CallScreen extends StatefulWidget {
  final UserModel peer;
  final CallType callType;
  final bool isIncoming;
  final Map<String, dynamic>? offerData;

  const CallScreen({
    super.key,
    required this.peer,
    required this.callType,
    this.isIncoming = false,
    this.offerData,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with TickerProviderStateMixin {
  final _webrtc = WebRTCService();

  final _localRenderer  = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  CallState _callState = CallState.calling;
  int _seconds = 0;
  Timer? _timer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initRenderers();
    _setupCallbacks();

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    if (!widget.isIncoming) {
      _startCall();
    } else {
      _answerCall();
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupCallbacks() {
    _webrtc.onRemoteStream = (stream) {
      if (!mounted) return;
      setState(() {
        _remoteRenderer.srcObject = stream;
        _callState = CallState.connected;
      });
      _startTimer();
    };

    _webrtc.onCallEnded = () {
      if (mounted) Navigator.pop(context);
    };

    _webrtc.onCallDeclined = () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call declined')),
        );
        Navigator.pop(context);
      }
    };
  }

  Future<void> _startCall() async {
    final myId       = await TokenStorage.getUserId() ?? '';
    final myUsername = ''; // Optional
    _webrtc.setPeerId(widget.peer.id);

    await _webrtc.startCall(
      toUserId:     widget.peer.id,
      isVideo:      widget.callType == CallType.video,
      fromUserId:   myId,
      fromUsername: myUsername,
      fromAvatar:   '',
    );

    if (_webrtc.localStream != null) {
      setState(() => _localRenderer.srcObject = _webrtc.localStream);
    }
  }

  Future<void> _answerCall() async {
    _webrtc.setPeerId(widget.peer.id);
    await _webrtc.answerCall(
      offerData: widget.offerData!,
      fromUserId: widget.peer.id,
      isVideo: widget.callType == CallType.video,
    );
    if (_webrtc.localStream != null) {
      setState(() => _localRenderer.srcObject = _webrtc.localStream);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _timeLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _endCall() {
    _webrtc.endCall(widget.peer.id);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer?.cancel();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _webrtc,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.black,
        body: widget.callType == CallType.video
            ? _buildVideo()
            : _buildVoice(),
      ),
    );
  }

  // ══════════════════ VOICE CALL ══════════════════

  Widget _buildVoice() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050914), Color(0xFF0D1B3E), Color(0xFF050914)],
        ),
      ),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            Positioned(
              top: -100, left: -100,
              child: Container(
                width: 400, height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.neonBlue.withOpacity(0.15),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Text(
                    _callState == CallState.connected
                        ? _timeLabel
                        : (widget.isIncoming ? 'Connecting...' : 'Calling...'),
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, letterSpacing: 1),
                  ),
                  const SizedBox(height: 40),
                  ScaleTransition(
                    scale: _callState == CallState.calling ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_callState == CallState.calling) ...[
                          _ring(160, 0.06),
                          _ring(140, 0.1),
                          _ring(120, 0.15),
                        ],
                        Container(
                          width: 110, height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.neonBlue.withOpacity(0.6), width: 2),
                            boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)],
                          ),
                          child: ClipOval(
                            child: Avatar(imageUrl: widget.peer.avatar, size: 110, glowBorder: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    widget.peer.username,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_callState == CallState.connected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 8),
                          SizedBox(width: 6),
                          Text('Connected', style: TextStyle(color: Colors.green, fontSize: 13)),
                        ],
                      ),
                    ),
                  const Spacer(),
                  _voiceControls(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════ VIDEO CALL ══════════════════

  Widget _buildVideo() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // Remote video
          Positioned.fill(
            child: _callState == CallState.connected && _webrtc.remoteStream != null
                ? RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF050914), Color(0xFF0D1B3E)],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaleTransition(scale: _pulseAnim,
                            child: Avatar(imageUrl: widget.peer.avatar, size: 120, glowBorder: true)),
                          const SizedBox(height: 16),
                          Text(
                            widget.isIncoming ? 'Connecting...' : 'Calling...',
                            style: const TextStyle(color: Colors.white54, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Local video (top right)
          if (!_webrtc.cameraOff && _webrtc.localStream != null)
            Positioned(
              right: 16, top: 80,
              child: Container(
                width: 100, height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RTCVideoView(_localRenderer, mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(widget.peer.username,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                        Text(
                          _callState == CallState.connected ? _timeLabel : 'Calling...',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 50),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                ),
              ),
              child: _videoControls(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.neonBlue.withOpacity(opacity), width: 1.5),
    ),
  );

  Widget _voiceControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlBtn(
            icon: _webrtc.muted ? Icons.mic_off : Icons.mic,
            label: _webrtc.muted ? 'Unmute' : 'Mute',
            active: _webrtc.muted,
            onTap: _webrtc.toggleMute,
          ),
          _EndCallBtn(onTap: _endCall),
          _ControlBtn(
            icon: _webrtc.speakerOn ? Icons.volume_up : Icons.volume_down,
            label: 'Speaker',
            active: _webrtc.speakerOn,
            onTap: _webrtc.toggleSpeaker,
          ),
        ],
      ),
    );
  }

  Widget _videoControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlBtn(icon: _webrtc.muted ? Icons.mic_off : Icons.mic,
            label: 'Mute', active: _webrtc.muted, onTap: _webrtc.toggleMute),
        _ControlBtn(icon: _webrtc.cameraOff ? Icons.videocam_off : Icons.videocam,
            label: 'Camera', active: _webrtc.cameraOff, onTap: _webrtc.toggleCamera),
        _EndCallBtn(onTap: _endCall),
        _ControlBtn(icon: Icons.flip_camera_ios,
            label: 'Flip', active: false, onTap: () => _webrtc.flipCamera()),
        _ControlBtn(icon: _webrtc.speakerOn ? Icons.volume_up : Icons.volume_off,
            label: 'Speaker', active: _webrtc.speakerOn, onTap: _webrtc.toggleSpeaker),
      ],
    );
  }
}

// ── Reusable control buttons ──

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ControlBtn({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.neonBlue.withOpacity(0.3) : Colors.white.withOpacity(0.12),
              border: Border.all(color: active ? AppColors.neonBlue.withOpacity(0.5) : Colors.white24),
            ),
            child: Icon(icon, color: active ? AppColors.neonBlue : Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}

class _EndCallBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _EndCallBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF3B55),
              boxShadow: [BoxShadow(color: const Color(0xFFFF3B55).withOpacity(0.5), blurRadius: 20, spreadRadius: 2)],
            ),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 6),
          const Text('End', style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
