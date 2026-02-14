import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/reel_model.dart';
import '../comments/comments_sheet.dart';

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

    // 👁 VIEW
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

  Widget _icon(String path,
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
        // 🎥 VIDEO
        _controller.value.isInitialized
            ? VideoPlayer(_controller)
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

        // ❤️💬📤🔖 ACTIONS
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              // LIKE
              GestureDetector(
                onTap: widget.onLike,
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

              // COMMENT
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        CommentsSheet(reelId: widget.reel.id),
                  );
                },
                child: _icon('assets/icons/comment.svg'),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.reel.comments}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),

              const SizedBox(height: 22),

              // SHARE (UI ready)
              _icon('assets/icons/share.svg'),

              const SizedBox(height: 22),

              // SAVE (UI ready)
              _icon('assets/icons/save.svg'),
            ],
          ),
        ),

        // ℹ️ USER + CAPTION
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
