import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'reels_controller.dart';
import '../reels_repository.dart';
import '../../widgets/loading_indicator.dart';
import '../player/reel_player.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReelsController(
        repository: ReelsRepository(),
      )..loadReels(),
      child: const _ReelsView(),
    );
  }
}

class _ReelsView extends StatelessWidget {
  const _ReelsView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReelsController>();
    final state = controller.state;

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: LoadingIndicator()),
      );
    }

    if (state.hasError) {
      return const Scaffold(
        body: Center(
          child: Text('Failed to load reels'),
        ),
      );
    }

    if (state.reels.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No reels available'),
        ),
      );
    }

    return Scaffold(
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: state.reels.length,
        itemBuilder: (context, index) {
          final reel = state.reels[index];
          return ReelPlayer(
            reel: reel,
            onLike: () => controller.likeReel(reel.id),
          );
        },
      ),
    );
  }
}
