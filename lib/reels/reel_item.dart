import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/reel_model.dart';

class ReelItem extends StatefulWidget {
  final Reel reel;
  final VoidCallback onLike;
  final VoidCallback onView;
  final VoidCallback onComment; // 👈 ИЛОВА

  const ReelItem({
    super.key,
    required this.reel,
    required this.onLike,
    required this.onView,
    required this.onComment,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController _controller;
  bool _viewSent = false; // 👁️ prevent double view

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.network(widget.reel.videoUrl)
      ..initialize().then((_) {
        _controller
          ..setLooping(true)
          ..play();
        setState(() {});
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 👁️ VIEW – ТАНҲО 1 БОР
    if (!_viewSent) {
      widget.onView();
      _viewSent = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _svg(String path,
      {double size = 28, Color color = Colors.white}) {
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 🎬 VIDEO
        _controller.value.isInitialized
            ? VideoPlayer(_controller)
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

        // ❤️ ACTIONS (RIGHT)
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              // ❤️ LIKE
              GestureDetector(
                onTap: widget.onLike,
                child: AnimatedScale(
                  scale: widget.reel.liked ? 1.25 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: _svg(
                      'assets/icons/heart.svg',
                      key: ValueKey(widget.reel.liked),
                      color: widget.reel.liked
                          ? Colors.red
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.reel.likes}',
                style: const TextStyle(color: Colors.white),
              ),

              const SizedBox(height: 22),

              // 💬 COMMENT
              GestureDetector(
                onTap: widget.onComment,
                child: _svg('assets/icons/comment.svg', size: 26),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.reel.comments}',
                style: const TextStyle(color: Colors.white),
              ),

              const SizedBox(height: 22),

              // 📤 SHARE
              _svg('assets/icons/share.svg', size: 26),

              const SizedBox(height: 22),

              // 🔖 SAVE
              _svg('assets/icons/save.svg', size: 26),
            ],
          ),
        ),

        // ℹ️ INFO (LEFT BOTTOM)
        Positioned(
          left: 12,
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
