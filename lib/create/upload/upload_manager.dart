// lib/create/upload/upload_manager.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../app/app_config.dart';
import '../../core/storage/token_storage.dart';

class UploadManager {

  String _ext(File f) => f.path.split('.').last.toLowerCase();

  bool _isVideo(File f) =>
      ['mp4','mov','avi','mkv','webm','3gp'].contains(_ext(f));

  MediaType _mime(File f) {
    final e = _ext(f);
    if (['mp4','mov','avi','mkv','webm'].contains(e)) return MediaType('video','mp4');
    if (e == 'png') return MediaType('image','png');
    return MediaType('image','jpeg');
  }

  // Upload file directly — NO compression (compression was crashing)
  Future<String> _uploadFile(File file) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен нест — дубора ворид шавед');
    }

    final base = AppConfig.apiBaseUrl;
    final uri  = Uri.parse('$base/upload');

    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath(
        'file', file.path, contentType: _mime(file)));

    final streamed = await req.send()
        .timeout(const Duration(minutes: 3));

    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode >= 400) {
      throw Exception('Upload хато ${streamed.statusCode}: $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final url  = (json['url'] ?? json['secure_url'] ?? '').toString();
    if (url.isEmpty) throw Exception('Server URL нафиристод');
    return url;
  }

  Future<String> uploadAvatar(File f) => _uploadFile(f);
  Future<String> uploadFile(File f)   => _uploadFile(f);

  // ── POST /posts ────────────────────────────────────────────────
  Future<void> uploadPost({
    required List<File> media,
    required String caption,
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен нест — дубора ворид шавед');
    }

    final base = AppConfig.apiBaseUrl;

    // Step 1: upload each file
    final list = <Map<String, String>>[];
    for (int i = 0; i < media.length; i++) {
      final url = await _uploadFile(media[i]);
      list.add({'url': url, 'type': _isVideo(media[i]) ? 'video' : 'image'});
      onProgress?.call((i + 1) / media.length * 0.8);
    }

    // Step 2: create post
    final res = await http.post(
      Uri.parse('$base/posts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type' : 'application/json',
      },
      body: jsonEncode({'caption': caption, 'media': list}),
    ).timeout(const Duration(seconds: 30));

    onProgress?.call(1.0);

    if (res.statusCode >= 400) {
      Map err = {};
      try { err = jsonDecode(res.body); } catch (_) {}
      throw Exception(
        'Post сохта нашуд (${res.statusCode}): '
        '${err['message'] ?? res.body}',
      );
    }
  }

  // ── POST /stories ──────────────────────────────────────────────
  Future<void> uploadStory({
    required File file,
    String caption = '',
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен нест — дубора ворид шавед');
    }

    final base = AppConfig.apiBaseUrl;

    // Step 1: upload
    final url = await _uploadFile(file);
    onProgress?.call(0.7);

    // Step 2: create story
    final res = await http.post(
      Uri.parse('$base/stories'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type' : 'application/json',
      },
      body: jsonEncode({
        'mediaUrl' : url,
        'mediaType': _isVideo(file) ? 'video' : 'image',
        'caption'  : caption,
      }),
    ).timeout(const Duration(seconds: 30));

    onProgress?.call(1.0);

    if (res.statusCode >= 400) {
      Map err = {};
      try { err = jsonDecode(res.body); } catch (_) {}
      throw Exception(
        'Story сохта нашуд (${res.statusCode}): '
        '${err['message'] ?? res.body}',
      );
    }
  }
}
