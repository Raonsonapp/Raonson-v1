import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/media_compressor.dart';
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

  // ── Видеоро пеш аз бор кардан фишурда мекунад — ба сифати миёна ~720p.
  // (45MB → ~15MB) — дар интернети суст 3-5 бор тезтар.
  // Агар call-site аллакай фишурда бошад (файл дар tempDir мебошад ё
  // хурд аст) — дубора фишурда намекунем.
  Future<File> _maybeCompressVideo(File file) async {
    if (!_isVideo(file)) return file;
    try {
      final size = await file.length();
      // Файли то 8MB — арзиши фишурдан надорад (шояд аллакай фишурда).
      if (size < 8 * 1024 * 1024) return file;
      // Файле, ки дар tempDir аст, эҳтимол аллакай compress шудааст.
      final tmp = await getTemporaryDirectory();
      if (file.path.startsWith(tmp.path)) return file;
      return await MediaCompressor.compressVideo(file);
    } catch (_) {}
    return file;
  }

  // ── Upload file to R2 ─────────────────────────────────────────
  // Retry: 3 маротиба (2с/4с фосила) — интернети суст талаб мекунад.
  Future<String> _uploadFile(File rawFile) async {
    final token = _token;
    if (token.isEmpty) throw Exception('Токен нест');

    // 1. Пеш аз upload — файлро фишурда мекунем (расм ва видео)
    File file = await _maybeCompressImage(rawFile);
    file = await _maybeCompressVideo(file);

    Object? lastErr;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final req = http.MultipartRequest(
            'POST', Uri.parse('${AppConfig.apiBaseUrl}/upload'))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(await http.MultipartFile.fromPath(
              'file', file.path, contentType: _mime(file)));

        // Timeout — то 5 дақиқа, барои файлҳои калон дар интернети суст.
        final up  = await req.send().timeout(const Duration(minutes: 5));
        final str = await up.stream.bytesToString();

        if (up.statusCode >= 500) {
          // Хатои сервер — арзиши retry дорад.
          throw Exception('Upload ${up.statusCode}: $str');
        }
        if (up.statusCode >= 400) {
          // Хатои клиент (auth, bad request) — retry намекунем.
          throw Exception('Upload ${up.statusCode}: $str');
        }

        final j   = jsonDecode(str) as Map<String, dynamic>;
        final url = (j['url'] ?? j['secure_url'] ?? '').toString().trim();
        if (url.isEmpty) throw Exception('URL нест: $str');
        return url;
      } on SocketException catch (e) {
        lastErr = e;
      } on TimeoutException catch (e) {
        lastErr = e;
      } on HttpException catch (e) {
        lastErr = e;
      } catch (e) {
        // 4xx-и клиент — retry намекунем, фавран мепартоем.
        final msg = e.toString();
        if (msg.contains('40') && !msg.contains('408')) rethrow;
        lastErr = e;
      }
      if (attempt < 2) {
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    throw Exception(lastErr?.toString() ?? 'Upload ноком шуд');
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
