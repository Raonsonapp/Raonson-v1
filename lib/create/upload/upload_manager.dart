// lib/create/upload/upload_manager.dart
// Direct upload to Go backend → Cloudflare R2
// Cloudinary removed — no preset/config needed

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../app/app_config.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/media_compressor.dart';

class UploadManager {
  String _ext(File f) => f.path.split('.').last.toLowerCase();

  bool _isVideo(File f) =>
      ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(_ext(f));

  MediaType _contentType(File f) {
    final ext = _ext(f);
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) return MediaType('video', 'mp4');
    if (ext == 'png') return MediaType('image', 'png');
    return MediaType('image', 'jpeg');
  }

  // ── Compress + upload to backend (R2) ──────────────────────────
  Future<String> _upload(File file) async {
    // 1. Compress
    File toUpload;
    try {
      toUpload = await MediaCompressor.compress(file);
    } catch (_) {
      toUpload = file; // fallback: no compress
    }

    final before = await MediaCompressor.sizeLabel(file);
    final after  = await MediaCompressor.sizeLabel(toUpload);
    print('[Upload] $before → $after');

    return await _uploadToBackend(toUpload);
  }

  Future<String> _uploadToBackend(File file) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен нест — дубора ворид шавед');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/upload');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: _contentType(file),
      ));

    print('[Upload] Sending to: $uri');

    final streamed = await req.send().timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw Exception('Upload timeout — интернет суст аст'),
    );

    final bodyStr = await streamed.stream.bytesToString();
    print('[Upload] Response ${streamed.statusCode}: $bodyStr');

    if (streamed.statusCode >= 400) {
      Map body = {};
      try { body = jsonDecode(bodyStr); } catch (_) {}
      throw Exception('Upload хато ${streamed.statusCode}: ${body['error'] ?? bodyStr}');
    }

    final body = jsonDecode(bodyStr);
    final url = (body['url'] ?? body['secure_url'])?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('Server URL нафиристод: $bodyStr');
    }

    print('[Upload] ✅ URL: $url');
    return url;
  }

  // ── Public API ──────────────────────────────────────────────────

  Future<String> uploadAvatar(File file) => _upload(file);

  Future<String> uploadFile(File file) => _upload(file);

  Future<void> uploadPost({
    required List<File> media,
    required String caption,
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен нест — дубора ворид шавед');
    }

    final mediaList = <Map<String, String>>[];

    for (int i = 0; i < media.length; i++) {
      final url = await _upload(media[i]);
      mediaList.add({
        'url':  url,
        'type': _isVideo(media[i]) ? 'video' : 'image',
      });
      onProgress?.call((i + 1) / media.length * 0.85);
    }

    print('[Upload] Creating post with ${mediaList.length} media...');

    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/posts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({'caption': caption, 'media': mediaList}),
    ).timeout(const Duration(seconds: 60));

    onProgress?.call(1.0);

    if (res.statusCode >= 400) {
      Map body = {};
      try { body = jsonDecode(res.body); } catch (_) {}
      throw Exception('Post сохта нашуд: ${body['message'] ?? res.body}');
    }

    print('[Upload] ✅ Post created');
  }

  Future<void> uploadStory({
    required File file,
    String caption = '',
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен нест — дубора ворид шавед');
    }

    final url = await _upload(file);
    onProgress?.call(0.8);

    print('[Upload] Creating story...');

    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/stories'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({
        'mediaUrl':  url,
        'mediaType': _isVideo(file) ? 'video' : 'image',
        'caption':   caption,
      }),
    ).timeout(const Duration(seconds: 60));

    onProgress?.call(1.0);

    if (res.statusCode >= 400) {
      Map body = {};
      try { body = jsonDecode(res.body); } catch (_) {}
      throw Exception('Story сохта нашуд: ${body['message'] ?? res.body}');
    }

    print('[Upload] ✅ Story created');
  }
}
