import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelItem extends StatefulWidget {
  final String videoUrl;
  final String username;
  final String caption;
  final int initialLikes;

  const ReelItem({
    super.key,
    required this.videoUrl,
    required this.username,
    required this.caption,
    required this.initialLikes,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late int likes;
  bool isLiked = false;
  bool showHeart = false;

  late AnimationController heartController;
  late Animation<double> heartScale;

  @override
  void initState() {
    super.initState();
    likes = widget.initialLikes;

    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        _controller.setLooping(true);
        _controller.play();
        setState(() {});
      });

    heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    heartScale =
        Tween<double>(begin: 0.6, end: 1.4).animate(CurvedAnimation(
      parent: heartController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    heartController.dispose();
    super.dispose();
  }

  String formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  void toggleLike() {
    if (!isLiked) {
      setState(() {
        isLiked = true;
        likes++;
        showHeart = true;
      });
      heartController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 700), () {
        setState(() => showHeart = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: toggleLike,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 🎬 VIDEO
          _controller.value.isInitialized
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator()),

          // ❤️ DOUBLE TAP HEART
          if (showHeart)
            ScaleTransition(
              scale: heartScale,
              child: const Icon(Icons.favorite,
                  color: Colors.white, size: 100),
            ),

          // 👉 ACTIONS
          Positioned(
            right: 14,
            bottom: 120,
            child: Column(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                    size: 34,
                  ),
                  onPressed: toggleLike,
                ),
                Text(formatCount(likes),
                    style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 20),

                const Icon(Icons.mode_comment_outlined,
                    color: Colors.white, size: 30),
                const SizedBox(height: 6),
                const Text('56.3K',
                    style: TextStyle(color: Colors.white)),
                const SizedBox(height: 20),

                const Icon(Icons.send_outlined,
                    color: Colors.white, size: 30),
                const SizedBox(height: 20),

                const Icon(Icons.bookmark_border,
                    color: Colors.white, size: 30),
              ],
            ),
          ),

          // 📝 CAPTION
          Positioned(
            left: 14,
            bottom: 40,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${widget.username}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.caption,
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
