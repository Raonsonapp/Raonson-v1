import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'feed_controller.dart';
import 'feed_state.dart';
import '../post/post_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import '../../app/app_routes.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FeedController(),
      child: const _FeedView(),
    );
  }
}

class _FeedView extends StatefulWidget {
  const _FeedView();

  @override
  State<_FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<_FeedView> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController()..addListener(_onScroll);

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

        return Scaffold(
          appBar: _buildAppBar(context),
          body: _buildBody(context, state, controller),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Text(
          'Raonson',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: isDark
                ? theme.colorScheme.primary
                : theme.colorScheme.secondary,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_box_outlined),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.create);
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.notifications);
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    FeedState state,
    FeedController controller,
  ) {
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
