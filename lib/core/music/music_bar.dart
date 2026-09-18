import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../ui/app_icons.dart';
import 'song_info.dart';

// ══════════════════════════════════════════════════════════════════
//  Сатри музика — он чи ТАМОШОБИН мебинад.
//
//  Пеш дар пост танҳо матн буд: «Ном — Хонанда» ва халос. Ҳеҷ гоҳ
//  ҳеҷ чиз намехонд, чунки суроғаи суруд (previewUrl) ҳатто сабт
//  намешуд. Дар стори бошад ҳатто ном гум мешуд.
//
//  Акнун:
//   • номи суруд ва номи ХОНАНДА навишта мешавад;
//   • занед → аз ҲАМОН ҷое, ки муаллиф интихоб кард, мехонад;
//   • хати зери сатр ҳангоми хондан пеш меравад.
// ══════════════════════════════════════════════════════════════════

/// iTunes ҳамеша 30 сония preview медиҳад.
const int kPreviewMs = 30000;

/// Ҷои `startMs`-и суруди пурра дар дохили preview-и 30-сонияи iTunes.
///
/// Худи suruди пурра дастрас нест — танҳо порчаи 30-сония. Барои
/// ҳамин ҷои интихобшуда ба ҳамон порча мутаносиб гузаронда мешавад.
int previewOffsetMs(SongInfo song) {
  final trackMs = song.trackMs > 0 ? song.trackMs : kPreviewMs;
  final windowMs = song.windowMs;
  final maxSeek = (kPreviewMs - windowMs.clamp(0, kPreviewMs)).clamp(0, kPreviewMs);
  return ((song.startMs / trackMs) * kPreviewMs).round().clamp(0, maxSeek);
}

class MusicBar extends StatefulWidget {
  final SongInfo song;

  /// Дарҳол сар кунад (стори) ё интизори зарба шавад (пост дар лента).
  ///
  /// Дар лента худкор хондан МУМКИН НЕСТ: даҳ пост дар экран =
  /// даҳ суруд якбора.
  final bool autoPlay;

  /// Ҳангоми аз экран рафтани стори садоро бас мекунад.
  final bool paused;

  /// Сабки фишурда барои лента; васеъ барои стори.
  final bool compact;

  const MusicBar({
    super.key,
    required this.song,
    this.autoPlay = false,
    this.paused = false,
    this.compact = true,
  });

  @override
  State<MusicBar> createState() => _MusicBarState();
}

class _MusicBarState extends State<MusicBar> {
  AudioPlayer? _player;
  StreamSubscription? _posSub, _stateSub;

  bool _playing = false;
  bool _loading = false;
  int _posMs = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay && widget.song.playable && !widget.paused) {
      // Баъди аввалин кашидани экран — вагарна `setState` дар
      // `initState` огоҳинома медиҳад.
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void didUpdateWidget(MusicBar old) {
    super.didUpdateWidget(old);

    // Суруд иваз шуд (стори-и дигар) → аз нав.
    if (old.song.previewUrl != widget.song.previewUrl) {
      _dispose();
      if (widget.autoPlay && widget.song.playable && !widget.paused) _start();
      return;
    }
    if (widget.paused && _playing) {
      _player?.pause();
    } else if (!widget.paused && old.paused && widget.autoPlay) {
      _player == null ? _start() : _player!.resume();
    }
  }

  void _dispose() {
    _posSub?.cancel();
    _posSub = null;
    _stateSub?.cancel();
    _stateSub = null;
    _player?.stop();
    _player?.dispose();
    _player = null;
    if (mounted) {
      setState(() {
        _playing = false;
        _posMs = 0;
      });
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player?.stop();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!widget.song.playable || _loading) return;
    setState(() => _loading = true);

    final p = _player ??= AudioPlayer();
    final startAt = previewOffsetMs(widget.song);
    final windowMs = widget.song.windowMs.clamp(1000, kPreviewMs);

    _posSub ??= p.onPositionChanged.listen((d) {
      if (!mounted) return;
      setState(() => _posMs = d.inMilliseconds);
      // Такрори порча — ҳамон тавре ки дар Instagram.
      if (d.inMilliseconds >= startAt + windowMs) {
        p.seek(Duration(milliseconds: startAt));
      }
    });
    _stateSub ??= p.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() {
        _playing = s == PlayerState.playing;
        _loading = false;
      });
    });

    try {
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setSource(UrlSource(widget.song.previewUrl));
      await p.seek(Duration(milliseconds: startAt));
      await p.resume();
    } catch (e) {
      debugPrint('[MusicBar] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    if (!widget.song.playable) return;
    if (_playing) {
      await _player?.pause();
      if (mounted) setState(() => _playing = false);
    } else if (_player != null) {
      await _player!.resume();
    } else {
      await _start();
    }
  }

  /// 0..1 — то чӣ андоза порча хонда шуд.
  double get _progress {
    if (!_playing) return 0;
    final startAt = previewOffsetMs(widget.song);
    final windowMs = widget.song.windowMs.clamp(1000, kPreviewMs);
    return ((_posMs - startAt) / windowMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    if (song.isEmpty) return const SizedBox.shrink();

    final fg = widget.compact ? AppColors.textSecondary : AppColors.white;
    final bg = widget.compact
        ? AppColors.card
        : Colors.black.withOpacity(0.42);

    return GestureDetector(
      onTap: song.playable ? _toggle : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (_loading)
              SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 1.8, color: fg))
            else
              Icon(
                !song.playable
                    ? AppIcons.music_note_rounded
                    : _playing
                        ? AppIcons.pause_rounded
                        : AppIcons.play_arrow_rounded,
                color: fg,
                size: 14,
              ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                // Ном ВА хонанда — ҳарду. Пеш дар стори ҳарду гум мешуданд.
                song.label,
                style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: widget.compact ? FontWeight.w400 : FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),

          // Хати ҳаракаткунанда. Танҳо ҳангоми хондан — вагарна он
          // хатти холии бемаъно мебуд.
          if (_playing) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 2.5,
                backgroundColor: fg.withOpacity(0.22),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.storyEnd),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
