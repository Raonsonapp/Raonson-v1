import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'feed_controller.dart';
import 'feed_state.dart';
import '../post/post_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedController>().loadInitialFeed();
    });
  }

  void _onScroll() {
    final controller = context.read<FeedController>();
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedController>(
      builder: (_, controller, __) {
        final FeedState state = controller.state;

        if (state.isLoading && state.posts.isEmpty) {
          return const Center(child: LoadingIndicator());
        }

        if (state.hasError) {
          return Center(
            child: Text(
              state.errorMessage ?? 'Unexpected error',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        if (state.posts.isEmpty) {
          return const EmptyState(
            title: 'No posts yet',
            subtitle: 'Follow users to see posts in your feed',
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: state.posts.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < state.posts.length) {
                return PostCard(post: state.posts[index]);
              }
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: LoadingIndicator()),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
