import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api/api.dart';
import 'profile_model.dart';

class ProfileApi {
  static Future<Profile> getProfile(String userId) async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/profile/$userId'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load profile');
    }

    return Profile.fromJson(jsonDecode(res.body));
  }

  static Future<void> toggleFollow(String userId) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/follow/$userId'),
    );
  }
}
