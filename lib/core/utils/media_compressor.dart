// lib/core/utils/media_compressor.dart
// Расм: 1.7MB → ~170KB  |  Видео: 45MB → ~15MB

import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:video_compress/video_compress.dart';

class MediaCompressor {
  // ── Расм compress ──────────────────────────────────────────────
  // 1.7MB → ~170KB  (quality: 70, maxWidth: 1080)
  static Future<File> compressImage(File file) async {
    final dir  = await getTemporaryDirectory();
    final ext  = p.extension(file.path).toLowerCase();
    final name = 'compressed_${DateTime.now().millisecondsSinceEpoch}$ext';
    final outPath = p.join(dir.path, name);

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality:  70,         // 70% сифат — чашм фарқ намекунад
      minWidth:  1080,
      minHeight: 1080,
      format: ext == '.png'
          ? CompressFormat.png
          : CompressFormat.jpeg,
    );

    if (result == null) return file; // fallback
    final compressed = File(result.path);

    // Агар compressed калонтар бошад, оригиналро бар гардон
    final origSize = await file.length();
    final compSize = await compressed.length();
    return compSize < origSize ? compressed : file;
  }

  // ── Видео compress ─────────────────────────────────────────────
  // 45MB → ~15MB  (medium quality, 720p)
  static Future<File> compressVideo(File file) async {
    final info = await VideoCompress.compressVideo(
      file.path,
      quality:         VideoQuality.MediumQuality, // 720p
      deleteOrigin:    false,
      includeAudio:    true,
      frameRate:       30,
    );

    if (info == null || info.file == null) return file;

    final origSize = await file.length();
    final compSize = await info.file!.length();
    return compSize < origSize ? info.file! : file;
  }

  // ── Видеои сифати ПАСТ (480p) — барои интернети суст (адаптивӣ) ──
  // Бармегардонад null агар компресс нашавад (вақте видеоУрли паст лозим нест).
  static Future<File?> compressVideoLow(File file) async {
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality:      VideoQuality.Res640x480Quality, // ~480p
        deleteOrigin: false,
        includeAudio: true,
        frameRate:    30,
      );
      return info?.file;
    } catch (_) { return null; }
  }

  // ── Автоматӣ — расм ё видео тафриқ мекунад ────────────────────
  static Future<File> compress(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    final isVideo = ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext);
    return isVideo ? compressVideo(file) : compressImage(file);
  }

  // ── Андозаро нишон диҳад (debug) ──────────────────────────────
  static Future<String> sizeLabel(File file) async {
    final bytes = await file.length();
    if (bytes < 1024)       return '${bytes}B';
    if (bytes < 1024*1024)  return '${(bytes/1024).toStringAsFixed(1)}KB';
    return '${(bytes/1024/1024).toStringAsFixed(1)}MB';
  }
}
