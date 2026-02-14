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
    loadReels();
  }

  Future<void> loadReels() async {
    reels = await ReelsApi.fetchReels();
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Ҳоло ягон Reels нест',
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

// ======================
// SINGLE REEL
// ======================
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

    controller = VideoPlayerController.network(widget.reel.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        controller.play();
        controller.setLooping(true);
      });

    // 👁️ VIEW
    ReelsApi.view(widget.reel.id);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void onLike() async {
    await ReelsApi.like(widget.reel.id);
    setState(() {
      liked = true;
      widget.reel.likes += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // VIDEO
        controller.value.isInitialized
            ? VideoPlayer(controller)
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

        // RIGHT ACTIONS
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
              Text(
                '${widget.reel.likes}',
                style: const TextStyle(color: Colors.white),
              ),

              const SizedBox(height: 22),

              const Icon(Icons.mode_comment_outlined,
                  color: Colors.white, size: 30),
              const SizedBox(height: 6),
              const Text('0', style: TextStyle(color: Colors.white)),

              const SizedBox(height: 22),

              const Icon(Icons.send, color: Colors.white, size: 28),

              const SizedBox(height: 22),

              const Icon(Icons.bookmark_border,
                  color: Colors.white, size: 28),
            ],
          ),
        ),

        // LEFT INFO
        Positioned(
          left: 14,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '@user',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
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
