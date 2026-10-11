// lib/voice/voice_post_player.dart
//
// «Овоз» — плеери пости овозӣ дар лента ва плиткаи он дар гриди профил.
//
//   • мавҷ (то 64 нуқта аз сервер), пешрафт рӯи мавҷ, пахш → ҷаҳиш;
//   • танҳо ЯК пости овозӣ дар як вақт садо медиҳад (дигарон ист мекунанд);
//   • муқова (ихтиёрӣ) ё градиенти бренд дар замина.
import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';

/// Мавҷ аз сатри "12,40,…" (0..100) → 0..1. Холӣ — мавҷи устувори
/// сохташуда аз суроға (то пости кӯҳна ҳам шакл дошта бошад).
List<double> parseWaveform(String? csv, {String seed = '', int fallback = 48}) {
  final out = <double>[];
  for (final p in (csv ?? '').split(',')) {
    final v = int.tryParse(p.trim());
    if (v != null) out.add((v.clamp(0, 100)) / 100.0);
  }
  if (out.isNotEmpty) return out;
  var h = seed.hashCode;
  return List.generate(fallback, (i) {
    h = (h * 1103515245 + 12345) & 0x7fffffff;
    return 0.2 + (h % 800) / 1000.0;
  });
}

/// «0:07», «1:00».
String formatVoiceDuration(Duration d) {
  final s = d.inSeconds.clamp(0, 5999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Мавҷ бо пешрафт.
class WaveformBars extends StatelessWidget {
  final List<double> samples;
  final double progress; // 0..1
  final Color played;
  final Color rest;
  final double height;
  const WaveformBars({
    super.key,
    required this.samples,
    this.progress = 0,
    this.played = Colors.white,
    this.rest = const Color(0x66FFFFFF),
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _WavePainter(samples, progress, played, rest),
        ),
      );
}

class _WavePainter extends CustomPainter {
  final List<double> s;
  final double p;
  final Color played, rest;
  _WavePainter(this.s, this.p, this.played, this.rest);

  @override
  void paint(Canvas canvas, Size size) {
    if (s.isEmpty || size.width <= 0) return;
    final n = s.length;
    final slot = size.width / n;
    final w = math.max(1.5, slot * 0.6);
    final paint = Paint()..strokeCap = StrokeCap.round..strokeWidth = w;
    for (var i = 0; i < n; i++) {
      final x = slot * i + slot / 2;
      final hgt = math.max(3.0, s[i] * size.height);
      paint.color = (i + 0.5) / n <= p ? played : rest;
      canvas.drawLine(Offset(x, (size.height - hgt) / 2),
          Offset(x, (size.height + hgt) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.p != p || o.s != s;
}

/// Плеери пости овозӣ дар лента.
class VoicePostPlayer extends StatefulWidget {
  final Map<String, String> media;
  final String postId;
  const VoicePostPlayer({super.key, required this.media, required this.postId});

  /// Кадом пост ҳоло садо медиҳад (як дар як вақт).
  static final ValueNotifier<String?> playing = ValueNotifier<String?>(null);

  /// Барои тест: плеери воқеӣ платформаро мехоҳад.
  @visibleForTesting
  static AudioPlayer Function() playerFactory = AudioPlayer.new;

  @override
  State<VoicePostPlayer> createState() => _VoicePostPlayerState();
}

class _VoicePostPlayerState extends State<VoicePostPlayer> {
  AudioPlayer? _player;
  final _subs = <StreamSubscription>[];
  bool _playing = false;
  bool _loading = false;
  Duration _pos = Duration.zero;
  late Duration _dur;
  late List<double> _wave;

  String get _url => widget.media['url'] ?? '';
  String get _cover => widget.media['cover'] ?? '';

  @override
  void initState() {
    super.initState();
    _dur = Duration(milliseconds: int.tryParse(widget.media['durationMs'] ?? '') ?? 0);
    _wave = parseWaveform(widget.media['waveform'], seed: _url);
    VoicePostPlayer.playing.addListener(_onOtherPlayer);
  }

  void _onOtherPlayer() {
    if (VoicePostPlayer.playing.value != widget.postId && _playing) {
      _player?.pause();
    }
  }

  AudioPlayer _ensurePlayer() {
    final p = _player;
    if (p != null) return p;
    final np = VoicePostPlayer.playerFactory();
    _subs.add(np.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    }));
    _subs.add(np.onDurationChanged.listen((d) {
      if (mounted && d > Duration.zero) setState(() => _dur = d);
    }));
    _subs.add(np.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() {
        _playing = s == PlayerState.playing;
        if (_playing) _loading = false;
      });
    }));
    _subs.add(np.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _pos = Duration.zero;
      });
      if (VoicePostPlayer.playing.value == widget.postId) {
        VoicePostPlayer.playing.value = null;
      }
    }));
    return _player = np;
  }

  Future<void> _toggle() async {
    if (_url.isEmpty) return;
    try {
      final p = _ensurePlayer();
      if (_playing) {
        await p.pause();
        return;
      }
      VoicePostPlayer.playing.value = widget.postId;
      if (_pos > Duration.zero) {
        await p.resume();
      } else {
        setState(() => _loading = true);
        await p.play(UrlSource(_url));
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seek(double fraction) async {
    if (_dur == Duration.zero) return;
    final to = _dur * fraction.clamp(0.0, 1.0);
    setState(() => _pos = to);
    try {
      await _ensurePlayer().seek(to);
    } catch (_) {}
  }

  @override
  void dispose() {
    VoicePostPlayer.playing.removeListener(_onOtherPlayer);
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    if (VoicePostPlayer.playing.value == widget.postId) {
      VoicePostPlayer.playing.value = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _dur.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);
    return AspectRatio(
      aspectRatio: 1.25,
      child: Stack(fit: StackFit.expand, children: [
        if (_cover.isNotEmpty)
          CachedNetworkImage(
            imageUrl: _cover, fit: BoxFit.cover, memCacheWidth: 900,
            errorWidget: (_, __, ___) => const _VoiceGradient())
        else
          const _VoiceGradient(),
        // Торик кардан, то мавҷ ва матн дар ҳар муқова хонда шаванд.
        const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x22000000), Color(0x99000000)]))),
        Positioned(
          left: 14, top: 12,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(AppIcons.mic_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Text(tr('voice.title'),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
        Center(
          child: Semantics(
            button: true,
            label: tr(_playing ? 'voice.pause' : 'voice.play'),
            child: GestureDetector(
              key: const ValueKey('voice-play'),
              onTap: _toggle,
              child: Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(blurRadius: 16, color: Color(0x55000000))],
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: CircularProgressIndicator(strokeWidth: 2.5,
                            color: Colors.black87))
                    : Icon(_playing ? AppIcons.pause_rounded : AppIcons.play_arrow_rounded,
                        color: Colors.black87, size: 36),
              ),
            ),
          ),
        ),
        Positioned(
          left: 14, right: 14, bottom: 12,
          child: Row(children: [
            Expanded(
              child: LayoutBuilder(builder: (_, c) => GestureDetector(
                key: const ValueKey('voice-wave'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _seek(d.localPosition.dx / c.maxWidth),
                child: WaveformBars(samples: _wave, progress: progress, height: 40),
              )),
            ),
            const SizedBox(width: 10),
            Text(
              _playing || _pos > Duration.zero
                  ? '${formatVoiceDuration(_pos)} / ${formatVoiceDuration(_dur)}'
                  : formatVoiceDuration(_dur),
              key: const ValueKey('voice-time'),
              style: const TextStyle(color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        ),
      ]),
    );
  }
}

class _VoiceGradient extends StatelessWidget {
  const _VoiceGradient();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: AppColors.musicGradient)));
}

