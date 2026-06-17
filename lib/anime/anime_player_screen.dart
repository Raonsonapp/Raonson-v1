// lib/anime/anime_player_screen.dart
// Player-и худамон барои аниме (на embed). 480p ройгон; 720p/1080p VIP.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../app/app_theme.dart';
import '../core/services/vip_service.dart';
import '../widgets/embed_player.dart';
import 'aparat_api.dart';

class AnimePlayerScreen extends StatefulWidget {
  final String hash;
  final String title;
  const AnimePlayerScreen({super.key, required this.hash, required this.title});

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (streams, embed) = await AparatApi.streams(widget.hash);
    if (!mounted) return;
    _embed = embed;
    _streams = streams;
    if (streams.isEmpty) {
      // Стрими мустақим ёфт нашуд — ба embed мегузарем.
      setState(() { _useEmbed = true; _loading = false; });
      return;
    }
    // Аввал сифати ройгони беҳтарин (≤480p), вагарна пасттарин.
    final free = streams.where((s) => s.height <= freeMaxHeight).toList();
    final pick = free.isNotEmpty ? free.last : streams.first;
    await _play(pick);
  }

  Future<void> _play(AnimeStream s) async {
    setState(() { _loading = true; _error = null; _current = s; });
    await _ctrl?.dispose();
    final c = VideoPlayerController.networkUrl(Uri.parse(s.url));
    try {
      await c.initialize();
      c.setLooping(false);
      c.play();
      if (!mounted) { c.dispose(); return; }
      setState(() { _ctrl = c; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Бозӣ нашуд — embed санҷед'; _useEmbed = true; });
    }
  }

  bool _isFree(AnimeStream s) => s.height <= freeMaxHeight;

  void _selectQuality() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          const Text('Сифат', style: TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._streams.reversed.map((s) {
            final free = _isFree(s);
            final vip = VipService.instance.isVip.value;
            final locked = !free && !vip;
            final selected = _current?.profile == s.profile;
            return ListTile(
              leading: Icon(
                  locked ? Icons.lock_outline_rounded
                         : (selected ? Icons.check_rounded : Icons.hd_outlined),
                  color: locked ? Colors.amber
                                : (selected ? AppColors.neonBlue : Colors.white70)),
              title: Text(s.profile.isEmpty ? '${s.height}p' : s.profile,
                  style: const TextStyle(color: Colors.white)),
              trailing: free
                  ? const Text('Ройгон', style: TextStyle(color: Colors.white38, fontSize: 12))
                  : Text(locked ? 'VIP 🔒' : 'VIP',
                      style: TextStyle(color: locked ? Colors.amber : Colors.white38, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                if (locked) {
                  _showVipDialog();
                } else {
                  _play(s);
                }
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
  void dispose() { _ctrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        title: Text(widget.title.isEmpty ? 'Аниме' : widget.title,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15)),
        actions: [
          if (!_useEmbed && _streams.isNotEmpty)
            TextButton.icon(
              onPressed: _selectQuality,
              icon: const Icon(Icons.hd_outlined, color: Colors.white, size: 20),
              label: Text(_current?.profile ?? 'Сифат',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
        ],
      ),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_useEmbed) {
      return AspectRatio(aspectRatio: 16 / 9, child: EmbedPlayer(url: _embed));
    }
    if (_loading) {
      return const CircularProgressIndicator(color: Colors.white, strokeWidth: 2);
    }
    if (_ctrl != null && _ctrl!.value.isInitialized) {
      return GestureDetector(
        onTap: () => setState(() =>
            _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play()),
        child: AspectRatio(
          aspectRatio: _ctrl!.value.aspectRatio == 0 ? 16 / 9 : _ctrl!.value.aspectRatio,
          child: Stack(alignment: Alignment.bottomCenter, children: [
            VideoPlayer(_ctrl!),
            VideoProgressIndicator(_ctrl!, allowScrubbing: true,
                colors: const VideoProgressColors(playedColor: AppColors.neonBlue)),
            if (!_ctrl!.value.isPlaying)
              const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 64),
          ]),
        ),
      );
    }
    return Text(_error ?? 'Бозӣ нашуд', style: const TextStyle(color: Colors.white54));
  }
}
