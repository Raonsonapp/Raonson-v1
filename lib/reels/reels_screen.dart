import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    load();
  }

  Future<void> load() async {
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
          child: Text('No reels yet',
              style: TextStyle(color: Colors.white)),
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

class ReelItem extends StatefulWidget {
  final Reel reel;
  const ReelItem({super.key, required this.reel});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.network(widget.reel.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        controller.play();
        controller.setLooping(true);
        ReelsApi.view(widget.reel.id); // 👁️ view +1
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget icon(String path, {Color color = Colors.white}) {
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
        controller.value.isInitialized
            ? VideoPlayer(controller)
            : const Center(
                child: CircularProgressIndicator(color: Colors.white)),

        // ACTIONS
        Positioned(
          right: 14,
          bottom: 120,
          child: Column(
            children: [
              GestureDetector(
                onTap: () async {
                  final likes =
                      await ReelsApi.like(widget.reel.id);
                  setState(() {
                    widget.reel.likes = likes;
                    widget.reel.liked = true;
                  });
                },
                child: icon(
                  'assets/icons/heart.svg',
                  color: widget.reel.liked
                      ? Colors.red
                      : Colors.white,
                ),
              ),
              Text('${widget.reel.likes}',
                  style: const TextStyle(color: Colors.white)),

              const SizedBox(height: 22),
              icon('assets/icons/comment.svg'),
              Text('${widget.reel.comments}',
                  style: const TextStyle(color: Colors.white)),

              const SizedBox(height: 22),
              icon('assets/icons/share.svg'),

              const SizedBox(height: 22),
              GestureDetector(
                onTap: () {
                  setState(() {
                    widget.reel.saved = !widget.reel.saved;
                  });
                },
                child: icon(
                  'assets/icons/save.svg',
                  color: widget.reel.saved
                      ? Colors.yellow
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),

        // INFO
        Positioned(
          left: 14,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.reel.user,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(widget.reel.caption,
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}
