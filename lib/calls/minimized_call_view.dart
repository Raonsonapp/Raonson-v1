// lib/calls/minimized_call_view.dart
// ════════════════════════════════════════════════════════════════════
//  Занги хурдшуда — дар болои тамоми барнома (OverlayEntry).
//
//  Видео: тасвири хурди кашидашаванда бо видеои ҳамсӯҳбат, «бесадо» ва
//  «қатъ». Аудио: ҳубобча бо аватар, вақт ва «қатъ». Пахш → экрани пурра.
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../core/ui/app_icons.dart';
import '../widgets/avatar.dart';
import 'active_call.dart';
import 'call_strings.dart';
import 'snap_tile.dart';

class MinimizedCallView extends StatelessWidget {
  const MinimizedCallView({super.key, required this.controller});

  final ActiveCallController controller;

  static const videoSize = Size(112, 168);
  static const voiceSize = Size(196, 60);

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    // Аз панели поёнии навигатсия боло — то тугмаҳоро напӯшонад.
    final insets = EdgeInsets.fromLTRB(
        pad.left + 12, pad.top + 12, pad.right + 12, pad.bottom + 72);
    final s = controller.session;
    if (s == null) return const SizedBox.shrink();
    return Material(
      type: MaterialType.transparency,
      child: SnapTile(
        size: s.isVideo ? videoSize : voiceSize,
        insets: insets,
        initialCorner: SnapCorner.topRight,
        onTap: controller.restore,
        child: Semantics(
          key: const Key('call_pip'),
          button: true,
          label: CallStrings.t('returnToCall'),
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, __) =>
                s.isVideo ? _video(controller, s) : _voice(controller, s),
          ),
        ),
      ),
    );
  }

  static Widget _video(ActiveCallController c, CallSession s) {
    final e = c.engine;
    final showRemote = c.connected && e.remoteUid != null && e.hasVideo;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x88000000), blurRadius: 18, spreadRadius: 1)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(fit: StackFit.expand, children: [
          if (showRemote)
            e.remoteView('pip')
          else
            Container(
              color: const Color(0xFF0D1B3E),
              alignment: Alignment.center,
              child: Avatar(imageUrl: s.peer.avatar, size: 56, glowBorder: false),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: const Color(0x55000000),
              child: Text(c.statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundBtn(
                  key: const Key('call_pip_mute'),
                  icon: e.muted ? AppIcons.mic_off_rounded : AppIcons.mic_rounded,
                  color: e.muted ? Colors.white : const Color(0x66000000),
                  iconColor: e.muted ? Colors.black : Colors.white,
                  onTap: c.toggleMute,
                ),
                _RoundBtn(
                  key: const Key('call_pip_end'),
                  icon: AppIcons.call_end_rounded,
                  color: const Color(0xFFFF3B55),
                  iconColor: Colors.white,
                  onTap: c.endCall,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  static Widget _voice(ActiveCallController c, CallSession s) => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xF0101D3A),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0x3300E5FF)),
          boxShadow: const [
            BoxShadow(color: Color(0x88000000), blurRadius: 16)
          ],
        ),
        child: Row(children: [
          ClipOval(
              child: Avatar(imageUrl: s.peer.avatar, size: 44, glowBorder: false)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.peer.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(c.statusText,
                    key: const Key('call_pip_time'),
                    maxLines: 1,
                    style: TextStyle(
                        color: c.connected
                            ? const Color(0xFF34C759)
                            : Colors.white70,
                        fontSize: 12)),
              ],
            ),
          ),
          _RoundBtn(
            key: const Key('call_pip_end'),
            icon: AppIcons.call_end_rounded,
            color: const Color(0xFFFF3B55),
            iconColor: Colors.white,
            onTap: c.endCall,
          ),
        ]),
      );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      );
}
