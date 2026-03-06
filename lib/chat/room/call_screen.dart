import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_theme.dart';
import '../../models/user_model.dart';
import '../../widgets/avatar.dart';

enum CallType { voice, video }
enum CallState { calling, connected, ended }

class CallScreen extends StatefulWidget {
  final UserModel peer;
  final CallType callType;
  final bool isIncoming;

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
  CallState _callState = CallState.calling;
  bool _muted = false;
  bool _speakerOn = false;
  bool _cameraOff = false;
  bool _frontCamera = true;
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

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    if (!widget.isIncoming) _simulateConnect();
  }

  void _simulateConnect() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _callState = CallState.connected);
        _startTimer();
      }
    });
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

  void _accept() {
    setState(() => _callState = CallState.connected);
    _startTimer();
  }

  void _endCall() {
    _timer?.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer?.cancel();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: widget.callType == CallType.video
          ? _buildVideo()
          : _buildVoice(),
    );
  }

  // ═══════════════════════ VOICE CALL ═══════════════════════

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
            // Background glow
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.neonBlue.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // Status
                  Text(
                    _callState == CallState.calling
                        ? (widget.isIncoming ? 'Incoming call...' : 'Calling...')
                        : _timeLabel,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Avatar with pulse
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
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.neonBlue.withOpacity(0.6),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonBlue.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Avatar(
                              imageUrl: widget.peer.avatar,
                              size: 110,
                              glowBorder: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Name
                  Text(
                    widget.peer.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
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
                  // Controls
                  if (_callState == CallState.connected)
                    _voiceControls()
                  else if (widget.isIncoming)
                    _incomingControls()
                  else
                    _callingControl(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: AppColors.neonBlue.withOpacity(opacity),
        width: 1.5,
      ),
    ),
  );

  Widget _voiceControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlBtn(
            icon: _muted ? Icons.mic_off : Icons.mic,
            label: _muted ? 'Unmute' : 'Mute',
            active: _muted,
            onTap: () => setState(() => _muted = !_muted),
          ),
          _EndCallBtn(onTap: _endCall),
          _ControlBtn(
            icon: _speakerOn ? Icons.volume_up : Icons.volume_down,
            label: 'Speaker',
            active: _speakerOn,
            onTap: () => setState(() => _speakerOn = !_speakerOn),
          ),
        ],
      ),
    );
  }

  Widget _incomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _DeclineBtn(onTap: _endCall),
        _AcceptBtn(onTap: _accept),
      ],
    );
  }

  Widget _callingControl() {
    return Center(child: _EndCallBtn(onTap: _endCall));
  }

  // ═══════════════════════ VIDEO CALL ═══════════════════════

  Widget _buildVideo() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // Remote video (black placeholder with peer avatar)
          Positioned.fill(
            child: _callState == CallState.connected
                ? Container(
                    color: const Color(0xFF0A0A0A),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Avatar(imageUrl: widget.peer.avatar, size: 80, glowBorder: true),
                          const SizedBox(height: 12),
                          const Text('Camera connecting...', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF050914), Color(0xFF0D1B3E)],
                      ),
                    ),
                    child: Center(
                      child: ScaleTransition(
                        scale: _pulseAnim,
                        child: Avatar(imageUrl: widget.peer.avatar, size: 120, glowBorder: true),
                      ),
                    ),
                  ),
          ),

          // Local video preview (bottom right)
          if (_callState == CallState.connected && !_cameraOff)
            Positioned(
              right: 16,
              top: 80,
              child: Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: const Center(
                    child: Icon(Icons.person, color: Colors.white24, size: 40),
                  ),
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
                          _callState == CallState.calling
                              ? (widget.isIncoming ? 'Incoming video call...' : 'Calling...')
                              : _timeLabel,
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
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 50),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                ),
              ),
              child: _callState == CallState.connected
                  ? _videoControls()
                  : widget.isIncoming
                      ? _incomingControls()
                      : _callingControl(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlBtn(
          icon: _muted ? Icons.mic_off : Icons.mic,
          label: _muted ? 'Unmute' : 'Mute',
          active: _muted,
          onTap: () => setState(() => _muted = !_muted),
        ),
        _ControlBtn(
          icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
          label: _cameraOff ? 'Start video' : 'Stop video',
          active: _cameraOff,
          onTap: () => setState(() => _cameraOff = !_cameraOff),
        ),
        _EndCallBtn(onTap: _endCall),
        _ControlBtn(
          icon: Icons.flip_camera_ios,
          label: 'Flip',
          active: false,
          onTap: () => setState(() => _frontCamera = !_frontCamera),
        ),
        _ControlBtn(
          icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
          label: 'Speaker',
          active: _speakerOn,
          onTap: () => setState(() => _speakerOn = !_speakerOn),
        ),
      ],
    );
  }
}

// ── Control Button ──
class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppColors.neonBlue.withOpacity(0.3)
                  : Colors.white.withOpacity(0.12),
              border: Border.all(
                color: active ? AppColors.neonBlue.withOpacity(0.5) : Colors.white24,
              ),
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

// ── End Call Button ──
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
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF3B55),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3B55).withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
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

// ── Accept Button ──
class _AcceptBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AcceptBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.call, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 6),
          const Text('Accept', style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Decline Button ──
class _DeclineBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _DeclineBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF3B55),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3B55).withOpacity(0.4),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 6),
          const Text('Decline', style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
