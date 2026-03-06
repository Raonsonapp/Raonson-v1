import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../core/webrtc_service.dart';
import '../../models/user_model.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final UserModel caller;
  final Map<String, dynamic> offerData;
  final CallType callType;

  const IncomingCallScreen({
    super.key,
    required this.caller,
    required this.offerData,
    required this.callType,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _ringAnim = Tween<double>(begin: 0.9, end: 1.1)
        .animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ringCtrl.dispose();
    super.dispose();
  }

  void _accept() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peer: widget.caller,
          callType: widget.callType,
          isIncoming: true,
          offerData: widget.offerData,
        ),
      ),
    );
  }

  void _decline() {
    WebRTCService().declineCall(widget.caller.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050914), Color(0xFF0A1628), Color(0xFF050914)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Top info
              Column(
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.callType == CallType.video
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          color: AppColors.neonBlue,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.callType == CallType.video
                              ? 'Incoming video call'
                              : 'Incoming voice call',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Avatar with rings
                  ScaleTransition(
                    scale: _ringAnim,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _ring(180, 0.05),
                        _ring(155, 0.08),
                        _ring(130, 0.12),
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonBlue.withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Avatar(
                              imageUrl: widget.caller.avatar,
                              size: 110,
                              glowBorder: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.caller.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'is calling you...',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),

              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBtn(
                      icon: Icons.call_end_rounded,
                      label: 'Decline',
                      color: const Color(0xFFFF3B55),
                      onTap: _decline,
                    ),
                    _buildBtn(
                      icon: widget.callType == CallType.video
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      label: 'Accept',
                      color: Colors.green,
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

  Widget _buildBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }
}
