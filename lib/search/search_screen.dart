import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'search_controller.dart';
import '../../widgets/avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SearchController(),
      child: const _SearchBody(),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SearchController>();
    final state = controller.state;

    return Column(
      children: [
        _searchField(controller),
        Expanded(
          child: _buildResults(state),
        ),
      ],
    );
  }

  Widget _searchField(SearchController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: controller.updateQuery,
        decoration: const InputDecoration(
          hintText: 'Search users or posts',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(SearchState state) {
    if (state.isLoading) {
      return const Center(child: LoadingIndicator());
    }

    if (state.users.isEmpty && state.posts.isEmpty) {
      return const EmptyState(
        title: 'Search Raonson',
        subtitle: 'Find people and posts',
      );
    }

    return ListView(
      children: [
        if (state.users.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Users',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...state.users.map(
            (u) => ListTile(
              leading: Avatar(
                imageUrl: u.avatarUrl,
                size: 40,
              ),
              title: Text(u.username),
              trailing: u.verified
                  ? const Icon(
                      Icons.verified,
                      color: Colors.blue,
                      size: 18,
                    )
                  : null,
            ),
          ),
        ],
        if (state.posts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Posts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...state.posts.map(
            (p) => ListTile(
              title: Text(p.caption),
              subtitle: Text(
                p.user.username,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
