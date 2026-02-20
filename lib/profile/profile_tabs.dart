import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../widgets/media_viewer.dart';

class ProfileTabs extends StatelessWidget {
  final List<PostModel> posts;
  final List<ReelModel> reels;

  const ProfileTabs({
    super.key,
    required this.posts,
    required this.reels,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.grid_on)),
              Tab(icon: Icon(Icons.video_collection)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _grid(
                  posts
                      .where((p) => p.media.isNotEmpty)
                      .map((p) => p.media.first['url'] ?? '')
                      .toList(),
                ),
                _grid(
                  reels.map((r) => r.videoUrl).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<String> urls) {
    if (urls.isEmpty) {
      return const Center(child: Text('No content'));
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
      ),
      itemCount: urls.length,
      itemBuilder: (_, i) => MediaViewer(
        url: urls[i], // ✅ фақат url
      ),
    );
  }
}
