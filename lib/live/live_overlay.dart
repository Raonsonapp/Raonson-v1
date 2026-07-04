// lib/live/live_overlay.dart
// Overlay-и Live мисли Instagram — вале бо ранги худамон (кабуду сабз) ва icon-и худамон.
// Комментҳо (поёни чап), дилҳои парвозкунанда (рост), майдони коммент + дил.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/api/api_client.dart';
import '../widgets/avatar.dart';

// Ранги брендии Live — кабуду сабз (на пушти Instagram).
const List<Color> kLiveGradient = [Color(0xFF00C6FF), Color(0xFF00E87A)];

class LiveInteractionOverlay extends StatefulWidget {
  final String streamId;
  final String hostUsername;
  final String hostAvatar;
  final VoidCallback onClose;
  const LiveInteractionOverlay({
    super.key,
    required this.streamId,
    required this.hostUsername,
    required this.hostAvatar,
    required this.onClose,
  });
  @override
  State<LiveInteractionOverlay> createState() => _LiveInteractionOverlayState();
}

class _LiveInteractionOverlayState extends State<LiveInteractionOverlay> {
  final _input = TextEditingController();
  final _hearts = <int>[];
  int _heartSeq = 0;
  List<Map<String, dynamic>> _comments = [];
  int _viewers = 0, _likes = 0;
  Timer? _pollC, _pollS;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _loadStats();
    _pollC = Timer.periodic(const Duration(seconds: 3), (_) => _loadComments());
    _pollS = Timer.periodic(const Duration(seconds: 5), (_) => _loadStats());
  }

  @override
  void dispose() {
    _input.dispose();
    _pollC?.cancel();
    _pollS?.cancel();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final r = await ApiClient.instance.get('/live/${widget.streamId}/comments');
      if (r.statusCode < 400 && mounted) {
        final list = (jsonDecode(r.body)['comments'] ?? []) as List;
        setState(() => _comments =
            list.map((e) => (e as Map).cast<String, dynamic>()).toList());
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final r = await ApiClient.instance.get('/live/');
      if (r.statusCode < 400 && mounted) {
        final list = (jsonDecode(r.body)['streams'] ?? []) as List;
        for (final s in list) {
          if ((s['id'] ?? '') == widget.streamId) {
            setState(() {
              _viewers = (s['viewers'] as num?)?.toInt() ?? 0;
              _likes = (s['likes'] as num?)?.toInt() ?? 0;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    _input.clear();
    setState(() => _comments.add({'username': 'шумо', 'text': t}));
    try {
      await ApiClient.instance.post('/live/${widget.streamId}/comment',
          body: {'text': t});
    } catch (_) {}
  }

  void _like() {
    setState(() => _hearts.add(_heartSeq++));
    ApiClient.instance.post('/live/${widget.streamId}/like');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Stack(children: [
        // ── Top bar ─────────────────────────────────
        Positioned(top: 8, left: 12, right: 12,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(color: Colors.black45,
                  borderRadius: BorderRadius.circular(24)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Avatar(imageUrl: widget.hostAvatar, size: 30,
                    name: widget.hostUsername),
                const SizedBox(width: 8),
                Text('@${widget.hostUsername}',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: kLiveGradient),
                      borderRadius: BorderRadius.circular(5)),
                  child: const Text('LIVE',
                      style: TextStyle(color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
              ]),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.black45,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(AppIcons.remove_red_eye_rounded,
                    color: Colors.white, size: 15),
                const SizedBox(width: 4),
                Text('$_viewers',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onClose,
              child: const CircleAvatar(radius: 16, backgroundColor: Colors.black45,
                  child: Icon(AppIcons.close, color: Colors.white, size: 18)),
            ),
          ]),
        ),

        // ── Floating hearts (рост) ───────────────────
        Positioned(right: 10, bottom: 80,
          child: SizedBox(width: 60, height: 260,
            child: Stack(alignment: Alignment.bottomCenter,
              children: _hearts.map((k) => _FloatingHeart(
                key: ValueKey(k),
                onDone: () { if (mounted) setState(() => _hearts.remove(k)); },
              )).toList()),
          ),
        ),

        // ── Comments (поёни чап) ─────────────────────
        Positioned(left: 12, right: 80, bottom: 74,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              reverse: true, // навтарин дар поён
              shrinkWrap: true,
              children: _comments.reversed.take(6).map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: RichText(text: TextSpan(children: [
                  TextSpan(text: '${c['username'] ?? ''}  ',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 13,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
                  TextSpan(text: (c['text'] ?? '').toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 13,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
                ])),
              )).toList(),
            ),
          ),
        ),

        // ── Comment input + like ─────────────────────
        Positioned(left: 12, right: 12, bottom: 12,
          child: Row(children: [
            Expanded(child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54),
                  borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _input,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Шарҳ...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none, isDense: true),
                )),
                GestureDetector(onTap: _send,
                    child: const Icon(AppIcons.send_rounded,
                        color: Colors.white, size: 20)),
              ]),
            )),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _like,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(AppIcons.favorite, color: Color(0xFFFF3040), size: 32),
                if (_likes > 0)
                  Text('$_likes', style: const TextStyle(color: Colors.white,
                      fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ]),
    ));
  }
}

// Як дили парвозкунанда — аз поён боло меравад ва нопадид мешавад.
class _FloatingHeart extends StatefulWidget {
  final VoidCallback onDone;
  const _FloatingHeart({super.key, required this.onDone});
  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward();
  late final double _dx = (_c.hashCode % 40) - 20.0;
  final List<Color> _palette = const [
    Color(0xFFFF3040), Color(0xFF00E87A), Color(0xFF00C6FF), Colors.white,
    Color(0xFFFF85A1),
  ];

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = _palette[_c.hashCode % _palette.length];
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Positioned(
          bottom: t * 230,
          right: 20 + _dx * t,
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.6 + (t < 0.2 ? t * 2 : 1.0),
              child: Icon(AppIcons.favorite, color: color, size: 26),
            ),
          ),
        );
      },
    );
  }
}
