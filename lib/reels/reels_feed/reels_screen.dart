import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../reels_repository.dart';
import '../../models/reel_model.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_viewer.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReelsController(
        ReelsRepository(ApiClient.instance),
      )..loadReels(),
      child: const _ReelsView(),
    );
  }
}

// =======================================================
// CONTROLLER
// =======================================================

class ReelsController extends ChangeNotifier {
  final ReelsRepository _repository;

  ReelsController(this._repository);

  bool isLoading = false;
  List<ReelModel> reels = [];

  Future<void> loadReels() async {
    if (isLoading) return;

    isLoading = true;
    notifyListeners();

    try {
      reels = await _repository.fetchReels();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> likeReel(String reelId) async {
    await _repository.likeReel(reelId);
  }
}

// =======================================================
// VIEW
// =======================================================

class _ReelsView extends StatelessWidget {
  const _ReelsView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReelsController>();

    if (controller.isLoading && controller.reels.isEmpty) {
      return const Center(child: LoadingIndicator());
    }

    if (controller.reels.isEmpty) {
      return const EmptyState(
        icon: Icons.video_collection_outlined,
        title: 'No reels',
        subtitle: 'Videos will appear here',
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: controller.reels.length,
      itemBuilder: (context, index) {
        final reel = controller.reels[index];

        return Stack(
          fit: StackFit.expand,
          children: [
            /// 🎥 VIDEO
            MediaViewer(
              url: reel.videoUrl,
              type: 'video',
            ),

            /// ❤️ ACTIONS
            Positioned(
              right: 16,
              bottom: 80,
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      reel.isLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: reel.isLiked ? Colors.red : Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      controller.likeReel(reel.id);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.share,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
