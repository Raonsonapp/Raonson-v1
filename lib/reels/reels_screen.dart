import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final List<String> videos = [
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: videos.length,
        itemBuilder: (_, index) => ReelItem(videoUrl: videos[index]),
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final String videoUrl;
  const ReelItem({super.key, required this.videoUrl});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController controller;
  bool isLiked = false;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        controller.play();
        controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _svgIcon(String path) {
    return SvgPicture.asset(
      path,
      width: 28,
      height: 28,
      colorFilter: const ColorFilter.mode(
        Colors.white,
        BlendMode.srcIn,
      ),
    );
  }

  Widget _animatedLikeButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isLiked = !isLiked;
        });
      },
      child: AnimatedScale(
        scale: isLiked ? 1.25 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: SvgPicture.asset(
            'assets/icons/heart.svg',
            key: ValueKey(isLiked),
            width: 28,
            height: 28,
            colorFilter: ColorFilter.mode(
              isLiked ? Colors.red : Colors.white,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        controller.value.isInitialized
            ? VideoPlayer(controller)
            : const Center(child: CircularProgressIndicator()),

        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              _animatedLikeButton(),
              const SizedBox(height: 6),
              const Text('45.2K',
                  style: TextStyle(color: Colors.white, fontSize: 12)),

              const SizedBox(height: 22),
              _svgIcon('assets/icons/comment.svg'),
              const SizedBox(height: 6),
              const Text('120',
                  style: TextStyle(color: Colors.white, fontSize: 12)),

              const SizedBox(height: 22),
              _svgIcon('assets/icons/share.svg'),

              const SizedBox(height: 22),
              _svgIcon('assets/icons/save.svg'),
            ],
          ),
        ),

        Positioned(
          left: 12,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('olivia_martin',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Sunset vibes 🌅 #beachlife',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}
