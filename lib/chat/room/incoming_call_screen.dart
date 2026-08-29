import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../core/webrtc_service.dart';
import '../../models/user_model.dart';
import 'call_screen.dart';
import '../../core/ui/app_icons.dart';
import '../../core/i18n/strings.dart';

class IncomingCallScreen extends StatefulWidget {
  final UserModel caller;
  final CallType  callType;

  const IncomingCallScreen({
    super.key,
    required this.caller,
    required this.callType,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late Animation<double>   _ringAnim;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Ring animation
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _ringAnim = Tween<double>(begin: 0.88, end: 1.12)
        .animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut));

    // Play ringtone from asset
    _playRingtone();
  }

  Future<void> _playRingtone() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      // ringtone.wav — loops until accepted or declined
      await _player.play(AssetSource('sounds/ringtone.wav'));
    } catch (e) {
      debugPrint('[IncomingCall] ringtone error: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try { await _player.stop(); } catch (_) {}
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ringCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  void _accept() {
    _stopRingtone().then((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            peer:       widget.caller,
            callType:   widget.callType,
            isIncoming: true,
          ),
        ),
      );
    });
  }

  void _decline() {
    _stopRingtone().then((_) {
      WebRTCService().sendDecline(widget.caller.id);
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: [Color(0xFF050914), Color(0xFF0A1628), Color(0xFF050914)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // ── Top section ──
              Column(children: [
                const SizedBox(height: 40),

                // Call type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.dividerFaint),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      widget.callType == CallType.video
                          ? AppIcons.videocam_rounded
                          : AppIcons.call_rounded,
                      color: AppColors.neonBlue, size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.callType == CallType.video
                          ? 'Занги видео'
                          : 'Занги овозӣ',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ]),
                ),
                const SizedBox(height: 44),

                // Avatar + animated rings
                ScaleTransition(
                  scale: _ringAnim,
                  child: Stack(alignment: Alignment.center, children: [
                    _ring(190, 0.04),
                    _ring(160, 0.07),
                    _ring(132, 0.11),
                    Container(
                      width: 112, height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: AppColors.neonBlue.withOpacity(0.4),
                          blurRadius: 32, spreadRadius: 6,
                        )],
                      ),
                      child: ClipOval(
                        child: Avatar(
                            imageUrl: widget.caller.avatar,
                            size: 112, glowBorder: false),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),

                Text(widget.caller.username,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'занг мезанад...',
                  style: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.45), fontSize: 16),
                ),
              ]),

              // ── Action buttons ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 64),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionBtn(
                      icon:  AppIcons.call_end_rounded,
                      label: tr('ui.efdc7ddae3'),
                      color: const Color(0xFFFF3B55),
                      onTap: _decline,
                    ),
                    _actionBtn(
                      icon:  widget.callType == CallType.video
                          ? AppIcons.videocam_rounded
                          : AppIcons.call_rounded,
                      label: tr('ui.5d3c9ee794'),
                      color: const Color(0xFF00C853),
                      onTap: _accept,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ring(double s, double o) => Container(
    width: s, height: s,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
          color: AppColors.neonBlue.withOpacity(o), width: 1.5),
    ),
  );

  Widget _actionBtn({
    required IconData     icon,
    required String       label,
    required Color        color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 74, height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 28, spreadRadius: 3)],
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 32),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]),
      );
}
