import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'search_controller.dart';
import 'search_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RaonsonSearchController(),
      child: const _SearchBody(),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody();

  @override
  Widget build(BuildContext context) {
    final controller =
        context.watch<RaonsonSearchController>();
    final SearchState state = controller.state;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: controller.updateQuery,
            decoration: const InputDecoration(
              hintText: 'Search users or posts',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildResults(state),
        ),
      ],
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
      children: state.users.map(
        (u) => ListTile(
          leading: Avatar(imageUrl: u.avatar, size: 40),
          title: Text(u.username),
          trailing: u.verified
              ? const Icon(
                  Icons.verified,
                  color: Colors.blue,
                  size: 18,
                )
              : null,
        ),
      ).toList(),
    );
  }
}
