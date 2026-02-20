import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/api/api_client.dart';
import '../reels_repository.dart';
import '../../models/reel_model.dart';
import '../../app/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          _ReelsVM(ReelsRepository(ApiClient.instance))..load(),
      child: const _ReelsView(),
    );
  }
}

class _ReelsVM extends ChangeNotifier {
  final ReelsRepository _repo;
  _ReelsVM(this._repo);

  List<ReelModel> reels = [];
  bool loading = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      reels = await _repo.fetchReels();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> like(String id) => _repo.likeReel(id);
}

class _ReelsView extends StatelessWidget {
  const _ReelsView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<_ReelsVM>();

    if (vm.loading && vm.reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: LoadingIndicator()),
      );
    }

    if (vm.reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: EmptyState(
          icon: Icons.video_collection_outlined,
          title: 'No Reels',
          subtitle: 'Videos will appear here',
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: vm.reels.length,
        itemBuilder: (context, i) =>
            _ReelItem(reel: vm.reels[i], onLike: () => vm.like(vm.reels[i].id)),
      ),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final ReelModel reel;
  final VoidCallback onLike;
  const _ReelItem({required this.reel, required this.onLike});

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  late bool _liked;

  @override
  void initState() {
    super.initState();
    _liked = widget.reel.isLiked;
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background video/thumbnail
        CachedNetworkImage(
          imageUrl: reel.videoUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) =>
              Container(color: Colors.black87),
        ),

        // Gradient overlay
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Color(0x99000000),
                Color(0xCC000000),
              ],
              stops: [0, 0.5, 0.8, 1],
            ),
          ),
        ),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Reels',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
        ),

        // Right action buttons (like Image 3)
        Positioned(
          right: 14,
          bottom: 100,
          child: Column(
            children: [
              _actionBtn(
                icon: _liked ? Icons.favorite : Icons.favorite,
                color: _liked ? AppColors.red : Colors.white,
                label: _formatCount(reel.likesCount),
                onTap: () {
                  setState(() => _liked = !_liked);
                  widget.onLike();
                },
                glow: _liked,
              ),
              const SizedBox(height: 20),
              _actionBtn(
                icon: Icons.chat_bubble_rounded,
                color: Colors.white,
                label: _formatCount(reel.commentsCount),
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _actionBtn(
                icon: Icons.reply_rounded,
                color: Colors.white,
                label: '',
                onTap: () {},
                mirrorX: true,
              ),
              const SizedBox(height: 20),
              _actionBtn(
                icon: Icons.bookmark_border,
                color: Colors.white,
                label: '',
                onTap: () {},
              ),
            ],
          ),
        ),

        // Bottom user info (like Image 3)
        Positioned(
          left: 14,
          right: 80,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(
                    imageUrl: reel.user.avatar,
                    size: 36,
                    glowBorder: true,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    reel.user.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (reel.caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  reel.caption,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool glow = false,
    bool mirrorX = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Transform.scale(
            scaleX: mirrorX ? -1 : 1,
            child: Icon(
              icon,
              size: 32,
              color: color,
              shadows: glow
                  ? [Shadow(color: AppColors.red.withOpacity(0.8), blurRadius: 12)]
                  : null,
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
