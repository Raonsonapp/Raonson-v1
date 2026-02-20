import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/reel_model.dart';

class ReelsRepository {
  final ApiClient _api;
  ReelsRepository(this._api);

  Future<List<ReelModel>> fetchReels({int page = 1, int limit = 20}) async {
    final res = await _api.get(
      ApiEndpoints.reels,
      query: {'page': '$page', 'limit': '$limit'},
    );
    final body = jsonDecode(res.body);
    final List list = body is Map ? (body['reels'] ?? []) : body as List;
    return list.map((e) => ReelModel.fromJson(e)).toList();
  }

  Future<void> likeReel(String reelId) async {
    await _api.post('${ApiEndpoints.reels}/$reelId/like');
  }

  Future<void> saveReel(String reelId) async {
    await _api.post('${ApiEndpoints.reels}/$reelId/save');
  }

  Future<void> addView(String reelId) async {
    await _api.post('${ApiEndpoints.reels}/$reelId/view');
  }
}
