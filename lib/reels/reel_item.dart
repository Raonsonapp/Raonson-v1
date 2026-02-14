import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    widget.onView();

    controller = VideoPlayerController.network(widget.reel.videoUrl)
      ..initialize().then((_) {
        controller
          ..setLooping(true)
          ..play();
        setState(() {});
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
            : const Center(child: CircularProgressIndicator()),

        // ❤️ ACTIONS
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              GestureDetector(
                onTap: widget.onLike,
                child: AnimatedScale(
                  scale: widget.reel.liked ? 1.25 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: SvgPicture.asset(
                    'assets/icons/heart.svg',
                    width: 28,
                    colorFilter: ColorFilter.mode(
                      widget.reel.liked ? Colors.red : Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              Text('${widget.reel.likes}',
                  style: const TextStyle(color: Colors.white)),

              const SizedBox(height: 22),
              SvgPicture.asset('assets/icons/comment.svg',
                  width: 26, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
              Text('${widget.reel.comments}',
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),

        // ℹ️ INFO
        Positioned(
          left: 12,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${widget.reel.username}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(widget.reel.caption,
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}
