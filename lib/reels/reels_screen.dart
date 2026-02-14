import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../reels/reels_api.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  List<Map<String, dynamic>> reels = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadReels();
  }

  Future<void> loadReels() async {
    try {
      final data = await ReelsApi.fetchReels();
      setState(() {
        reels = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      loading = false;
      setState(() {});
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
        itemBuilder: (_, i) => ReelItem(reel: reels[i]),
      ),
    );
  }
}

// =======================================================

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reel;
  const ReelItem({super.key, required this.reel});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController controller;

  late int likes;
  bool liked = false;

  @override
  void initState() {
    super.initState();

    likes = widget.reel['likes'] ?? 0;

    controller = VideoPlayerController.network(
      widget.reel['videoUrl'],
    )..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        controller
          ..setLooping(true)
          ..play();
      });

    // 👁 VIEW COUNT (+1 once)
    ReelsApi.addView(widget.reel['id']);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void onLike() {
    if (liked) return;

    setState(() {
      liked = true;
      likes += 1;
    });

    ReelsApi.like(widget.reel['id']);
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

        // ❤️💬✈️🔖 ACTIONS
        Positioned(
          right: 14,
          bottom: 120,
          child: Column(
            children: [
              GestureDetector(
                onTap: onLike,
                child: Icon(
                  Icons.favorite,
                  size: 36,
                  color: liked ? Colors.red : Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$likes',
                style: const TextStyle(color: Colors.white),
              ),

              const SizedBox(height: 22),
              const Icon(
                Icons.mode_comment_outlined,
                color: Colors.white,
                size: 30,
              ),

              const SizedBox(height: 22),
              const Icon(
                Icons.send,
                color: Colors.white,
                size: 28,
              ),

              const SizedBox(height: 22),
              const Icon(
                Icons.bookmark_border,
                color: Colors.white,
                size: 28,
              ),
            ],
          ),
        ),

        // ℹ️ USER + CAPTION
        Positioned(
          left: 14,
          bottom: 40,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.reel['user'] ?? 'unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.reel['caption'] ?? '',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
