import 'dart:io';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

class StoryApi {
  static Future<Map<String, dynamic>> fetchStories() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/stories'),
    );
    return Map<String, dynamic>.from(
      res.statusCode == 200 ? jsonDecode(res.body) : {},
    );
  }

  static Future<void> uploadStory({
    required String user,
    required File file,
    required String mediaType,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${Constants.baseUrl}/stories'),
    );

    req.fields['user'] = user;
    req.fields['mediaType'] = mediaType;
    req.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
    ));

    final res = await req.send();
    if (res.statusCode != 200) {
      throw Exception('Story upload failed');
    }
  }

  static Future<void> viewStory(String id, String user) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/stories/$id/view'),
      headers: {'Content-Type': 'application/json'},
      body: '{"user":"$user"}',
    );
  }
}
