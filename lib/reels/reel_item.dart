import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../models/reel_model.dart';

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
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    // 👁 VIEW (1 бор)
    widget.onView();

    _controller = VideoPlayerController.network(widget.reel.videoUrl)
      ..initialize().then((_) {
        _controller
          ..setLooping(true)
          ..play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ❤️ LIKE
  void _handleLike() {
    if (widget.reel.liked) return;

    setState(() {
      widget.reel.liked = true;
      widget.reel.likes += 1;
    });

    widget.onLike();
  }

  // 📤 SHARE
  void _handleShare() {
    final text =
        '🎬 ${widget.reel.caption}\n\nWatch on Raonson:\n${widget.reel.videoUrl}';

    Share.share(text);

    setState(() {
      widget.reel.shares += 1;
    });
  }

  Widget _icon(String path, {Color color = Colors.white}) {
    return SvgPicture.asset(
      path,
      width: 28,
      height: 28,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 🎥 VIDEO
        _controller.value.isInitialized
            ? VideoPlayer(_controller)
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

        // 👉 ACTIONS (RIGHT)
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              // ❤️ LIKE
              GestureDetector(
                onTap: _handleLike,
                child: AnimatedScale(
                  scale: widget.reel.liked ? 1.25 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: _icon(
                    'assets/icons/heart.svg',
                    color: widget.reel.liked ? Colors.red : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.reel.likes}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),

              const SizedBox(height: 22),

              // 💬 COMMENT (ҳоло UI, backend аллакай дорӣ)
              _icon('assets/icons/comment.svg'),
              const SizedBox(height: 4),
              Text(
                '${widget.reel.comments}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),

              const SizedBox(height: 22),

              // 📤 SHARE
              GestureDetector(
                onTap: _handleShare,
                child: _icon('assets/icons/share.svg'),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.reel.shares}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),

              const SizedBox(height: 22),

              // 🔖 SAVE (UI, backend қадамӣ)
              _icon('assets/icons/save.svg'),
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
