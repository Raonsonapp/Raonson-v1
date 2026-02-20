import '../models/user_model.dart';
import '../models/post_model.dart';

class SearchState {
  final bool isLoading;
  final String query;
  final List<UserModel> users;
  final List<PostModel> posts;
  final String? error;

  const SearchState({
    required this.isLoading,
    required this.query,
    required this.users,
    required this.posts,
    this.error,
  });

  factory SearchState.initial() {
    return const SearchState(
      isLoading: false,
      query: '',
      users: [],
      posts: [],
    );
  }

  SearchState copyWith({
    bool? isLoading,
    String? query,
    List<UserModel>? users,
    List<PostModel>? posts,
    String? error,
  }) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      users: users ?? this.users,
      posts: posts ?? this.posts,
      error: error,
    );
  }
}
