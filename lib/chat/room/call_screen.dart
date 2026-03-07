import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_theme.dart';
import '../../models/user_model.dart';
import '../../widgets/avatar.dart';
import '../../core/agora_service.dart';
import '../../core/webrtc_service.dart';
import '../../core/storage/token_storage.dart';

enum CallType { voice, video }

class CallScreen extends StatefulWidget {
  final UserModel peer;
  final CallType  callType;
  final bool      isIncoming;

  const CallScreen({
    super.key,
    required this.peer,
    required this.callType,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with TickerProviderStateMixin {
  final _agora  = AgoraService();
  final _signal = WebRTCService();

  int    _seconds = 0;
  Timer? _timer;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _agora.addListener(_onAgoraChange);

    // Signal callbacks
    _signal.onCallEnded    = _onRemoteEnded;
    _signal.onCallDeclined = _onDeclined;

    _joinAgora();
  }

  void _onAgoraChange() {
    if (!mounted) return;
    setState(() {});
    // Start timer once the other person joins
    if (_agora.remoteJoined && _timer == null) _startTimer();
  }

  Future<void> _joinAgora() async {
    final myId    = await TokenStorage.getUserId() ?? '';
    final channel = AgoraService.channelName(myId, widget.peer.id);

    await _agora.joinCall(
      channelName: channel,
      isVideo:     widget.callType == CallType.video,
    );

    // Tell caller we answered (only callee does this)
    if (widget.isIncoming) {
      _signal.sendAnswered(widget.peer.id);
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
    _signal.sendEnd(widget.peer.id);
    _agora.leaveCall();
    Navigator.pop(context);
  }

  void _onRemoteEnded() {
    _agora.leaveCall();
    if (mounted) Navigator.pop(context);
  }

  void _onDeclined() {
    _agora.leaveCall();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Call declined')));
    Navigator.pop(context);
  }

  bool get _connected => _agora.remoteJoined;

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _agora.removeListener(_onAgoraChange);
    _signal.onCallEnded    = null;
    _signal.onCallDeclined = null;
    _timer?.cancel();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: FadeTransition(
      opacity: _fadeAnim,
      child: widget.callType == CallType.video ? _buildVideo() : _buildVoice(),
    ),
  );

  // ══════════════════ VOICE UI ══════════════════

  Widget _buildVoice() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF050914), Color(0xFF0D1B3E), Color(0xFF050914)],
      ),
    ),
    child: SafeArea(child: Column(children: [
      const SizedBox(height: 60),
      Text(
        _connected
            ? _timeLabel
            : (widget.isIncoming ? 'Connecting...' : 'Calling...'),
        style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 16, letterSpacing: 1.2),
      ),
      const SizedBox(height: 48),
      Stack(alignment: Alignment.center, children: [
        if (!_connected) ...[_ring(180, 0.04), _ring(150, 0.08), _ring(120, 0.13)],
        ScaleTransition(
          scale: _connected
              ? const AlwaysStoppedAnimation(1.0)
              : _pulseAnim,
          child: Container(
            width: 112, height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.neonBlue.withOpacity(0.5), width: 2),
              boxShadow: [BoxShadow(
                  color: AppColors.neonBlue.withOpacity(0.35),
                  blurRadius: 32, spreadRadius: 4)],
            ),
            child: ClipOval(
              child: Avatar(imageUrl: widget.peer.avatar, size: 112, glowBorder: false),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 28),
      Text(widget.peer.username,
          style: const TextStyle(
              color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (_connected) _connectedBadge(),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Btn(
              icon:   _agora.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label:  _agora.muted ? 'Unmute' : 'Mute',
              active: _agora.muted,
              onTap:  _agora.toggleMute),
          _EndBtn(onTap: _endCall),
          _Btn(
              icon:   _agora.speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
              label:  'Speaker',
              active: _agora.speakerOn,
              onTap:  _agora.toggleSpeaker),
        ]),
      ),
      const SizedBox(height: 56),
    ])),
  );

  // ══════════════════ VIDEO UI ══════════════════

  Widget _buildVideo() => Stack(children: [
    // Remote video — full screen
    Positioned.fill(
      child: _connected && _agora.remoteUid != null && _agora.engine != null
          ? AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine:  _agora.engine!,
                canvas:     VideoCanvas(uid: _agora.remoteUid!),
                connection: RtcConnection(channelId: _agora.channelId),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF050914), Color(0xFF0D1B3E)],
                ),
              ),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Avatar(imageUrl: widget.peer.avatar, size: 120, glowBorder: true),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isIncoming ? 'Connecting...' : 'Calling...',
                  style: const TextStyle(color: Colors.white54, fontSize: 15),
                ),
              ])),
            ),
    ),

    // Local camera — top right
    if (!_agora.cameraOff && _agora.engine != null)
      Positioned(
        right: 16, top: 90,
        child: Container(
          width: 100, height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16)
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _agora.engine!,
                canvas: const VideoCanvas(uid: 0),
              ),
            ),
          ),
        ),
      ),

    // Top bar
    SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(widget.peer.username,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
            Text(
              _connected ? _timeLabel : 'Calling...',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
          ],
        )),
        const SizedBox(width: 48),
      ]),
    )),

    // Bottom controls
    Positioned(bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 52),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.88), Colors.transparent],
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Btn(icon: _agora.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: 'Mute', active: _agora.muted, onTap: _agora.toggleMute),
          _Btn(icon: _agora.cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
              label: 'Camera', active: _agora.cameraOff, onTap: _agora.toggleCamera),
          _EndBtn(onTap: _endCall),
          _Btn(icon: Icons.flip_camera_ios_rounded,
              label: 'Flip', active: false, onTap: _agora.flipCamera),
          _Btn(icon: _agora.speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              label: 'Speaker', active: _agora.speakerOn, onTap: _agora.toggleSpeaker),
        ]),
      ),
    ),
  ]);

  Widget _ring(double s, double o) => Container(
    width: s, height: s,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.neonBlue.withOpacity(o), width: 1.5),
    ),
  );

  Widget _connectedBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.green.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.green.withOpacity(0.4)),
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, color: Colors.green, size: 8),
      SizedBox(width: 6),
      Text('Connected', style: TextStyle(color: Colors.green, fontSize: 13)),
    ]),
  );
}

// ─── Buttons ───

class _Btn extends StatelessWidget {
  final IconData    icon;
  final String      label;
  final bool        active;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.label,
      required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 58, height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppColors.neonBlue.withOpacity(0.3)
              : Colors.white.withOpacity(0.12),
          border: Border.all(
              color: active
                  ? AppColors.neonBlue.withOpacity(0.6)
                  : Colors.white24),
        ),
        child: Icon(icon,
            color: active ? AppColors.neonBlue : Colors.white, size: 24),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]),
  );
}

class _EndBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _EndBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFF3B55),
          boxShadow: [BoxShadow(
              color: const Color(0xFFFF3B55).withOpacity(0.55),
              blurRadius: 22, spreadRadius: 2)],
        ),
        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
      ),
      const SizedBox(height: 6),
      const Text('End', style: TextStyle(color: Colors.white60, fontSize: 11)),
    ]),
  );
}
