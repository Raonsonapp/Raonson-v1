// lib/create/upload/post_upload_service.dart
// Загрузкаи фонӣ — баъди «Нашр» корбар фавран ба Home бармегардад,
// бор кардан дар фон давом мекунад ва progress дар боли Home нишон дода
// мешавад (мисли Instagram). Корбар метавонад дар ин ҳол видео бинад ва ғ.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/media_compressor.dart';
import 'upload_manager.dart';

/// Ratio-и аслии медиаро ҳисоб мекунад (расм ё видео) — то дар база нигоҳ
/// дошта шавад ва ҳангоми намоиш формат нигоҳ дошта шавад.
Future<double> mediaAspectRatio(File file, bool isVideo) async {
  try {
    if (isVideo) {
      final c = VideoPlayerController.file(file);
      await c.initialize().timeout(const Duration(seconds: 20));
      final r = c.value.aspectRatio;
      await c.dispose();
      return (r > 0) ? r : 0;
    } else {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final r = img.height > 0 ? img.width / img.height : 0.0;
      img.dispose();
      return r;
    }
  } catch (_) {
    return 0;
  }
}

class UploadState {
  final File   thumb;     // расм барои thumbnail-и progress
  final double progress;  // 0..1
  final bool   done;
  final bool   error;
  const UploadState(
      {required this.thumb, this.progress = 0, this.done = false, this.error = false});
}

class PostUploadService {
  PostUploadService._();
  static final PostUploadService instance = PostUploadService._();

  final ValueNotifier<UploadState?> state = ValueNotifier<UploadState?>(null);

  /// Феед-ро refresh мекунад баъди нашр (FeedController мегузорад).
  VoidCallback? onPublished;

  Future<void> publishPost({
    required File file,
    required bool isVideo,
    required String caption,
    String musicTitle = '',
    String musicArtist = '',
    String location = '',
    List<String> taggedUsers = const [],
    List<String> collaborators = const [],
    String scheduledAt = '', // ISO-8601 — агар холӣ набошад, ба нақша гирифта мешавад
  }) async {
    state.value = UploadState(thumb: file, progress: 0.08);
    try {
      // 0. Ratio-и аслиро аз файли аслӣ мегирем (пеш аз фишурдан).
      final ar = await mediaAspectRatio(file, isVideo);

      // 1. Compress (видеоро ~720p, расмро дар UploadManager)
      final media = isVideo
          ? await MediaCompressor.compressVideo(file)
          : file;
      state.value = UploadState(thumb: file, progress: 0.3);

      // 2. Upload медиа → URL
      final url = await UploadManager().uploadFile(media);
      if (url.isEmpty) throw Exception('upload failed');
      state.value = UploadState(thumb: file, progress: 0.85);

      // 3. POST /posts/
      final res = await ApiClient.instance.post('/posts/', body: {
        'caption': caption,
        'media': [
          {'url': url, 'type': isVideo ? 'video' : 'image',
           if (ar > 0) 'aspectRatio': ar}
        ],
        'musicTitle': musicTitle,
        'musicArtist': musicArtist,
        'location': location,
        'taggedUsers': taggedUsers,
        'collaborators': collaborators,
        if (scheduledAt.isNotEmpty) 'scheduledAt': scheduledAt,
      });
      if (res.statusCode >= 400) {
        throw Exception(_msg(res.body, res.statusCode));
      }

      state.value = UploadState(thumb: file, progress: 1.0, done: true);
      onPublished?.call();
      await Future.delayed(const Duration(seconds: 2));
      if (state.value?.done == true) state.value = null;
    } catch (_) {
      state.value = UploadState(thumb: file, error: true);
      await Future.delayed(const Duration(seconds: 4));
      if (state.value?.error == true) state.value = null;
    }
  }

  String _msg(String body, int code) {
    try {
      final j = jsonDecode(body);
      return (j['message'] ?? 'Хато $code').toString();
    } catch (_) { return 'Хато $code'; }
  }
}
