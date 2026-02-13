import 'package:flutter/material.dart';
import 'reels_api.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late Future<List<dynamic>> reels;

  @override
  void initState() {
    super.initState();
    reels = ReelsApi.getReels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder(
        future: reels,
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return const Center(child: Text('Error loading reels'));
          }

          final data = s.data as List;

          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: data.length,
            itemBuilder: (_, i) {
              final reel = data[i];
              return Stack(
                children: [
                  /// 🔥 Video placeholder (ба video_player иваз мешавад)
                  Center(
                    child: Text(
                      reel['title'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),

                  /// ❤️ Actions
                  Positioned(
                    right: 16,
                    bottom: 120,
                    child: Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.white),
                          onPressed: () =>
                              ReelsApi.likeReel(reel['id']),
                        ),
                        const SizedBox(height: 20),
                        const Icon(Icons.comment, color: Colors.white),
                        const SizedBox(height: 20),
                        const Icon(Icons.share, color: Colors.white),
                      ],
                    ),
                  ),

                  /// 👤 User + caption
                  Positioned(
                    left: 16,
                    bottom: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${reel['user'] ?? 'user'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          reel['caption'] ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  )
                ],
              );
            },
          );
        },
      ),
    );
  }
}
