import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../feed_repository.dart';
import 'feed_controller.dart';
import 'feed_state.dart';
import '../post/post_card.dart';

import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';

import '../../navigation/drawer/app_drawer.dart';

import '../../app/app_routes.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FeedController(
        FeedRepository(),
      )..loadInitialFeed(),
      child: const _FeedShell(),
    );
  }
}

class _FeedShell extends StatefulWidget {
  const _FeedShell();

  @override
  State<_FeedShell> createState() => _FeedShellState();
}

class _FeedShellState extends State<_FeedShell> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
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
    return Scaffold(
      drawer: AppDrawer(
        onProfile: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, AppRoutes.profile);
        },
        onSaved: () {},
        onSettings: () {},
        onLogout: () {},
      ),
      appBar: _buildAppBar(context),
      body: _FeedTab(scrollController: _scrollController),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'Raonson',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _FeedTab extends StatelessWidget {
  final ScrollController scrollController;

  const _FeedTab({required this.scrollController});

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
            child: Text(state.errorMessage ?? 'Unexpected error'),
          );
        }

        if (state.posts.isEmpty) {
          return const EmptyState(
            icon: Icons.image_not_supported,
            title: 'No posts yet',
            subtitle: 'Follow users to see posts',
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.builder(
            controller: scrollController,
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
}
