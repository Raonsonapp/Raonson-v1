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
      ['mp4','mov','avi','mkv','webm','3gp'].contains(_ext(f));

  MediaType _contentType(File f) {
    final ext = _ext(f);
    if (['mp4','mov','avi','mkv','webm'].contains(ext)) return MediaType('video','mp4');
    if (ext == 'png') return MediaType('image','png');
    return MediaType('image','jpeg');
  }

  // ─── Internal: compress + upload to R2 via backend ─────────────
  Future<String> _upload(File file) async {
    // Compress
    File toUpload = file;
    try {
      toUpload = await MediaCompressor.compress(file);
    } catch (e) {
      print('[Upload] compress failed, using original: $e');
    }

    final before = await MediaCompressor.sizeLabel(file);
    final after  = await MediaCompressor.sizeLabel(toUpload);
    print('[Upload] size: $before → $after');

    // Get token
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен нест — дубора ворид шавед');
    }

    // Upload file
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/upload');
    print('[Upload] → $uri');

    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath(
        'file', toUpload.path,
        contentType: _contentType(toUpload),
      ));

    final streamed = await req.send().timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw Exception('Upload timeout'),
    );

    final bodyStr = await streamed.stream.bytesToString();
    print('[Upload] response ${streamed.statusCode}: $bodyStr');

    if (streamed.statusCode >= 400) {
      throw Exception('Upload хато ${streamed.statusCode}: $bodyStr');
    }

    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final url  = (body['url'] ?? body['secure_url'])?.toString() ?? '';
    if (url.isEmpty) throw Exception('URL нест: $bodyStr');

    print('[Upload] ✅ url=$url');
    return url;
  }

  // ─── Public ────────────────────────────────────────────────────
  Future<String> uploadAvatar(File file) => _upload(file);
  Future<String> uploadFile(File file)   => _upload(file);

  // POST /posts
  Future<void> uploadPost({
    required List<File> media,
    required String caption,
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Токен нест — дубора ворид шавед');
    }

    // 1. Upload all media files
    final mediaList = <Map<String, String>>[];
    for (int i = 0; i < media.length; i++) {
      print('[Upload] uploading media ${i+1}/${media.length}');
      final url = await _upload(media[i]);
      mediaList.add({
        'url':  url,
        'type': _isVideo(media[i]) ? 'video' : 'image',
      });
      onProgress?.call((i + 1) / media.length * 0.85);
    }

    // 2. Create post
    print('[Upload] creating post, media=${mediaList.length}, caption=$caption');
    final postUri = Uri.parse('${AppConfig.apiBaseUrl}/posts');
    print('[Upload] POST → $postUri');

    final res = await http.post(
      postUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({'caption': caption, 'media': mediaList}),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Post timeout'),
    );

    onProgress?.call(1.0);
    print('[Upload] POST /posts → ${res.statusCode}: ${res.body}');

    if (res.statusCode >= 400) {
      Map body = {};
      try { body = jsonDecode(res.body); } catch (_) {}
      throw Exception('Post сохта нашуд ${res.statusCode}: ${body['message'] ?? res.body}');
    }

    print('[Upload] ✅ Post created!');
  }

  // POST /stories
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

    print('[Upload] creating story url=$url');
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
    ).timeout(const Duration(seconds: 30));

    onProgress?.call(1.0);
    print('[Upload] POST /stories → ${res.statusCode}: ${res.body}');

    if (res.statusCode >= 400) {
      Map body = {};
      try { body = jsonDecode(res.body); } catch (_) {}
      throw Exception('Story сохта нашуд: ${body['message'] ?? res.body}');
    }

    print('[Upload] ✅ Story created!');
  }
}
