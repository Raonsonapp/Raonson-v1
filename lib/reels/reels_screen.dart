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
    // 🔴 ҲОЗИР ВИДЕОҲОИ ТЕСТӢ (иваз мекунӣ)
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: videos.length,
        itemBuilder: (context, index) {
          return ReelItem(videoUrl: videos[index]);
        },
      ),
    );
  }
}

// --------------------------------------------------

class ReelItem extends StatefulWidget {
  final String videoUrl;

  const ReelItem({super.key, required this.videoUrl});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller
          ..setLooping(true)
          ..play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _svgIcon(String path, {double size = 28}) {
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(
        Colors.white,
        BlendMode.srcIn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🎥 VIDEO
        Positioned.fill(
          child: _controller.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
        ),

        // ❤️ ACTION ICONS (RIGHT)
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              _svgIcon('assets/icons/heart.svg'),
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

        // 👤 USER + CAPTION (LEFT BOTTOM)
        Positioned(
          left: 12,
          bottom: 90,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'olivia_martin',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
                      'Follow',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Sunset vibes 🌅  #beachlife #flutter',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
