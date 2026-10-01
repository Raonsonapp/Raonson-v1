import 'dart:async';

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
// Дар сутуни рост тугмаи ▶/❚❚ НЕСТ (мисли Instagram). Вақте видео истодааст,
// дар марказ нишони калони ▶ пайдо мешавад ва баъди бозӣ оҳиста нопадид
// мешавад; зарба ба он — боз бозӣ. Нишони садо баъди зарба ~700 ms намоён
// аст ва баъд нопадид мешавад. Ҳардуи ин нишонҳо дар худи ҳамин виҷет
// кашида мешаванд — Reels, Explore ва reel-и алоҳида як хел рафтор мекунанд.

/// Қисми канорӣ (аз ҳар ду тараф), ки пахш-нигоҳ дар он 2x мекунад.
const double kReelFastEdgeFraction = 0.2;

/// Чанд вақт нишони садо (баъди зарба) дар марказ мемонад.
const Duration kReelMuteFlash = Duration(milliseconds: 700);

/// Давомнокии пайдо/нопадид шудани нишонҳои марказӣ.
const Duration kReelOverlayFade = Duration(milliseconds: 200);

enum _HoldMode { none, pause, fast }

class ReelPressGestures extends StatefulWidget {
  final VideoPlayerController? controller;

  /// Видео истода аст (на бо hold) — пахш-нигоҳ он гоҳ ҳеҷ кор намекунад,
  /// вагарна бардоштани ангушт видеои истондашударо боз ба кор медаровард.
  /// Дар марказ нишони ▶ намоён аст; зарба → [onResume].
  final bool paused;

  /// Ҳолати садо барои нишони баландгӯяк баъди зарба. null — нишон нест.
  final bool? muted;

  /// Зарба ҳангоми [paused] (ба экран ё ба нишони ▶) — бозӣ.
  final VoidCallback? onResume;

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
    this.muted,
    this.onResume,
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
  bool _flash = false;
  Timer? _flashTimer;

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

  void _tap() {
    if (widget.paused) {
      (widget.onResume ?? widget.onTap)?.call();
      return;
    }
    widget.onTap?.call();
    if (widget.muted == null) return;
    _flashTimer?.cancel();
    setState(() => _flash = true);
    _flashTimer = Timer(kReelMuteFlash, () {
      if (mounted) setState(() => _flash = false);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
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
        onTap: _tap,
        onDoubleTap: widget.onDoubleTap,
        onLongPressStart: (d) => _start(d, box.maxWidth),
        onLongPressEnd: (_) => _end(),
        onLongPressCancel: _end,
        child: Stack(fit: StackFit.expand, children: [
          widget.child,
          // ▶ дар марказ: ҳангоми ист (ё hold) намоён, баъди бозӣ нопадид.
          ReelPausedIndicator(
            visible: widget.paused || _mode == _HoldMode.pause,
            onTap: widget.paused ? (widget.onResume ?? widget.onTap) : null,
          ),
          if (widget.muted != null)
            ReelMuteFlash(visible: _flash, muted: widget.muted!),
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

/// Нишони калони ▶ дар марказ, вақте видео истодааст. Ҳангоми бозӣ
/// оҳиста нопадид мешавад. Зарба ба худи он — боз бозӣ (мисли Instagram).
class ReelPausedIndicator extends StatelessWidget {
  final bool visible;
  final VoidCallback? onTap;
  const ReelPausedIndicator({super.key, this.visible = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = visible && onTap != null;
    return IgnorePointer(
      ignoring: !active,
      child: Center(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: kReelOverlayFade,
          child: Semantics(
            button: active,
            label: 'Бозӣ',
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
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
          ),
        ),
      ),
    );
  }
}

/// Нишони баландгӯяк дар марказ баъди зарба — ~700 ms, баъд нопадид.
class ReelMuteFlash extends StatelessWidget {
  final bool visible;
  final bool muted;
  const ReelMuteFlash({super.key, required this.visible, required this.muted});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: kReelOverlayFade,
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            child: Icon(
                muted ? AppIcons.volume_off_rounded : AppIcons.volume_up_rounded,
                color: Colors.white,
                size: 30),
          ),
        ),
      ),
    );
  }
}
