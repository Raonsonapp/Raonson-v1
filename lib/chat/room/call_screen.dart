import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_theme.dart';
import '../../models/user_model.dart';
import '../../widgets/avatar.dart';
import '../../core/agora_service.dart';
import '../../core/webrtc_service.dart';
import '../../core/storage/token_storage.dart';
import '../../core/ui/app_icons.dart';
import '../chat_repository.dart';
import '../../core/i18n/strings.dart';

enum CallType { voice, video }

class CallScreen extends StatefulWidget {
  final UserModel peer;
  final CallType  callType;
  final bool      isIncoming;
  final bool      peerIsOnline;

  const CallScreen({
    super.key,
    required this.peer,
    required this.callType,
    this.isIncoming   = false,
    this.peerIsOnline = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final _agora  = AgoraService();
  final _signal = WebRTCService();
  final _player = AudioPlayer();
  final _repo   = ChatRepository();

  int    _seconds = 0;
  Timer? _timer;
  bool   _everConnected = false; // ягон бор пайваст шуд?
  bool   _logged        = false; // паёми занг сабт шуд?

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _agora.addListener(_onAgoraChange);
    _signal.onCallEnded    = _onRemoteEnded;
    _signal.onCallDeclined = _onDeclined;

    // Caller side only — play outgoing ring
    if (!widget.isIncoming) _playOutgoingRing();
    _joinAgora();
  }

  // ── AUDIO ──

  Future<void> _playOutgoingRing() async {
    try {
      // ringtone.wav = ringing sound (loop until answered/declined)
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/ringtone.wav'));
    } catch (e) {
      debugPrint('[CallScreen] audio error: $e');
    }
  }

  Future<void> _playConnectSound() async {
    try {
      // connect.wav = short "connected" beep — plays once
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(AssetSource('sounds/connect.wav'));
    } catch (e) {
      debugPrint('[CallScreen] connect sound error: $e');
    }
  }

  Future<void> _stopRing() async {
    try { await _player.stop(); } catch (_) {}
  }

  // ── AGORA ──

  void _onAgoraChange() {
    if (_agora.remoteJoined) _everConnected = true;
    if (!mounted) return;
    if (_agora.remoteJoined && _timer == null) {
      _stopRing().then((_) => _playConnectSound());
      _startTimer();
    }
    setState(() {});
  }

  Future<void> _joinAgora() async {
    if (kAgoraAppId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('ui.cce2a178f1')),
            backgroundColor: Colors.red, duration: Duration(seconds: 3)));
        Navigator.pop(context);
      }
      return;
    }
    final myId    = await TokenStorage.getUserId() ?? '';
    final channel = AgoraService.channelName(myId, widget.peer.id);
    await _agora.joinCall(channelName: channel, isVideo: widget.callType == CallType.video);
    if (widget.isIncoming) _signal.sendAnswered(widget.peer.id);
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _timeLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusText {
    if (_connected)           return _timeLabel;
    if (widget.isIncoming)    return 'Пайваст мешавад...';
    return widget.peerIsOnline ? 'Пайваст мешавад...' : 'Занг мезанад...';
  }

  // ── CALL ACTIONS ──

  // Танҳо тарафи зангзананда (на қабулкунанда) як паёми занг ба чат сабт
  // мекунад — то ҳарду тараф онро бубинанд (мисли Instagram).
  void _logCall() {
    if (_logged || widget.isIncoming) return;
    _logged = true;
    final kind   = widget.callType == CallType.video ? 'video' : 'audio';
    final status = _everConnected ? 'ended' : 'missed';
    _repo.sendMessage(
      toUserId:  widget.peer.id,
      text:      '$status:$kind:$_seconds',
      mediaType: 'call',
    ).then((_) {}, onError: (_) {});
  }

  Future<void> _endCall() async {
    _logCall();
    await _stopRing();
    _signal.sendEnd(widget.peer.id);
    _agora.leaveCall();
    if (mounted) Navigator.pop(context);
  }

  void _onRemoteEnded() {
    _logCall();
    _stopRing();
    _agora.leaveCall();
    if (mounted) Navigator.pop(context);
  }

  void _onDeclined() {
    _logCall();
    _stopRing();
    _agora.leaveCall();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('ui.30bcc62c44'))));
    Navigator.pop(context);
  }

  bool get _connected => _agora.remoteJoined;

  @override
  void dispose() {
    _logCall(); // safety net — агар бо роҳи дигар пӯшида шавад
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _agora.removeListener(_onAgoraChange);
    _signal.onCallEnded    = null;
    _signal.onCallDeclined = null;
    _player.dispose();
    _timer?.cancel();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════ BUILD ══════════════════════════════

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: FadeTransition(
      opacity: _fadeAnim,
      child: widget.callType == CallType.video ? _buildVideo() : _buildVoice(),
    ),
  );

  // ══════════════════ VOICE UI ══════════════════

  Widget _buildVoice() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF050914), Color(0xFF0D1B3E), Color(0xFF050914)],
      ),
    ),
    child: SafeArea(child: Column(children: [
      const SizedBox(height: 60),
      Text(_statusText,
          style: TextStyle(
              color: AppColors.textPrimary.withOpacity(0.65), fontSize: 16, letterSpacing: 1.2)),
      const SizedBox(height: 48),
      Stack(alignment: Alignment.center, children: [
        if (!_connected) ...[_ring(180, 0.04), _ring(150, 0.08), _ring(120, 0.13)],
        ScaleTransition(
          scale: _connected ? const AlwaysStoppedAnimation(1.0) : _pulseAnim,
          child: Container(
            width: 112, height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.neonBlue.withOpacity(0.5), width: 2),
              boxShadow: [BoxShadow(
                  color: AppColors.neonBlue.withOpacity(0.35), blurRadius: 32, spreadRadius: 4)],
            ),
            child: ClipOval(
                child: Avatar(imageUrl: widget.peer.avatar, size: 112, glowBorder: false)),
          ),
        ),
      ]),
      const SizedBox(height: 28),
      Text(widget.peer.username,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (_connected) _connectedBadge(),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Btn(
            icon:   _agora.muted ? AppIcons.mic_off_rounded : AppIcons.mic_rounded,
            label:  _agora.muted ? 'Кушо' : 'Бандош',
            active: _agora.muted,
            onTap:  _agora.toggleMute,
          ),
          _EndBtn(onTap: _endCall),
          _Btn(
            icon:   _agora.speakerOn ? AppIcons.volume_up_rounded : AppIcons.volume_down_rounded,
            label:  tr('ui.ce3cad995c'),
            active: _agora.speakerOn,
            onTap:  _agora.toggleSpeaker,
          ),
        ]),
      ),
      const SizedBox(height: 56),
    ])),
  );

  // ══════════════════ VIDEO UI ══════════════════

  Widget _buildVideo() => Stack(children: [
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
              decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF050914), Color(0xFF0D1B3E)],
              )),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                ScaleTransition(scale: _pulseAnim,
                    child: Avatar(imageUrl: widget.peer.avatar, size: 120, glowBorder: true)),
                const SizedBox(height: 16),
                Text(_statusText,
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 15)),
              ])),
            ),
    ),

    if (!_agora.cameraOff && _agora.engine != null)
      Positioned(right: 16, top: 90,
        child: Container(
          width: 100, height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textFaint),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16)],
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

    SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        IconButton(
          icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
          onPressed: _endCall,
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(widget.peer.username,
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
          Text(_statusText,
              style: TextStyle(color: AppColors.textPrimary.withOpacity(0.6), fontSize: 13)),
        ])),
        const SizedBox(width: 48),
      ]),
    )),

    Positioned(bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 52),
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.88), Colors.transparent],
        )),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Btn(icon: _agora.muted ? AppIcons.mic_off_rounded : AppIcons.mic_rounded,
              label: tr('ui.485bf9ddc4'), active: _agora.muted, onTap: _agora.toggleMute),
          _Btn(icon: _agora.cameraOff ? AppIcons.videocam_off_rounded : AppIcons.videocam_rounded,
              label: tr('ui.a71a775fd9'), active: _agora.cameraOff, onTap: _agora.toggleCamera),
          _EndBtn(onTap: _endCall),
          _Btn(icon: AppIcons.flip_camera_ios_rounded,
              label: tr('ui.05a19ea7d3'), active: false, onTap: _agora.flipCamera),
          _Btn(icon: _agora.speakerOn ? AppIcons.volume_up_rounded : AppIcons.volume_off_rounded,
              label: tr('ui.ce3cad995c'), active: _agora.speakerOn, onTap: _agora.toggleSpeaker),
        ]),
      ),
    ),
  ]);

  Widget _ring(double s, double o) => Container(
    width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle,
        border: Border.all(color: AppColors.neonBlue.withOpacity(o), width: 1.5)),
  );

  Widget _connectedBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.green.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.green.withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(AppIcons.circle, color: Colors.green, size: 8),
      SizedBox(width: 6),
      Text(tr('ui.bbd96268bb'), style: TextStyle(color: Colors.green, fontSize: 13)),
    ]),
  );
}

// ─── Buttons ───

class _Btn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;
  _Btn({required this.icon, required this.label,
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
              : AppColors.textPrimary.withOpacity(0.12),
          border: Border.all(
              color: active ? AppColors.neonBlue.withOpacity(0.6) : AppColors.textFaint),
        ),
        child: Icon(icon,
            color: active ? AppColors.neonBlue : AppColors.textPrimary, size: 24),
      ),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
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
        child: Icon(AppIcons.call_end_rounded, color: AppColors.textPrimary, size: 32),
      ),
      const SizedBox(height: 6),
      Text(tr('ui.f0718687b4'), style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ]),
  );
}
