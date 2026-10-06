// lib/create/upload/post_upload_service.dart
// Загрузкаи фонӣ — баъди «Нашр» корбар фавран ба Home бармегардад,
// бор кардан дар фон давом мекунад ва progress дар боли Home нишон дода
// мешавад (мисли Instagram). Корбар метавонад дар ин ҳол видео бинад ва ғ.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../auto_dm_sheet.dart';

import '../../core/music/song_info.dart';
import '../../core/api/api_client.dart';
import '../../core/notifications/upload_notifier.dart';
import '../../core/utils/media_compressor.dart';
import 'upload_manager.dart';
import '../../core/moderation/content_policy.dart';

/// Ratio-и аслии медиаро ҳисоб мекунад (расм ё видео) — то дар база нигоҳ
/// дошта шавад ва ҳангоми намоиш формат нигоҳ дошта шавад.
Future<double> mediaAspectRatio(File file, bool isVideo) async {
  if (isVideo) {
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.file(file);
      await c.initialize().timeout(const Duration(seconds: 20));
      final r = c.value.aspectRatio;
      return (r > 0) ? r : 0;
    } catch (_) {
      return 0;
    } finally {
      // Дар ҲАР роҳ (аз он ҷумла timeout) player-и native озод мешавад,
      // вагарна ExoPlayer-ҳо ҷамъ шуда видеопахшро мешикананд.
      c?.dispose();
    }
  }
  try {
    // Танҳо ҳедери расм хонда мешавад — бе decode-и пурраи пикселҳо.
    final buf = await ui.ImmutableBuffer.fromFilePath(file.path);
    final desc = await ui.ImageDescriptor.encoded(buf);
    final r = desc.height > 0 ? desc.width / desc.height : 0.0;
    desc.dispose();
    buf.dispose();
    return r;
  } catch (_) {
    return 0;
  }
}

class UploadState {
  final File   thumb;     // расм барои thumbnail-и progress
  final double progress;  // 0..1
  final bool   done;
  final bool   error;
  /// Сабаби хато барои корбар (масалан «Ин мӯҳтаво қоидаҳои
  /// Raonson-ро вайрон мекунад»). null — хатои умумӣ.
  final String? message;
  /// Сервер мӯҳтаворо рад кард (на хатои шабака).
  final bool   rejected;
  /// Пост қабул шуд, вале то санҷиши модератор пинҳон аст.
  final bool   pendingReview;
  const UploadState(
      {required this.thumb, this.progress = 0, this.done = false, this.error = false,
       this.message, this.rejected = false, this.pendingReview = false});
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
    /// Суруди интихобкардаи муаллиф. Пеш танҳо ном ва хонанда
    /// фиристода мешуданд — бе суроға ва ҷои оғоз пост ҳеҷ гоҳ
    /// хонда намешуд.
    SongInfo? song,
    String location = '',
    List<String> taggedUsers = const [],
    List<String> collaborators = const [],
    String scheduledAt = '', // ISO-8601 — агар холӣ набошад, ба нақша гирифта мешавад
    String altText = '',     // тавсифи расм барои нобиноён
    AutoDmDraft? autoDm,     // паёми худкор ба Direct аз рӯи калимаи шарҳ
  }) async {
    // Огоҳиномаи системавӣ («Пост бор мешавад… 45%») ҳамон рақамеро
    // нишон медиҳад, ки навори дохили барнома.
    final notifier = UploadNotifier.instance;
    final nid = notifier.start(UploadKind.post);
    // Пешрафт танҳо ба пеш; навори дохилӣ ҳар 1% навсозӣ мешавад.
    int shownPct = -1;
    final report = MonotonicProgress((p) {
      notifier.progress(nid, p);
      final pct = toPercent(p);
      if (pct != shownPct) {
        shownPct = pct;
        state.value = UploadState(thumb: file, progress: p);
      }
    });
    report(0.08);
    try {
      // 0. Ratio-и аслиро аз файли аслӣ мегирем (пеш аз фишурдан).
      final ar = await mediaAspectRatio(file, isVideo);

      // 1. Compress (видеоро ~720p, расмро дар UploadManager)
      final media = isVideo
          ? await MediaCompressor.compressVideo(file,
              onProgress: (f) => report(phase(0.08, 0.3, f)))
          : file;
      report(0.3);

      // 2. Upload медиа → URL (пешрафт аз рӯи байтҳо)
      final url = await UploadManager().uploadFile(media,
          onProgress: (f) => report(phase(0.3, 0.85, f)));
      if (url.isEmpty) throw Exception('upload failed');
      report(0.85);

      // 3. POST /posts/
      final res = await ApiClient.instance.post('/posts/', body: {
        'caption': caption,
        'media': [
          {'url': url, 'type': isVideo ? 'video' : 'image',
           if (ar > 0) 'aspectRatio': ar,
           if (altText.isNotEmpty) 'alt': altText}
        ],
        // Майдонҳои кӯҳна барои мутобиқати сервери насбшуда.
        'musicTitle': song?.title ?? '',
        'musicArtist': song?.artist ?? '',
        if (song != null && song.isNotEmpty) 'song': song.toJson(),
        'location': location,
        'taggedUsers': taggedUsers,
        'collaborators': collaborators,
        if (scheduledAt.isNotEmpty) 'scheduledAt': scheduledAt,
        if (autoDm != null) 'autoDm': autoDm.toJson(),
      });
      if (res.statusCode >= 400) {
        final rejection = ContentPolicy.fromResponse(res.statusCode, res.body);
        if (rejection != null) throw rejection;
        throw Exception(_msg(res.body, res.statusCode));
      }
      var pending = false;
      try {
        pending = (jsonDecode(res.body) as Map)['pendingReview'] == true;
      } catch (_) {}

      state.value = UploadState(thumb: file, progress: 1.0, done: true,
          pendingReview: pending,
          message: pending ? 'Пост то санҷиши модератор пинҳон аст' : null);
      notifier.done(nid);
      onPublished?.call();
      await Future.delayed(const Duration(seconds: 2));
      if (state.value?.done == true) state.value = null;
    } catch (e) {
      notifier.failed(nid);
      final rejection = ContentPolicy.fromError(e);
      state.value = UploadState(thumb: file, error: true,
          rejected: rejection != null,
          message: rejection?.message);
      // Сабаби радро корбар бояд хонда тавонад — дарозтар мемонад.
      await Future.delayed(Duration(seconds: rejection != null ? 8 : 4));
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
