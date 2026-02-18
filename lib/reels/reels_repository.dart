import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/reel_model.dart';

class ReelsRepository {
  final ApiClient _api = ApiClient.instance;

  /// =========================
  /// FETCH REELS
  /// =========================
  Future<List<ReelModel>> fetchReels() async {
    final response = await ApiClient.get(ApiEndpoints.reels);

    final List list = response.body.isNotEmpty
        ? (response.bodyBytes.isNotEmpty
            ? List.from(
                (jsonDecode(response.body) as List),
              )
            : [])
        : [];

    return list.map((e) => ReelModel.fromJson(e)).toList();
  }

  /// =========================
  /// LIKE REEL
  /// =========================
  Future<void> likeReel(String reelId) async {
    await ApiClient.post('${ApiEndpoints.reels}/$reelId/like');
  }
}
