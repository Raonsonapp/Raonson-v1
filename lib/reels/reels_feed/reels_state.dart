import '../../models/reel_model.dart';

class ReelsState {
  final List<ReelModel> reels;
  final bool isLoading;
  final bool hasError;

  const ReelsState({
    required this.reels,
    required this.isLoading,
    required this.hasError,
  });

  factory ReelsState.initial() {
    return const ReelsState(
      reels: [],
      isLoading: false,
      hasError: false,
    );
  }

  ReelsState copyWith({
    List<ReelModel>? reels,
    bool? isLoading,
    bool? hasError,
  }) {
    return ReelsState(
      reels: reels ?? this.reels,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
    );
  }
}
