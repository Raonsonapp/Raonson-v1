import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'search_controller.dart' show SearchController;
import 'search_state.dart';
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
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: controller.updateQuery,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const LoadingIndicator()
              : state.users.isEmpty && state.posts.isEmpty
                  ? const EmptyState(
                      title: 'Search Raonson',
                      subtitle: 'Find people and posts',
                    )
                  : ListView(
                      children: state.users
                          .map(
                            (u) => ListTile(
                              leading:
                                  Avatar(imageUrl: u.avatar, size: 40),
                              title: Text(u.username),
                            ),
                          )
                          .toList(),
                    ),
        ),
      ],
    );
  }
}
