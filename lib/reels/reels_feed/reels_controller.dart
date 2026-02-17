import 'package:flutter/foundation.dart';

import 'reels_state.dart';
import '../reels_repository.dart';
import '../../models/reel_model.dart';

class ReelsController extends ChangeNotifier {
  final ReelsRepository _repository;

  ReelsState _state = ReelsState.initial();
  ReelsState get state => _state;

  ReelsController(this._repository);

  Future<void> loadReels() async {
    _state = _state.copyWith(isLoading: true, hasError: false);
    notifyListeners();

    try {
      final List<ReelModel> data = await _repository.fetchReels();
      _state = _state.copyWith(reels: data, isLoading: false);
    } catch (_) {
      _state = _state.copyWith(isLoading: false, hasError: true);
    }

    notifyListeners();
  }

  Future<void> likeReel(String reelId) async {
    await _repository.likeReel(reelId);
  }
}
