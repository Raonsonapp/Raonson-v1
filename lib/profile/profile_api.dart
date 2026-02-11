import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/token_storage.dart';
import 'profile_model.dart';

class ProfileApi {
  static Future<Profile> getProfile(String userId) async {
    final token = await TokenStorage.read();

    final res = await http.get(
      Uri.parse('${Api.baseUrl}/profile/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return Profile.fromJson(jsonDecode(res.body));
  }

  static Future<void> toggleFollow(String userId) async {
    final token = await TokenStorage.read();

    await http.post(
      Uri.parse('${Api.baseUrl}/follow/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
