import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/ui/app_icons.dart';

// ── Ишораҳои плеери Reel — ЯК қоида дар Reels, Explore ва reel-и алоҳида ──
//
//   як зарба                       → onTap (садо фаъол/хомӯш, мисли Instagram)
//   ду зарба                       → лайк
//   пахш-нигоҳ дар МИЁНА           → видео меистад, то ангушт бардошта шавад
//   пахш-нигоҳ дар КАНОР (20%-и    → суръати 2x бо нишони «2x ▶▶»;
//   чап ё рост)                      бардоштан → боз 1x
//
// Истодани доимӣ — бо тугмаи намоёни ▶/❚❚ ([ReelPlayPauseButton]) дар
// сутуни рост. Зарба ба садо мемонад, чунки корбарони Instagram ба ҳамин
// одат доранд; агар зарба ҳам истонад, ҳам садоро иваз кунад — ошуфта мешаванд.

/// Қисми канорӣ (аз ҳар ду тараф), ки пахш-нигоҳ дар он 2x мекунад.
const double kReelFastEdgeFraction = 0.2;

enum _HoldMode { none, pause, fast }

class ReelPressGestures extends StatefulWidget {
  final VideoPlayerController? controller;

  /// Корбар бо тугма истонд — пахш-нигоҳ он гоҳ ҳеҷ кор намекунад,
  /// вагарна бардоштани ангушт видеои истондашударо боз ба кор медаровард.
  final bool paused;

  /// Саҳифаи ҷорӣ аст (дар PageView) — танҳо он гоҳ баъди hold бозӣ мекунем.
  final bool active;

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  /// true — hold-pause оғоз шуд, false — тамом. Барои ҳисоби вақти тамошо.
  final ValueChanged<bool>? onHoldPause;

  final Widget child;

  const ReelPressGestures({
    super.key,
    required this.controller,
    required this.child,
    this.paused = false,
    this.active = true,
    this.onTap,
    this.onDoubleTap,
    this.onHoldPause,
  });

  @override
  State<ReelPressGestures> createState() => _ReelPressGesturesState();
}

class _ReelPressGesturesState extends State<ReelPressGestures> {
  _HoldMode _mode = _HoldMode.none;

  bool get _ready => widget.controller?.value.isInitialized ?? false;

  void _start(LongPressStartDetails d, double width) {
    final c = widget.controller;
    if (c == null || !_ready || widget.paused) return;
    final x = d.localPosition.dx;
    final edge = width * kReelFastEdgeFraction;
    if (width > 0 && (x < edge || x > width - edge)) {
      HapticFeedback.selectionClick();
      c.setPlaybackSpeed(2.0);
      if (!c.value.isPlaying && widget.active) c.play();
      setState(() => _mode = _HoldMode.fast);
    } else {
      c.pause();
      widget.onHoldPause?.call(true);
      setState(() => _mode = _HoldMode.pause);
    }
  }

  void _end() {
    final c = widget.controller;
    final was = _mode;
    if (was == _HoldMode.none) return;
    setState(() => _mode = _HoldMode.none);
    if (c == null || !_ready) return;
    if (was == _HoldMode.fast) {
      c.setPlaybackSpeed(1.0);
    } else {
      widget.onHoldPause?.call(false);
      if (!widget.paused && widget.active) c.play();
    }
  }

  @override
  void didUpdateWidget(ReelPressGestures old) {
    super.didUpdateWidget(old);
    // Swipe ба reel-и дигар ҳангоми hold — суръат 1x бармегардад,
    // вагарна видеои навбатӣ ҳам бо 2x оғоз мешуд.
    if (old.controller != widget.controller && _mode == _HoldMode.fast) {
      old.controller?.setPlaybackSpeed(1.0);
      _mode = _HoldMode.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPressStart: (d) => _start(d, box.maxWidth),
        onLongPressEnd: (_) => _end(),
        onLongPressCancel: _end,
        child: Stack(fit: StackFit.expand, children: [
          widget.child,
          if (_mode == _HoldMode.fast)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 0,
              right: 0,
              child: const IgnorePointer(child: Center(child: _FastBadge())),
            ),
        ]),
      );
    });
  }
}

class _FastBadge extends StatelessWidget {
  const _FastBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Text('2x',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        SizedBox(width: 4),
        Icon(AppIcons.forward_10_rounded, color: Colors.white, size: 16),
      ]),
    );
  }
}

/// Тугмаи хурди намоёни ▶ / ❚❚ — барои сутуни рости Reels.
class ReelPlayPauseButton extends StatelessWidget {
  final bool paused;
  final VoidCallback onTap;
  final Color color;

  const ReelPlayPauseButton({
    super.key,
    required this.paused,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: paused ? 'Бозӣ' : 'Ист',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            paused ? AppIcons.play_arrow_rounded : AppIcons.pause_rounded,
            color: color,
            size: 26,
            shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
          ),
        ),
      ),
    );
  }
}

/// Нишони калони ▶ дар марказ, вақте видео бо тугма истондааст.
/// Зарба ба худи он — боз бозӣ (мисли Instagram).
class ReelPausedIndicator extends StatelessWidget {
  final VoidCallback onTap;
  const ReelPausedIndicator({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          padding: const EdgeInsets.all(16),
          child: const Icon(AppIcons.play_arrow_rounded,
              color: Colors.white, size: 48),
        ),
      ),
    );
  }
}
