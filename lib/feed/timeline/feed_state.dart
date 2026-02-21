import '../../models/post_model.dart';

class FeedState {
  final bool isLoading;
  final bool isRefreshing;
  final bool hasError;
  final String? errorMessage;
  final List<PostModel> posts;
  final bool hasMore;

  const FeedState({
    required this.isLoading,
    required this.isRefreshing,
    required this.hasError,
    required this.posts,
    required this.hasMore,
    this.errorMessage,
  });

  factory FeedState.initial() {
    return const FeedState(
      isLoading: true,   // starts loading immediately
      isRefreshing: false,
      hasError: false,
      posts: [],
      hasMore: false,    // ← false то посе ки маълумот наояд
    );
  }

  FeedState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? hasError,
    String? errorMessage,
    List<PostModel>? posts,
    bool? hasMore,
  }) {
    return FeedState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage,
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}
