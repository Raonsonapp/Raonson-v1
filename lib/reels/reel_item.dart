import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/reel_model.dart';
import 'reels_api.dart';

class ReelItem extends StatefulWidget {
  final Reel reel;
  const ReelItem({super.key, required this.reel});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController controller;
  bool likedOnce = false;

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.network(widget.reel.videoUrl)
      ..initialize().then((_) {
        controller
          ..setLooping(true)
          ..play();
        setState(() {});
      });

    // 👁 VIEW
    ReelsApi.addView(widget.reel.id);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> onLike() async {
    if (likedOnce) return;

    setState(() {
      likedOnce = true;
      widget.reel.likes += 1;
    });

    try {
      final newLikes = await ReelsApi.like(widget.reel.id);
      setState(() => widget.reel.likes = newLikes);
    } catch (_) {}
  }

  Future<void> onSave() async {
    final saved = await ReelsApi.toggleSave(widget.reel.id);
    setState(() => widget.reel.saved = saved);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        controller.value.isInitialized
            ? VideoPlayer(controller)
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

        // ACTIONS
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              GestureDetector(
                onTap: onLike,
                child: AnimatedScale(
                  scale: likedOnce ? 1.25 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: SvgPicture.asset(
                    'assets/icons/heart.svg',
                    width: 30,
                    colorFilter: ColorFilter.mode(
                      likedOnce ? Colors.red : Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              Text('${widget.reel.likes}',
                  style: const TextStyle(color: Colors.white)),

              const SizedBox(height: 22),
              SvgPicture.asset(
                'assets/icons/comment.svg',
                width: 26,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
              const Text('0',
                  style: TextStyle(color: Colors.white)),

              const SizedBox(height: 22),
              SvgPicture.asset(
                'assets/icons/share.svg',
                width: 26,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),

              const SizedBox(height: 22),
              GestureDetector(
                onTap: onSave,
                child: SvgPicture.asset(
                  widget.reel.saved
                      ? 'assets/icons/save_filled.svg'
                      : 'assets/icons/save.svg',
                  width: 26,
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ],
          ),
        ),

        // INFO
        Positioned(
          left: 12,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.reel.user}',
                style: const TextStyle(
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
