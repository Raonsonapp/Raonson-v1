// lib/calls/incoming_call_page.dart
// ════════════════════════════════════════════════════════════════════
//  Занги воридотӣ вақте ки барнома КУШОДА аст — тамоми экран, на banner.
//
//  Мисли WhatsApp: аватари калон, ном, «Занги видеоӣ/аудиоӣ», тугмаи
//  сабзи «Қабул» ва сурхи «Рад», оҳанги давршаванда ва ларзиш.
//
//  Пештар экрани кӯҳна оҳанги assets/sounds/ringtone.wav-ро мехонд, ки
//  умуман вуҷуд надошт — занг бесадо буд. Вақти интизор ҳам набуд:
//  агар зангзананда қатъ мекард, экран абадан мемонд.
// ════════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../core/services/socket_service.dart';
import '../core/ui/app_icons.dart';
import '../widgets/avatar.dart';
import 'call_coordinator.dart';
import 'call_payload.dart';
import 'call_strings.dart';
import 'callkit_bridge.dart';

class IncomingCallPage extends StatefulWidget {
  final IncomingCall call;
  const IncomingCallPage({super.key, required this.call});

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);
  Timer? _vibrate;
  Timer? _timeout;
  bool _done = false;

  IncomingCall get c => widget.call;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _ring();
    // Ларзиш мисли занги телефон: ҳар 1.5 сония.
    HapticFeedback.vibrate();
    _vibrate = Timer.periodic(
        const Duration(milliseconds: 1500), (_) => HapticFeedback.vibrate());
    _timeout = Timer(CallkitBridge.ringDuration, () => _close(missed: true));
    // Зангзананда пеш аз ҷавоб қатъ кард → «аздастрафта».
    SocketService.instance.on('call:ended', _onRemoteEnded);
  }

  Future<void> _ring() async {
    try {
      // Ҳаҷми «занг», на «мусиқӣ»: режими бесадои телефон эҳтиром мешавад.
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.notificationRingtone,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      ));
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/ringtone.wav'));
    } catch (e) {
      debugPrint('[IncomingCall] ringtone: $e');
    }
  }

  void _stopAlerts() {
    _vibrate?.cancel();
    _timeout?.cancel();
    _player.stop().catchError((_) {});
  }

  void _onRemoteEnded(dynamic _) => _close(missed: true);

  void _close({required bool missed}) {
    if (_done || !mounted) return;
    _done = true;
    _stopAlerts();
    if (missed) CallCoordinator.instance.missed(c);
    // pop, на maybePop: PopScope (canPop: false) maybePop-ро боз медошт.
    Navigator.of(context).pop();
  }

  void _accept() {
    if (_done) return;
    _done = true;
    _stopAlerts();
    CallCoordinator.instance.accept(c, replace: true);
  }

  void _decline() {
    if (_done || !mounted) return;
    _done = true;
    _stopAlerts();
    CallCoordinator.instance.decline(c);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _stopAlerts();
    SocketService.instance.off('call:ended', _onRemoteEnded);
    _player.dispose();
    _pulse.dispose();
    // Агар ба CallScreen гузашта бошем, он ҳолати UI-ро худаш идора мекунад.
    if (!_done) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        c.callerName.isNotEmpty ? c.callerName : CallStrings.t('unknown');
    return PopScope(
      // «Ақиб» = рад: занг набояд пинҳон дар замина садо диҳад.
      canPop: _done,
      onPopInvoked: (didPop) {
        if (!didPop) _decline();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF050914),
        body: Stack(fit: StackFit.expand, children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC050914),
                  Color(0xEE0A1628),
                  Color(0xFF050914)
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(children: [
              const SizedBox(height: 56),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  c.isVideo ? AppIcons.videocam_rounded : AppIcons.call_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  CallStrings.t(c.isVideo ? 'video' : 'voice'),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 15, letterSpacing: 0.4),
                ),
              ]),
              const SizedBox(height: 48),
              ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.06).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonBlue.withOpacity(0.35),
                        blurRadius: 40,
                        spreadRadius: 8,
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: Avatar(
                        imageUrl: c.callerAvatar, size: 132, glowBorder: false),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Text(CallStrings.t('calling'),
                  style: const TextStyle(color: Colors.white54, fontSize: 16)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 64),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CallButton(
                      key: const Key('incoming_decline'),
                      icon: AppIcons.call_end_rounded,
                      label: CallStrings.t('decline'),
                      color: const Color(0xFFFF3B30),
                      onTap: _decline,
                    ),
                    _CallButton(
                      key: const Key('incoming_accept'),
                      icon: c.isVideo
                          ? AppIcons.videocam_rounded
                          : AppIcons.call_rounded,
                      label: CallStrings.t('accept'),
                      color: const Color(0xFF34C759),
                      onTap: _accept,
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            elevation: 8,
            shadowColor: color.withOpacity(0.6),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 76,
                height: 76,
                child: Icon(icon, color: Colors.white, size: 34),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      );
}
