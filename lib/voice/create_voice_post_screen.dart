// lib/voice/create_voice_post_screen.dart
//
// «Овоз» — сабти пости овозӣ то 60 сония: мавҷи зинда, гӯш кардан пеш аз
// нашр, тавсиф ва муқоваи ихтиёрӣ. Файл аз ҳамон /upload мегузарад; пост
// — ҳамон POST /posts бо медиаи `audio` (backend/handlers/voice_post.go).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../create/upload/upload_manager.dart';
import 'voice_post_player.dart';

/// Ҳадди пости овозӣ.
const voiceMaxDuration = Duration(seconds: 60);

/// dBFS (−60..0) → 0..100 — барои мавҷ.
int amplitudeToLevel(double dbfs) {
  if (dbfs.isNaN || dbfs.isInfinite) return 0;
  final v = ((dbfs + 60) / 60).clamp(0.0, 1.0);
  return (v * 100).round();
}

/// Нуқтаҳои мавҷро то [n] кам мекунад (ҳадди ҳар гурӯҳ).
List<int> downsampleLevels(List<int> levels, {int n = 64}) {
  if (levels.length <= n) return List.of(levels);
  return List.generate(n, (i) {
    final from = i * levels.length ~/ n;
    final to = (i + 1) * levels.length ~/ n;
    var m = 0;
    for (final v in levels.sublist(from, to)) {
      if (v > m) m = v;
    }
    return m;
  });
}

/// Бадани POST /posts барои пости овозӣ.
Map<String, dynamic> voicePostBody({
  required String audioUrl,
  required Duration duration,
  required List<int> levels,
  String caption = '',
  String coverUrl = '',
}) =>
    {
      'caption': caption.trim(),
      'media': [
        {
          'url': audioUrl,
          'type': 'audio',
          'durationMs': duration.inMilliseconds.clamp(0, voiceMaxDuration.inMilliseconds),
          'waveform': downsampleLevels(levels),
          if (coverUrl.isNotEmpty) 'cover': coverUrl,
        }
      ],
    };

class CreateVoicePostScreen extends StatefulWidget {
  const CreateVoicePostScreen({super.key});
  @override
  State<CreateVoicePostScreen> createState() => _CreateVoicePostScreenState();
}

