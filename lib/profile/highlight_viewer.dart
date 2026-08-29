// lib/profile/highlight_viewer.dart
// Намоиши актуалӣ (highlight) — мисли Instagram: progress bars, навигатсия,
// меню (зеркашӣ / номивазкунӣ / нест кардан / мубодила).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_theme.dart';
import 'highlight_model.dart';
import '../core/ui/app_icons.dart';
import '../core/i18n/strings.dart';

class HighlightViewer extends StatefulWidget {
  final HighlightModel highlight;
  final bool isOwner;
  final Future<void> Function(String title)? onRename;
  final Future<void> Function()? onDeleteHighlight;
  final Future<void> Function(List<HighlightItem> items)? onItemsChanged;

  const HighlightViewer({
    super.key,
    required this.highlight,
    this.isOwner = false,
    this.onRename,
    this.onDeleteHighlight,
    this.onItemsChanged,
  });

  @override
  State<HighlightViewer> createState() => _HighlightViewerState();
}

class _HighlightViewerState extends State<HighlightViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _progress;
  Timer? _timer;
  int _idx = 0;
  bool _paused = false;
  late List<HighlightItem> _items;
  late String _title;

  VideoPlayerController? _video;
  bool _videoReady = false;

  static const Duration _imageDur = Duration(seconds: 5);

  HighlightItem get _cur => _items[_idx];
  bool get _isVideo => _cur.type == 'video';

  @override
  void initState() {
    super.initState();
    _items = List<HighlightItem>.from(widget.highlight.items);
    _title = widget.highlight.title;
    _progress = AnimationController(vsync: this);
    if (_items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _timer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  void _load() {
    _video?.dispose();
    _video = null;
    _videoReady = false;
    if (_isVideo) {
      _video = VideoPlayerController.networkUrl(Uri.parse(_cur.url))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() => _videoReady = true);
          _video!..setLooping(false)..play();
          final d = _video!.value.duration;
          _start(d.inSeconds > 0 ? d : const Duration(seconds: 15));
        });
    } else {
      _start(_imageDur);
    }
  }

  void _start(Duration d) {
    _progress
      ..duration = d
      ..reset()
      ..forward();
    _timer?.cancel();
    _timer = Timer(d, _next);
  }

  void _pause() {
    if (_paused) return;
    _progress.stop();
    _timer?.cancel();
    _video?.pause();
    setState(() => _paused = true);
  }

  void _resume() {
    if (!_paused) return;
    final remaining = _progress.duration! * (1 - _progress.value);
    _progress.forward();
    _timer = Timer(remaining, _next);
    _video?.play();
    setState(() => _paused = false);
  }

  void _next() {
    if (_idx < _items.length - 1) {
      setState(() { _idx++; _paused = false; });
      _load();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_idx > 0) {
      setState(() { _idx--; _paused = false; });
      _load();
    }
  }

  // ── Меню (⋮) ────────────────────────────────────────────────
  void _menu() {
    _pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: AppColors.textFaint,
                  borderRadius: BorderRadius.circular(2))),
          _tile(ctx, AppIcons.download_rounded, 'Зеркашӣ', _download),
          _tile(ctx, AppIcons.share_outlined, 'Мубодила', _share),
          if (widget.isOwner) ...[
            _tile(ctx, AppIcons.drive_file_rename_outline_rounded,
                'Номивазкунӣ', _rename),
            _tile(ctx, AppIcons.hide_image_outlined,
                'Ин расмро аз актуалӣ нест кун', _removeItem),
            _tile(ctx, AppIcons.delete_outline_rounded,
                'Актуалиро нест кун', _deleteHighlight, color: Colors.redAccent),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    ).whenComplete(_resume);
  }

  Widget _tile(BuildContext ctx, IconData icon, String label, VoidCallback onTap,
          {Color? color}) =>
      ListTile(
        leading: Icon(icon, color: color ?? AppColors.textPrimary),
        title: Text(label, style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 15)),
        onTap: () { Navigator.pop(ctx); onTap(); },
      );

  void _download() {
    if (_cur.url.isNotEmpty) {
      launchUrl(Uri.parse(_cur.url), mode: LaunchMode.externalApplication);
    }
  }

  void _share() => Share.share('Raonson: ${_cur.url}');

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _title);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(tr('ui.efc0a35af9'),
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl, autofocus: true, maxLength: 20,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: tr('ui.3679b2134b'),
            hintStyle: TextStyle(color: AppColors.textFaint),
            counterStyle: TextStyle(color: AppColors.textFaint),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.textFaint)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.neonBlue)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(tr('ui.47ba09d086'),
                  style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text),
              child: Text(tr('ui.cb206b6c88'),
                  style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      setState(() => _title = name.trim());
      await widget.onRename?.call(name.trim());
    }
    _resume();
  }

  Future<void> _removeItem() async {
    setState(() {
      _items.removeAt(_idx);
      if (_idx >= _items.length) _idx = _items.length - 1;
    });
    if (_items.isEmpty) {
      await widget.onItemsChanged?.call(const []);
      if (mounted) Navigator.pop(context);
      return;
    }
    if (_idx < 0) _idx = 0;
    await widget.onItemsChanged?.call(_items);
    _load();
  }

  Future<void> _deleteHighlight() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(tr('ui.e6326ea2d4'), style: TextStyle(color: AppColors.textPrimary)),
        content: Text(tr('ui.5a9e354e38'),
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(tr('ui.47ba09d086'), style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text(tr('ui.b03ce66658'),
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) {
      await widget.onDeleteHighlight?.call();
      if (mounted) Navigator.pop(context);
    } else {
      _resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    if (_items.isEmpty) {
      return Scaffold(backgroundColor: AppColors.bg);
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd:   (_) => _resume(),
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx < w * 0.33) { _prev(); }
          else if (d.globalPosition.dx > w * 0.67) { _next(); }
          else { _paused ? _resume() : _pause(); }
        },
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.pop(context);
        },
        child: Stack(fit: StackFit.expand, children: [
          // Media
          _isVideo ? _buildVideo() : _buildImage(),

          // Top gradient
          Positioned(top: 0, left: 0, right: 0, height: 150,
            child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.6), Colors.transparent])))),

          // Progress bars
          Positioned(
            top: top + 6, left: 8, right: 8,
            child: Row(children: List.generate(_items.length, (i) {
              return Expanded(child: Padding(
                padding: EdgeInsets.only(right: i < _items.length - 1 ? 3 : 0),
                child: i < _idx
                    ? _bar(1.0)
                    : i == _idx
                        ? (_isVideo && !_videoReady)
                            ? _bar(0)
                            : AnimatedBuilder(
                                animation: _progress,
                                builder: (_, __) => _bar(_progress.value))
                        : _bar(0.0),
              ));
            })),
          ),

          // Header
          Positioned(
            top: top + 18, left: 14, right: 10,
            child: Row(children: [
              Text(_title,
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold, fontSize: 15,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
              const Spacer(),
              GestureDetector(
                onTap: _menu,
                child: Padding(padding: EdgeInsets.all(6),
                  child: Icon(AppIcons.more_vert, color: AppColors.textPrimary, size: 24))),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Padding(padding: EdgeInsets.all(6),
                  child: Icon(AppIcons.close, color: AppColors.textPrimary, size: 24))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bar(double v) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: LinearProgressIndicator(
      value: v, backgroundColor: AppColors.textFaint,
      valueColor: AlwaysStoppedAnimation(AppColors.textPrimary), minHeight: 2.5));

  Widget _buildImage() {
    if (_cur.url.isEmpty) return Container(color: AppColors.bg);
    return CachedNetworkImage(
      imageUrl: _cur.url, fit: BoxFit.contain,
      memCacheWidth: 1080,
      width: double.infinity, height: double.infinity,
      placeholder: (_, __) => Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textFaint)),
      errorWidget: (_, __, ___) => Center(
          child: Icon(AppIcons.broken_image_outlined, color: AppColors.textFaint, size: 64)));
  }

  Widget _buildVideo() {
    if (!_videoReady) {
      return Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textFaint));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _video!.value.aspectRatio,
        child: VideoPlayer(_video!)));
  }
}
