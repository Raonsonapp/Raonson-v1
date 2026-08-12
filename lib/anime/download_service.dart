// lib/anime/download_service.dart
// Зеркашии видеои аниме барои тамошои офлайн (бе интернет, бе лаг).
// MP4-ро мегирад (HLS/m3u8 барои офлайн мувофиқ нест).
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 10),
  ));

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/anime_downloads');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static String _safe(String s) {
    final t = s.replaceAll(RegExp(r'[^A-Za-z0-9А-Яа-я _-]'), '').trim();
    return t.isEmpty ? 'anime' : (t.length > 60 ? t.substring(0, 60) : t);
  }

  /// Файли видеоро зеркашӣ мекунад. Танҳо MP4 пуштибонӣ мешавад.
  /// Бармегардонад: масири файл.
  static Future<String> download(
    String url,
    String title, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await _dir();
    final path = '${dir.path}/${_safe(title)}.mp4';
    await _dio.download(
      url,
      path,
      cancelToken: cancelToken,
      onReceiveProgress: (recv, total) {
        if (total > 0 && onProgress != null) onProgress(recv / total);
      },
    );
    return path;
  }

  /// Рӯйхати файлҳои зеркашшуда.
  static Future<List<File>> list() async {
    final dir = await _dir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.mp4'))
        .toList();
    files.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  static Future<void> delete(File f) async {
    if (await f.exists()) await f.delete();
  }

  /// Номи зебо аз масири файл.
  static String titleOf(File f) {
    final name = f.path.split('/').last;
    return name.replaceAll('.mp4', '');
  }
}
