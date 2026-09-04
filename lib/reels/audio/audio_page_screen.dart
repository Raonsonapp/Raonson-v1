// lib/reels/audio/audio_page_screen.dart
// ════════════════════════════════════════════════════════════════════
//  Саҳифаи садо — «Ин садоро истифода бар».
//
//  Аз audio bar-и рилс кушода мешавад: маълумоти суруд, ҳамаи рилсҳое,
//  ки бо ҳамин садо сохта шудаанд, ва тугмаи сохтани рилси нав.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/ui/app_icons.dart';
import '../../create/create_reel/create_reel_screen.dart';

/// Садо ҳамчун объект — ҳамон чизе, ки сервер бармегардонад.
class ReelAudio {
  final String id, title, artist, coverUrl, previewUrl;
  final int reelsCount;
  final bool saved;

  const ReelAudio({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.previewUrl,
    required this.reelsCount,
    required this.saved,
  });

  factory ReelAudio.fromJson(Map<String, dynamic> j) => ReelAudio(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        artist: (j['artist'] ?? '').toString(),
        coverUrl: (j['coverUrl'] ?? '').toString(),
        previewUrl: (j['previewUrl'] ?? '').toString(),
        reelsCount: (j['reelsCount'] as num?)?.toInt() ?? 0,
        saved: j['saved'] == true,
      );
}

class AudioPageScreen extends StatefulWidget {
  final String audioId;
  /// Ном ва ҳунарманд аз рилс меоянд — то сарлавҳа фавран нишон дода
  /// шавад ва экран холӣ нанамояд, то дархост биояд.
  final String? initialTitle;
  final String? initialArtist;

  const AudioPageScreen({
    super.key,
    required this.audioId,
    this.initialTitle,
    this.initialArtist,
  });

  @override
  State<AudioPageScreen> createState() => _AudioPageScreenState();
}

class _AudioPageScreenState extends State<AudioPageScreen> {
  ReelAudio? _audio;
  List<Map<String, dynamic>> _reels = const [];
  String? _error;
  bool _savingAudio = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res =
          await ApiClient.instance.get('/reels/audio/${widget.audioId}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) {
        throw Exception(body['message'] ?? tr('audio.notFound'));
      }
      if (!mounted) return;
      setState(() {
        _audio = ReelAudio.fromJson(body);
        _reels = ((body['reels'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _toggleSave() async {
    if (_audio == null || _savingAudio) return;
    setState(() => _savingAudio = true);
    try {
      final res = await ApiClient.instance
          .post('/reels/audio/${widget.audioId}/save');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) throw Exception(body['message']);
      if (!mounted) return;
      // Ҳолати нав аз ҷавоби СЕРВЕР гирифта мешавад, на дар client
      // тахмин карда мешавад — вагарна дар хатои шабака нишона дурӯғ
      // мемонад.
      final saved = body['saved'] == true;
      setState(() {
        _audio = ReelAudio(
          id: _audio!.id,
          title: _audio!.title,
          artist: _audio!.artist,
          coverUrl: _audio!.coverUrl,
          previewUrl: _audio!.previewUrl,
          reelsCount: _audio!.reelsCount,
          saved: saved,
        );
        _savingAudio = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingAudio = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('common.errorTryAgain'))),
      );
    }
  }

  void _useAudio() {
    if (_audio == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateReelScreen(
          presetAudioId: _audio!.id,
          presetAudioTitle: _audio!.title,
          presetAudioArtist: _audio!.artist,
          presetAudioCover: _audio!.coverUrl,
          presetAudioPreview: _audio!.previewUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _audio?.title ?? widget.initialTitle ?? '';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('audio.title'),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ),
      body: _error != null
          ? _errorView()
          : Column(children: [
              _header(title),
              const Divider(height: 1),
              Expanded(child: _grid()),
            ]),
      bottomNavigationBar: _audio == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _useAudio,
                    icon: Icon(AppIcons.camera_alt_rounded,
                        size: 18, color: AppColors.white),
                    label: Text(tr('audio.useThis'),
                        style: TextStyle(
                            color: AppColors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.error_outline, size: 40, color: AppColors.red),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: Text(tr('common.retry'))),
          ]),
        ),
      );

  Widget _header(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: (_audio?.coverUrl ?? '').isEmpty
                ? Container(
                    width: 74,
                    height: 74,
                    color: AppColors.card,
                    child: Icon(AppIcons.music_note,
                        color: AppColors.textFaint, size: 28),
                  )
                : CachedNetworkImage(
                    imageUrl: _audio!.coverUrl,
                    width: 74,
                    height: 74,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 74,
                      height: 74,
                      color: AppColors.card,
                      child: Icon(AppIcons.music_note,
                          color: AppColors.textFaint, size: 28),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.isEmpty ? '—' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(_audio?.artist ?? widget.initialArtist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textTertiary, fontSize: 13.5)),
                if (_audio != null) ...[
                  const SizedBox(height: 5),
                  Text(trn('audio.reelsCount', _audio!.reelsCount),
                      style:
                          TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          if (_audio != null)
            IconButton(
              onPressed: _savingAudio ? null : _toggleSave,
              icon: Icon(
                _audio!.saved
                    ? AppIcons.bookmark
                    : AppIcons.bookmark_border_rounded,
                color: _audio!.saved
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
        ]),
      );

  Widget _grid() {
    if (_audio == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reels.isEmpty) {
      return Center(
        child: Text(tr('audio.noReels'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13.5)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 0.62,
        ),
        itemCount: _reels.length,
        itemBuilder: (_, i) {
          final r = _reels[i];
          final thumb = (r['thumbnailUrl'] ?? '').toString();
          final views = (r['viewsCount'] as num?)?.toInt() ?? 0;
          return Stack(fit: StackFit.expand, children: [
            if (thumb.isEmpty)
              Container(color: AppColors.card)
            else
              CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: AppColors.card),
              ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Row(children: [
                Icon(AppIcons.play_arrow_rounded,
                    size: 14, color: Colors.white),
                const SizedBox(width: 3),
                Text(_compact(views),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }
}
