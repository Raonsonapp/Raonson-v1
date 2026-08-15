// lib/anime/anime_player_screen.dart
// Player-и худамон барои аниме (на embed-и Aparat — бе логою скролл).
// Имконот: пахш/таваққуф, 10с ақиб/пеш, экрани калон (чархиш), интихоби
// сифат (480p ройгон, 720p/1080p VIP), зеркашӣ ва танзими худкори сифат.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:video_player/video_player.dart';
import '../app/app_theme.dart';
import '../core/services/vip_service.dart';
import '../widgets/embed_player.dart';
import 'aparat_api.dart';
import 'download_service.dart';
import '../core/ui/app_icons.dart';

class AnimePlayerScreen extends StatefulWidget {
  final String hash;
  final String title;
  final String? localPath; // агар офлайн (зеркашшуда) бошад
  const AnimePlayerScreen({
    super.key,
    required this.hash,
    required this.title,
    this.localPath,
  });

  @override
  State<AnimePlayerScreen> createState() => _AnimePlayerScreenState();
}

class _AnimePlayerScreenState extends State<AnimePlayerScreen> {
  static const int freeMaxHeight = 480; // 480p ва поёнтар ройгон

  List<AnimeStream> _streams = [];
  String _embed = '';
  AnimeStream? _current;
  VideoPlayerController? _ctrl;
  bool _loading = true;
  bool _useEmbed = false;
  bool _fullscreen = false;
  bool _controlsVisible = true;
  bool _downloading = false;
  double _dlProgress = 0;
  String? _error;
  Timer? _hideTimer;

  bool get _isLocal => widget.localPath != null;

  @override
  void initState() {
    super.initState();
    if (_isLocal) {
      _playLocal();
    } else {
      _load();
    }
  }

  // ── Боркунӣ ──
  Future<void> _load() async {
    final (streams, embed) = await AparatApi.streams(widget.hash);
    if (!mounted) return;
    _embed = embed;
    _streams = streams;
    if (streams.isEmpty) {
      setState(() { _useEmbed = true; _loading = false; });
      return;
    }
    await _play(await _pickInitial(streams));
  }

  Future<void> _playLocal() async {
    final c = VideoPlayerController.file(File(widget.localPath!));
    try {
      await c.initialize();
      c.setLooping(false);
      c.play();
      if (!mounted) { c.dispose(); return; }
      setState(() { _ctrl = c; _loading = false; });
      _restartHideTimer();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Файл бозӣ нашуд'; });
    }
  }

  // Сифати ибтидоиро вобаста ба интернет интихоб мекунад (барои кам шудани лаг).
  Future<AnimeStream> _pickInitial(List<AnimeStream> streams) async {
    final vip = VipService.instance.isVip.value;
    final allowed = streams.where((s) => _isFree(s) || vip).toList();
    final pool = allowed.isEmpty ? streams : allowed;
    bool fast = true;
    try {
      final c = await Connectivity().checkConnectivity();
      fast = c.contains(ConnectivityResult.wifi) ||
          c.contains(ConnectivityResult.ethernet);
    } catch (_) {}
    pool.sort((a, b) => a.height.compareTo(b.height));
    if (fast) return pool.last; // суръати хуб → баландтарин иҷозатдодашуда
    // Интернети суст → сифати миёна/паст, то шах нашавад.
    final mid = pool.firstWhere((s) => s.height >= 360 && s.height <= 480,
        orElse: () => pool.first);
    return mid;
  }

  Future<void> _play(AnimeStream s) async {
    // Мавқеи ҷориро нигоҳ медорем (ҳангоми иваз кардани сифат идома ёбад).
    final Duration? pos = _ctrl?.value.isInitialized == true
        ? _ctrl!.value.position : null;
    setState(() { _loading = true; _error = null; _current = s; });
    await _ctrl?.dispose();
    _ctrl = null;
    final c = VideoPlayerController.networkUrl(Uri.parse(s.url));
    try {
      await c.initialize();
      c.setLooping(false);
      if (pos != null) await c.seekTo(pos);
      c.play();
      if (!mounted) { c.dispose(); return; }
      setState(() { _ctrl = c; _loading = false; });
      _restartHideTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Бозӣ нашуд'; _useEmbed = true; });
    }
  }

  bool _isFree(AnimeStream s) => s.height == 0 || s.height <= freeMaxHeight;

