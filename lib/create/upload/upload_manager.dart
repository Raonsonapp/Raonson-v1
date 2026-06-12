import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/api/api_client.dart';
import '../../app/app_config.dart';

// ─────────────────────────────────────────────────────────────────
// МУҲИМ: Gin backend routes:
//   po.POST("/")  → /posts/   (бо slash)
//   st.POST("/")  → /stories/ (бо slash)
//   re.POST("/")  → /reels/   (бо slash)
// Бе slash → 301 redirect → http package POST-ро GET мекунад → 404
// ─────────────────────────────────────────────────────────────────
class UploadManager {
  String _ext(File f) => f.path.split('.').last.toLowerCase();

  bool _isVideo(File f) =>
      ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(_ext(f));

  MediaType _mime(File f) {
    final e = _ext(f);
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(e)) {
      return MediaType('video', 'mp4');
    }
    // Паёмҳои овозӣ
    if (e == 'm4a' || e == 'aac' || e == 'mp4a') return MediaType('audio', 'mp4');
    if (e == 'mp3')  return MediaType('audio', 'mpeg');
    if (e == 'ogg' || e == 'opus') return MediaType('audio', 'ogg');
    if (e == 'wav')  return MediaType('audio', 'wav');
    if (e == 'png')  return MediaType('image', 'png');
    return MediaType('image', 'jpeg');
  }

  String get _token => ApiClient.instance.authToken ?? '';

  bool _isImage(File f) =>
      ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'].contains(_ext(f));

  // Расмро пеш аз бор кардан фишурда мекунад (ҳаҷм + трафик кам).
  // Видео/аудио дар create-flow алоҳида фишурда мешавад.
  Future<File> _maybeCompressImage(File file) async {
    if (!_isImage(file)) return file;
    try {
      final dir = await getTemporaryDirectory();
      final out =
          '${dir.path}/cmp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path, out,
        quality: 72, minWidth: 1080, minHeight: 1080,
        format: CompressFormat.jpeg,
      );
      if (result != null) return File(result.path);
    } catch (_) {}
    return file;
  }

  // ── Upload file to R2 ─────────────────────────────────────────
  Future<String> _uploadFile(File rawFile) async {
    final token = _token;
    if (token.isEmpty) throw Exception('Токен нест');

    final file = await _maybeCompressImage(rawFile);
    final req = http.MultipartRequest(
        'POST', Uri.parse('${AppConfig.apiBaseUrl}/upload'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath(
          'file', file.path, contentType: _mime(file)));

    final up  = await req.send().timeout(const Duration(minutes: 3));
    final str = await up.stream.bytesToString();

    if (up.statusCode >= 400) {
      throw Exception('Upload ${up.statusCode}: $str');
    }

    final j   = jsonDecode(str) as Map<String, dynamic>;
    final url = (j['url'] ?? j['secure_url'] ?? '').toString().trim();
    if (url.isEmpty) throw Exception('URL нест: $str');
    return url;
  }

  Future<String> uploadAvatar(File f) => _uploadFile(f);
  Future<String> uploadFile(File f)   => _uploadFile(f);

  // ── Upload post ───────────────────────────────────────────────
  Future<void> uploadPost({
    required List<File> media,
    required String caption,
    void Function(double)? onProgress,
  }) async {
    final token = _token;
    if (token.isEmpty) throw Exception('Токен нест');

    final list = <Map<String, String>>[];
    for (int i = 0; i < media.length; i++) {
      final url = await _uploadFile(media[i]);
      list.add({'url': url, 'type': _isVideo(media[i]) ? 'video' : 'image'});
      onProgress?.call((i + 1) / media.length * 0.8);
    }

    // /posts/ — БО slash (Gin route: po.POST("/"))
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/posts/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type' : 'application/json',
      },
      body: jsonEncode({'caption': caption, 'media': list}),
    ).timeout(const Duration(seconds: 30));

    onProgress?.call(1.0);

    if (res.statusCode >= 400) {
      Map<String, dynamic> err = {};
      try { err = jsonDecode(res.body) as Map<String, dynamic>; } catch (_) {}
      throw Exception('Post ${res.statusCode}: ${err['message'] ?? res.body}');
    }
  }

  // ── Upload story ──────────────────────────────────────────────
  Future<void> uploadStory({
    required File file,
    String caption = '',
    void Function(double)? onProgress,
  }) async {
    final token = _token;
    if (token.isEmpty) throw Exception('Токен нест');

    final url = await _uploadFile(file);
    onProgress?.call(0.7);

    // /stories/ — БО slash (Gin route: st.POST("/"))
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/stories/'),
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
      Map<String, dynamic> err = {};
      try { err = jsonDecode(res.body) as Map<String, dynamic>; } catch (_) {}
      throw Exception('Story ${res.statusCode}: ${err['message'] ?? res.body}');
    }
  }
}
