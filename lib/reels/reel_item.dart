import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/reel_model.dart';
import '../reels/reels_api.dart';
import 'comment_sheet.dart';

class ReelItem extends StatefulWidget {
  final Reel reel;
  final VoidCallback onView;

  const ReelItem({
    super.key,
    required this.reel,
    required this.onView,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController controller;
  late bool liked;
  late int likes;

  @override
  void initState() {
    super.initState();
    widget.onView();

    liked = widget.reel.liked;
    likes = widget.reel.likes;

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

  Future<void> onLike() async {
    // 🔥 Optimistic UI
    setState(() {
      liked = !liked;
      likes += liked ? 1 : -1;
    });

    final res = await ReelsApi.toggleLike(widget.reel.id);

    // 🔁 Sync from backend
    setState(() {
      liked = res['liked'];
      likes = res['likes'];
    });
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
                onTap: onLike,
                child: AnimatedScale(
                  scale: liked ? 1.25 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: SvgPicture.asset(
                    'assets/icons/heart.svg',
                    width: 28,
                    colorFilter: ColorFilter.mode(
                      liked ? Colors.red : Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('$likes',
                  style: const TextStyle(color: Colors.white)),

              const SizedBox(height: 22),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) =>
                        CommentSheet(reelId: widget.reel.id),
                  );
                },
                child: SvgPicture.asset(
                  'assets/icons/comment.svg',
                  width: 26,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),

              const SizedBox(height: 22),
              SvgPicture.asset('assets/icons/share.svg',
                  width: 26,
                  colorFilter: const ColorFilter.mode(
                      Colors.white, BlendMode.srcIn)),

              const SizedBox(height: 22),
              SvgPicture.asset('assets/icons/save.svg',
                  width: 26,
                  colorFilter: const ColorFilter.mode(
                      Colors.white, BlendMode.srcIn)),
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              Text(widget.reel.caption,
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}
