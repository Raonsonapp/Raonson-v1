import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

/// Намуди сатри музика.
enum MusicBarStyle {
  /// Ҳаб бо тугмаи play — стори ва ҷойҳои дигар.
  pill,

  /// Як сатри борик зери номи корбар: «♫ Хонанда · Ном».
  ///
  /// Маҳз ҳамин тавр Instagram нишон медиҳад. Пеш дар Raonson сатри
  /// музика дар ЗЕРИ пост буд — корбар гуфт: «номи музика дар болои
  /// пост мисли инстаграм бошад, на дар таги пост».
  header,
}

class MusicBar extends StatefulWidget {
  final SongInfo song;

  /// Дарҳол сар кунад (стори, ё пости дар экран буда).
  final bool autoPlay;

  /// Садоро бас мекунад: стори аз экран рафт, ё корбар лентаро
  /// хомӯш кард.
  final bool paused;

  /// Сабки фишурда барои лента; васеъ барои стори.
  final bool compact;

  final MusicBarStyle style;

  const MusicBar({
    super.key,
    required this.song,
    this.autoPlay = false,
    this.paused = false,
    this.compact = true,
    this.style = MusicBarStyle.pill,
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

  /// Суроғае, ки ҳангоми зер кардан ёфта шуд.
  ///
  /// ⚠️ Постҳои КӮҲНА танҳо ном ва хонанда доранд: он вақт барнома
  /// суроғаро умуман намефиристод. Дар экран ном менамуд, вале зада
  /// ҳеҷ чиз намешуд — «номаш ҳасту намехонад».
  ///
  /// Барои онҳо суруд аз рӯи ном ёфта мешавад. Постҳои НАВ суроғаро
  /// худашон доранд ва ин роҳ истифода намешавад.
  SongInfo? _resolved;

  /// Суруде, ки воқеан истифода мешавад.
  SongInfo get _song => _resolved ?? widget.song;

  /// Оё хондан имконпазир аст — ҳозир ё баъди ҷустуҷӯ?
  bool get _canPlay => _song.playable || _song.title.isNotEmpty;

  /// Ҳоло бояд садо диҳад?
  ///
  /// Як шарти ЯГОНА ба ҷои ду парчами алоҳида. Пеш мантиқ танҳо
  /// тағйири `paused`-ро мегирифт: агар пост ҳангоми сохта шудан
  /// ҳанӯз дар экран набуд ва БАЪД намоён шуд, `autoPlay` аз
  /// `false` ба `true` мегузашт — ва ҳеҷ чиз намешуд. Маҳз аз ин
  /// «музика худаш сар намешуд».
  bool get _shouldPlay => widget.autoPlay && !widget.paused;

  @override
  void initState() {
    super.initState();
    if (_shouldPlay) {
      // Баъди аввалин кашидани экран — вагарна `setState` дар
      // `initState` огоҳинома медиҳад.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _shouldPlay) _start();
      });
    }
  }

  @override
  void didUpdateWidget(MusicBar old) {
    super.didUpdateWidget(old);

    // Суруд иваз шуд (стори-и дигар, ё пости дигар дар ҳамон ҷой) →
    // аз нав.
    if (old.song.previewUrl != widget.song.previewUrl ||
        old.song.label != widget.song.label) {
      _resolved = null;
      _dispose();
      if (_shouldPlay) _start();
      return;
    }

    final was = old.autoPlay && !old.paused;
    if (was == _shouldPlay) return;

    if (_shouldPlay) {
      _player == null ? _start() : _player!.resume();
    } else {
      _player?.pause();
      if (mounted && _playing) setState(() => _playing = false);
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
    if (_loading) return;
    setState(() => _loading = true);

    // Суроға нест — онро аз рӯи ном меёбем (пости кӯҳна).
    if (!_song.playable) {
      final found = await _lookup(_song);
      if (found == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (!mounted) return;
      setState(() => _resolved = found);
    }

    final p = _player ??= AudioPlayer();
    final startAt = previewOffsetMs(_song);
    final windowMs = _song.windowMs.clamp(1000, kPreviewMs);

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
      await p.setSource(UrlSource(_song.previewUrl));
      await p.seek(Duration(milliseconds: startAt));
      await p.resume();
    } catch (e) {
      debugPrint('[MusicBar] $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    if (!_canPlay) return;
    if (_playing) {
      await _player?.pause();
      if (mounted) setState(() => _playing = false);
    } else if (_player != null) {
      await _player!.resume();
    } else {
      await _start();
    }
  }

  /// Сурудро аз рӯи ном ва хонанда меёбад.
  ///
  /// Ҳамон манбае, ки ҳангоми интихоб истифода шуд — пас натиҷа
  /// ҳамон суруд аст. Ҷои оғоз аз худи пост гирифта мешавад.
  Future<SongInfo?> _lookup(SongInfo s) async {
    final term = '${s.title} ${s.artist}'.trim();
    if (term.isEmpty) return null;
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=${Uri.encodeComponent(term)}&media=music&limit=1&country=US',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final list = (jsonDecode(res.body)['results'] as List? ?? []);
      if (list.isEmpty) return null;
      final url = (list.first['previewUrl'] ?? '').toString();
      if (url.isEmpty) return null;
      return s.copyWith(
        previewUrl: url,
        trackMs: s.trackMs > 0
            ? s.trackMs
            : ((list.first['trackTimeMillis'] as num?) ?? 210000).toInt(),
      );
    } catch (e) {
      debugPrint('[MusicBar] lookup: $e');
      return null;
    }
  }

  /// Сатри зери номи корбар — ҳамон тавре ки Instagram медиҳад.
  ///
  /// Ҳеҷ тугмаи play нест ва лозим ҳам не: садо ҳангоми ба экран
  /// даромадани пост худаш сар мешавад, ва баландгӯяк дар тарафи
  /// рости расм аст. Ин ҷо танҳо НОМ аст.
  Widget _buildHeader(SongInfo song) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.music_note_rounded,
              size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              song.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
            ),
          ),
        ],
      );

  /// 0..1 — то чӣ андоза порча хонда шуд.
  double get _progress {
    if (!_playing) return 0;
    final startAt = previewOffsetMs(_song);
    final windowMs = _song.windowMs.clamp(1000, kPreviewMs);
    return ((_posMs - startAt) / windowMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;
    if (song.isEmpty) return const SizedBox.shrink();

    if (widget.style == MusicBarStyle.header) return _buildHeader(song);

    final fg = widget.compact ? AppColors.textSecondary : AppColors.white;
    final bg = widget.compact
        ? AppColors.card
        : Colors.black.withOpacity(0.42);

    return GestureDetector(
      // Ҳатто агар суроға набошад, зер кардан кор мекунад: суруд аз
      // рӯи ном ёфта мешавад.
      onTap: _canPlay ? _toggle : null,
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
                !_canPlay
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
                    const AlwaysStoppedAnimation(AppColors.musicEnd),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
