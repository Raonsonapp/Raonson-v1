import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/reel_model.dart';
import '../core/api.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  List<Reel> reels = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchReels();
  }

  Future<void> fetchReels() async {
    try {
      final res = await Api.get('/reels');
      final List data = jsonDecode(res.body);

      setState(() {
        reels = data
            .map((e) => Reel(
                  id: e['_id'],
                  username: e['username'] ?? 'user',
                  caption: e['caption'] ?? '',
                  videoUrl: e['videoUrl'],
                  likes: e['likesCount'] ?? 0,
                  liked: false,
                ))
            .toList();
        loading = false;
      });
    } catch (e) {
      loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: reels.length,
        itemBuilder: (_, i) => ReelItem(
          reel: reels[i],
          onLike: () => toggleLike(i),
          onView: () => addView(reels[i].id),
        ),
      ),
    );
  }

  // ❤️ LIKE (optimistic + backend)
  Future<void> toggleLike(int index) async {
    final reel = reels[index];
    final oldLiked = reel.liked;
    final oldLikes = reel.likes;

    setState(() {
      reel.liked = !oldLiked;
      reel.likes += oldLiked ? -1 : 1;
    });

    try {
      final res = await Api.post('/reels/like/${reel.id}');
      final data = jsonDecode(res.body);

      setState(() {
        reel.liked = data['liked'];
        reel.likes = data['likesCount'];
      });
    } catch (_) {
      setState(() {
        reel.liked = oldLiked;
        reel.likes = oldLikes;
      });
    }
  }

  // 👁️ VIEW
  Future<void> addView(String reelId) async {
    try {
      await Api.post('/reels/view/$reelId');
    } catch (_) {}
  }
}

// ===================================================================
// ======================== REEL ITEM =================================
// ===================================================================

class ReelItem extends StatefulWidget {
  final Reel reel;
  final VoidCallback onLike;
  final VoidCallback onView;

  const ReelItem({
    super.key,
    required this.reel,
    required this.onLike,
    required this.onView,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController controller;
  bool viewed = false;

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.network(widget.reel.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        controller
          ..setLooping(true)
          ..setVolume(0)
          ..play();
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!viewed) {
        widget.onView();
        viewed = true;
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        controller.value.isInitialized
            ? VideoPlayer(controller)
            : const Center(
                child:
                    CircularProgressIndicator(color: Colors.white),
              ),

        // ❤️ ACTIONS (RIGHT)
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              GestureDetector(
                onTap: widget.onLike,
                child: AnimatedScale(
                  scale: widget.reel.liked ? 1.25 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    Icons.favorite,
                    color: widget.reel.liked
                        ? Colors.red
                        : Colors.white,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _format(widget.reel.likes),
                style:
                    const TextStyle(color: Colors.white),
              ),

              const SizedBox(height: 22),
              const Icon(Icons.chat_bubble_outline,
                  color: Colors.white, size: 30),
              const SizedBox(height: 22),
              const Icon(Icons.send,
                  color: Colors.white, size: 28),
              const SizedBox(height: 22),
              const Icon(Icons.bookmark_border,
                  color: Colors.white, size: 28),
            ],
          ),
        ),

        // ℹ️ INFO (LEFT)
        Positioned(
          left: 12,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.reel.username}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                widget.reel.caption,
                style:
                    const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