class _CreateVoicePostScreenState extends State<CreateVoicePostScreen> {
  AudioRecorder? _rec;
  AudioPlayer? _player;
  StreamSubscription? _ampSub;
  Timer? _timer;
  bool _recording = false;
  bool _playing = false;
  bool _busy = false;
  String? _path;
  Duration _dur = Duration.zero;
  final List<int> _levels = [];
  File? _cover;
  final _caption = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _rec?.dispose();
    _player?.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(m)));

  Future<void> _start() async {
    final rec = _rec ??= AudioRecorder();
    try {
      if (!await rec.hasPermission()) {
        _snack(tr('voice.micDenied'));
        return;
      }
      await _player?.stop();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_post_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await rec.start(const RecordConfig(encoder: AudioEncoder.aacLc,
          bitRate: 96000, sampleRate: 44100), path: path);
      _levels.clear();
      _ampSub?.cancel();
      _ampSub = rec.onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((a) => _levels.add(amplitudeToLevel(a.current)));
      final started = DateTime.now();
      setState(() { _recording = true; _path = null; _dur = Duration.zero; _playing = false; });
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final d = DateTime.now().difference(started);
        if (!mounted) return;
        setState(() => _dur = d);
        if (d >= voiceMaxDuration) _stop();
      });
    } catch (_) {
      _snack(tr('voice.failed'));
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _timer?.cancel();
    _ampSub?.cancel();
    String? path;
    try { path = await _rec?.stop(); } catch (_) {}
    if (!mounted) return;
    final d = _dur > voiceMaxDuration ? voiceMaxDuration : _dur;
    setState(() { _recording = false; _dur = d; });
    if (path == null || d < const Duration(seconds: 1)) {
      _snack(tr('voice.tooShort'));
      return;
    }
    setState(() => _path = path);
  }

  Future<void> _togglePreview() async {
    final p = _path;
    if (p == null) return;
    final pl = _player ??= AudioPlayer()
      ..onPlayerComplete.listen((_) { if (mounted) setState(() => _playing = false); });
    if (_playing) {
      await pl.pause();
      setState(() => _playing = false);
    } else {
      await pl.play(DeviceFileSource(p));
      setState(() => _playing = true);
    }
  }

  Future<void> _pickCover() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery,
        maxWidth: 1400, imageQuality: 85);
    if (x != null) setState(() => _cover = File(x.path));
  }

  Future<void> _publish() async {
    final p = _path;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _player?.stop();
      final up = UploadManager();
      final audioUrl = await up.uploadFile(File(p));
      final coverUrl = _cover == null ? '' : await up.uploadFile(_cover!);
      final r = await ApiClient.instance.post('/posts/', body: voicePostBody(
          audioUrl: audioUrl, duration: _dur, levels: _levels,
          caption: _caption.text, coverUrl: coverUrl));
      if (r.statusCode >= 400) {
        String msg = tr('voice.failed');
        try { msg = (jsonDecode(r.body) as Map)['message']?.toString() ?? msg; } catch (_) {}
        throw Exception(msg);
      }
      if (!mounted) return;
      _snack(tr('voice.published'));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final s = e.toString().replaceFirst('Exception: ', '');
      _snack(s.length < 160 ? s : tr('voice.failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = downsampleLevels(_levels, n: 48).map((v) => v / 100.0).toList();
    final progress = _dur.inMilliseconds / voiceMaxDuration.inMilliseconds;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('voice.new'), style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            key: const ValueKey('voice-publish'),
            onPressed: _path != null && !_busy && !_recording ? _publish : null,
            child: _busy
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(tr('voice.publish'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.musicGradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            image: _cover == null ? null : DecorationImage(
                image: FileImage(_cover!), fit: BoxFit.cover,
                colorFilter: const ColorFilter.mode(Color(0x66000000), BlendMode.darken)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Text(_recording ? tr('voice.recording')
                    : tr('voice.limit', {'n': voiceMaxDuration.inSeconds}),
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const Spacer(),
            WaveformBars(samples: levels.isEmpty ? const [0.05] : levels,
                progress: 1, height: 70),
            const SizedBox(height: 12),
            Text(formatVoiceDuration(_dur),
                key: const ValueKey('voice-rec-time'),
                style: const TextStyle(color: Colors.white, fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0),
                  minHeight: 4, backgroundColor: Colors.white24,
                  color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_path != null && !_recording) ...[
            _round(_playing ? AppIcons.pause_rounded : AppIcons.play_arrow_rounded,
                _togglePreview, key: 'voice-preview'),
            const SizedBox(width: 24),
          ],
          GestureDetector(
            key: const ValueKey('voice-record'),
            onTap: _recording ? _stop : _start,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 84, height: 84,
              decoration: BoxDecoration(
                color: _recording ? const Color(0xFFE53935) : AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE53935), width: 3),
              ),
              child: Icon(_recording ? AppIcons.pause_rounded : AppIcons.mic_rounded,
                  color: _recording ? Colors.white : const Color(0xFFE53935), size: 36),
            ),
          ),
          if (_path != null && !_recording) ...[
            const SizedBox(width: 24),
            _round(AppIcons.refresh_rounded, _start, key: 'voice-retake'),
          ],
        ]),
        const SizedBox(height: 8),
        Center(child: Text(
            _path == null && !_recording ? tr('voice.tapToRecord') : '',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13))),
        const SizedBox(height: 18),
        TextField(
          controller: _caption,
          maxLength: 2200, minLines: 1, maxLines: 4,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: tr('voice.captionHint'),
            hintStyle: TextStyle(color: AppColors.textFaint),
            filled: true, fillColor: AppColors.card, counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(AppIcons.photo_library_outlined, color: AppColors.textPrimary),
          title: Text(tr('voice.cover'), style: TextStyle(color: AppColors.textPrimary)),
          trailing: _cover == null
              ? Icon(AppIcons.chevron_right_rounded, color: AppColors.textFaint)
              : IconButton(icon: Icon(AppIcons.close_rounded, color: AppColors.textFaint),
                  onPressed: () => setState(() => _cover = null)),
          onTap: _pickCover,
        ),
      ]),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap, {String? key}) => GestureDetector(
        key: key == null ? null : ValueKey(key),
        onTap: onTap,
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      );
}