/// Плиткаи пости овозӣ дар гриди профил ва Explore.
class VoiceTile extends StatelessWidget {
  final Map<String, String> media;
  const VoiceTile({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final cover = media['cover'] ?? '';
    final dur = Duration(milliseconds: int.tryParse(media['durationMs'] ?? '') ?? 0);
    final wave = parseWaveform(media['waveform'], seed: media['url'] ?? '', fallback: 24);
    // Барои плитка 24 сутун бас аст.
    final compact = <double>[
      for (var i = 0; i < 24; i++) wave[(i * wave.length) ~/ 24],
    ];
    return Stack(fit: StackFit.expand, children: [
      if (cover.isNotEmpty)
        CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover, memCacheWidth: 450,
            errorWidget: (_, __, ___) => const _VoiceGradient())
      else
        const _VoiceGradient(),
      const ColoredBox(color: Color(0x33000000)),
      const Positioned(top: 6, right: 6,
          child: Icon(AppIcons.mic_rounded, color: Colors.white, size: 16)),
      Positioned(left: 8, right: 8, bottom: 22,
          child: WaveformBars(samples: compact, height: 26,
              rest: const Color(0xCCFFFFFF))),
      if (dur > Duration.zero)
        Positioned(right: 6, bottom: 5,
            child: Text(formatVoiceDuration(dur),
                style: const TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]))),
    ]);
  }
}