  // ── Контролҳо ──
  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_ctrl?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _restartHideTimer();
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
    _restartHideTimer();
  }

  void _seekBy(int seconds) {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    var target = c.value.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > c.value.duration) target = c.value.duration;
    c.seekTo(target);
    _restartHideTimer();
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
    }
    _restartHideTimer();
  }

  String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  // ── Зеркашӣ ──
  Future<void> _download() async {
    // MP4-и беҳтарини иҷозатдода — HLS барои офлайн мувофиқ нест.
    final vip = VipService.instance.isVip.value;
    final mp4 = _streams
        .where((s) => s.url.toLowerCase().contains('.mp4'))
        .where((s) => _isFree(s) || vip)
        .toList()
      ..sort((a, b) => a.height.compareTo(b.height));
    if (mp4.isEmpty) {
      _snack('Ин видео барои зеркашӣ дастрас нест (танҳо стрим).');
      return;
    }
    setState(() { _downloading = true; _dlProgress = 0; });
    try {
      final path = await DownloadService.download(
        mp4.last.url,
        widget.title.isEmpty ? widget.hash : widget.title,
        onProgress: (p) { if (mounted) setState(() => _dlProgress = p); },
      );
      if (mounted) {
        setState(() => _downloading = false);
        _snack('Зеркашӣ шуд: ${path.split('/').last}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _downloading = false);
        _snack('Зеркашӣ нашуд — интернетро санҷед.');
      }
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: const Color(0xFF1A1A1A)),
    );
  }

  // ── Интихоби сифат ──
  void _selectQuality() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          const Text('Сифати видео', style: TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._streams.reversed.map((s) {
            final free = _isFree(s);
            final vip = VipService.instance.isVip.value;
            final locked = !free && !vip;
            final selected = _current?.url == s.url;
            final label = s.profile.isEmpty
                ? (s.height > 0 ? '${s.height}p' : 'Авто') : s.profile;
            return ListTile(
              leading: Icon(
                  locked ? AppIcons.lock_outline_rounded
                         : (selected ? AppIcons.check_rounded : AppIcons.hd_outlined),
                  color: locked ? Colors.amber
                                : (selected ? AppColors.neonBlue : Colors.white70)),
              title: Text(label, style: const TextStyle(color: Colors.white)),
              trailing: free
                  ? const Text('Ройгон', style: TextStyle(color: Colors.white38, fontSize: 12))
                  : Text(locked ? 'VIP 🔒' : 'VIP',
                      style: TextStyle(color: locked ? Colors.amber : Colors.white38, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                if (locked) { _showVipDialog(); } else { _play(s); }
              },
            );
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showVipDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Сифати баланд — VIP',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            '720p ва 1080p барои аъзоёни VIP дастрас аст. '
            '480p ройгон тамошо карда метавонед.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Хуб', style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _ctrl?.dispose();
    // Ҳолати экранро барқарор мекунем.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_fullscreen,
      onPopInvoked: (didPop) {
        if (!didPop && _fullscreen) _toggleFullscreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _fullscreen ? null : AppBar(
          backgroundColor: Colors.black, elevation: 0,
          title: Text(
              widget.title.isEmpty ? 'Аниме' : AparatApi.toTajik(widget.title),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15)),
          actions: [
            if (!_isLocal && !_useEmbed && _streams.isNotEmpty) ...[
              _downloading
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              value: _dlProgress, strokeWidth: 2,
                              color: AppColors.neonBlue)),
                    )
                  : IconButton(
                      onPressed: _download,
                      icon: const Icon(AppIcons.download_rounded, color: Colors.white),
                      tooltip: 'Зеркашӣ'),
            ],
          ],
        ),
        body: Center(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_useEmbed) {
      return AspectRatio(aspectRatio: 16 / 9, child: EmbedPlayer(url: _embed));
    }
    if (_loading) {
      return const CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 2);
    }
    final c = _ctrl;
    if (c != null && c.value.isInitialized) {
      final video = GestureDetector(
        onTap: _toggleControls,
        child: Stack(alignment: Alignment.center, children: [
          // Худи видео — танҳо тасвир, бе логою UI-и Aparat.
          AspectRatio(
            aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
          // Лоадери буфер (ҳангоми боркунӣ).
          if (c.value.isBuffering)
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          // Қабати контролҳо.
          if (_controlsVisible) _controls(c),
        ]),
      );
      if (_fullscreen) {
        return SizedBox.expand(
          child: FittedBox(fit: BoxFit.contain, child: SizedBox(
            width: c.value.size.width == 0 ? 16 : c.value.size.width,
            height: c.value.size.height == 0 ? 9 : c.value.size.height,
            child: video,
          )),
        );
      }
      return video;
    }
    return Text(_error ?? 'Бозӣ нашуд', style: const TextStyle(color: Colors.white54));
  }

  Widget _controls(VideoPlayerController c) {
    final pos = c.value.position;
    final dur = c.value.duration;
    return Positioned.fill(
      child: Container(
        color: Colors.black26,
        child: Column(children: [
          const Spacer(),
          // Маркази контролҳо: 10с ақиб | пахш/таваққуф | 10с пеш
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _ctrlBtn(AppIcons.replay_10_rounded, () => _seekBy(-10), size: 38),
            const SizedBox(width: 28),
            _ctrlBtn(
                c.value.isPlaying
                    ? AppIcons.pause_rounded
                    : AppIcons.play_arrow_rounded,
                _togglePlay, size: 58),
            const SizedBox(width: 28),
            _ctrlBtn(AppIcons.forward_10_rounded, () => _seekBy(10), size: 38),
          ]),
          const Spacer(),
          // Поён: вақт | слайдер | вақт | сифат | экрани калон
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Text(_fmt(pos), style: const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: AppColors.neonBlue,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.neonBlue,
                  ),
                  child: Slider(
                    value: pos.inMilliseconds
                        .clamp(0, dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds)
                        .toDouble(),
                    max: dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds.toDouble(),
                    onChanged: (v) {
                      c.seekTo(Duration(milliseconds: v.toInt()));
                      _restartHideTimer();
                    },
                  ),
                ),
              ),
              Text(_fmt(dur), style: const TextStyle(color: Colors.white, fontSize: 12)),
              if (!_isLocal && _streams.isNotEmpty)
                TextButton(
                  onPressed: _selectQuality,
                  style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text(
                    _current?.profile.isNotEmpty == true ? _current!.profile : 'Сифат',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              _ctrlBtn(
                  _fullscreen
                      ? AppIcons.fullscreen_exit_rounded
                      : AppIcons.screen_rotation_rounded,
                  _toggleFullscreen, size: 24),
            ]),
          ),
          SizedBox(height: _fullscreen ? 8 : 4),
        ]),
      ),
    );
  }

  Widget _ctrlBtn(IconData icon, VoidCallback onTap, {double size = 32}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: size),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }
}
