// lib/create/upload/upload_manager.dart
// Compress + Upload → Cloudinary (primary) ё R2 (fallback)

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../app/app_config.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/media_compressor.dart';

class UploadManager {
  static const _cloudName    = 'dtp3kzqxi';
  static const _uploadPreset = 'raonson_preset';

  String _ext(File f) => f.path.split('.').last.toLowerCase();

  bool _isVideo(File f) =>
      ['mp4','mov','avi','mkv','webm','3gp'].contains(_ext(f));

  MediaType _contentType(File f) {
    final ext = _ext(f);
    if (['mp4','mov','avi','mkv','webm'].contains(ext)) return MediaType('video','mp4');
    if (ext == 'png') return MediaType('image','png');
    return MediaType('image','jpeg');
  }

  Future<String> _upload(File file) async {
    final compressed = await MediaCompressor.compress(file);
    final before = await MediaCompressor.sizeLabel(file);
    final after  = await MediaCompressor.sizeLabel(compressed);
    print('Compress: $before → $after');

    try {
      return await _uploadToCloudinary(compressed);
    } catch (e) {
      print('Cloudinary failed: $e — trying R2...');
      return await _uploadToBackend(compressed);
    }
  }

  Future<String> _uploadToCloudinary(File file) async {
    final type = _isVideo(file) ? 'video' : 'image';
    final uri  = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/$type/upload');
    final req  = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder']        = 'raonson';
    req.files.add(await http.MultipartFile.fromPath(
      'file', file.path, contentType: _contentType(file)));
    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final body     = jsonDecode(await streamed.stream.bytesToString());
    if (streamed.statusCode >= 400) throw Exception('Cloudinary error');
    final url = body['secure_url'] as String?;
    if (url == null || url.isEmpty) throw Exception('No URL');
    return url;
  }

  Future<String> _uploadToBackend(File file) async {
    final token = await TokenStorage.getAccessToken();
    final req   = http.MultipartRequest(
        'POST', Uri.parse('${AppConfig.apiBaseUrl}/upload'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath(
        'file', file.path, contentType: _contentType(file)));
    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final body     = jsonDecode(await streamed.stream.bytesToString());
    if (streamed.statusCode >= 400) throw Exception('Upload failed');
    final url = body['url'] as String?;
    if (url == null || url.isEmpty) throw Exception('No URL');
    return url;
  }

  Future<String> uploadAvatar(File file) => _upload(file);

  // Upload any file (image or video) - public method for reels
  Future<String> uploadFile(File file) => _upload(file);

  Future<void> uploadPost({
    required List<File> media,
    required String caption,
    void Function(double)? onProgress,
  }) async {
    final token     = await TokenStorage.getAccessToken();
    final mediaList = <Map<String,String>>[];
    for (int i = 0; i < media.length; i++) {
      final url = await _upload(media[i]);
      mediaList.add({'url': url, 'type': _isVideo(media[i]) ? 'video' : 'image'});
      onProgress?.call((i+1) / media.length * 0.85);
    }
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/posts'),
      headers: {'Authorization':'Bearer $token','Content-Type':'application/json'},
      body: jsonEncode({'caption': caption, 'media': mediaList}),
    ).timeout(const Duration(seconds: 60));
    onProgress?.call(1.0);
    if (res.statusCode >= 400) {
      throw Exception(jsonDecode(res.body)['message'] ?? 'Post failed');
    }
  }

  Future<void> uploadStory({
    required File file,
    String caption = '',
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final url   = await _upload(file);
    onProgress?.call(0.8);
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/stories'),
      headers: {'Authorization':'Bearer $token','Content-Type':'application/json'},
      body: jsonEncode({'mediaUrl':url,'mediaType':_isVideo(file)?'video':'image','caption':caption}),
    ).timeout(const Duration(seconds: 60));
    onProgress?.call(1.0);
    if (res.statusCode >= 400) throw Exception('Story failed');
  }
}
