import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/reel_model.dart';
import 'reels_api.dart';

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
    _loadReels();
  }

  Future<void> _loadReels() async {
    try {
      final data = await ReelsApi.fetchReels();
      setState(() {
        reels = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No reels yet',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: reels.length,
        itemBuilder: (_, index) {
          return ReelItem(reel: reels[index]);
        },
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final Reel reel;
  const ReelItem({super.key, required this.reel});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController controller;
  bool liked = false;

  @override
  void initState() {
    super.initState();

    liked = widget.reel.liked;

    controller = VideoPlayerController.network(widget.reel.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        controller
          ..setLooping(true)
          ..play();
      });

    // 👁️ view
    ReelsApi.view(widget.reel.id);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _like() async {
    if (liked) return;

    final newLikes = await ReelsApi.like(widget.reel.id);

    setState(() {
      liked = true;
      widget.reel.likes = newLikes;
      widget.reel.liked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 🎥 VIDEO
        controller.value.isInitialized
            ? VideoPlayer(controller)
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

        // ❤️ ACTIONS (RIGHT)
        Positioned(
          right: 14,
          bottom: 120,
          child: Column(
            children: [
              GestureDetector(
                onTap: _like,
                child: AnimatedScale(
                  scale: liked ? 1.25 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    Icons.favorite,
                    size: 34,
                    color: liked ? Colors.red : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.reel.likes.toString(),
                style: const TextStyle(color: Colors.white),
              ),

              const SizedBox(height: 22),
              const Icon(Icons.chat_bubble_outline,
                  color: Colors.white, size: 30),
              const SizedBox(height: 6),
              const Text('0',
                  style: TextStyle(color: Colors.white, fontSize: 12)),

              const SizedBox(height: 22),
              const Icon(Icons.send, color: Colors.white, size: 28),

              const SizedBox(height: 22),
              const Icon(Icons.bookmark_border,
                  color: Colors.white, size: 28),
            ],
          ),
        ),

        // ℹ️ INFO (LEFT)
        Positioned(
          left: 14,
          bottom: 40,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.reel.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.reel.caption,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
