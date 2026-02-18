import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/reel_model.dart';

class ReelsRepository {
  final ApiClient _api;

  ReelsRepository(this._api);

  Future<List<ReelModel>> fetchReels() async {
    final res = await _api.get(ApiEndpoints.reels);
    return (jsonDecode(res.data) as List)
        .map((e) => ReelModel.fromJson(e))
        .toList();
  }

  Future<void> likeReel(String reelId) async {
    await _api.post('${ApiEndpoints.reels}/$reelId/like');
  }
}
