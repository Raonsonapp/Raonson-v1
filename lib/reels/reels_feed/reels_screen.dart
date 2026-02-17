import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'reels_controller.dart';
import '../../widgets/loading_indicator.dart';
import '../player/reel_player.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context.read<ReelsController>().loadReels(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReelsController>();
    final state = controller.state;

    if (state.isLoading) {
      return const Center(child: LoadingIndicator());
    }

    if (state.hasError) {
      return const Center(
        child: Text(
          'Failed to load reels',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: state.reels.length,
      itemBuilder: (context, index) {
        final reel = state.reels[index];
        return ReelPlayer(
          reel: reel,
          onLike: () => controller.likeReel(reel.id),
        );
      },
    );
  }
}
