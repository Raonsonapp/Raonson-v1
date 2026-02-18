import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/reel_model.dart';

class ReelsRepository {
  final ApiClient _api = ApiClient.instance;

  Future<List<ReelModel>> fetchReels() async {
    final res = await _api.getRequest(ApiEndpoints.reels);

    final List list = jsonDecode(res.body);
    return list.map((e) => ReelModel.fromJson(e)).toList();
  }

  Future<void> likeReel(String reelId) async {
    await _api.postRequest('${ApiEndpoints.reels}/$reelId/like');
  }
}
