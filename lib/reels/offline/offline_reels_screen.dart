// lib/reels/offline/offline_reels_screen.dart — рӯйхати Reels-и офлайн.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/app_theme.dart';
import '../../core/i18n/strings.dart';
import '../../core/ui/app_icons.dart';
import 'offline_reels.dart';

class OfflineReelsScreen extends StatefulWidget {
  const OfflineReelsScreen({super.key});
  @override
  State<OfflineReelsScreen> createState() => _OfflineReelsScreenState();
}

class _OfflineReelsScreenState extends State<OfflineReelsScreen> {
  final _store = OfflineReels.instance;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(tr('offline.title'),
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (ctx, _) {
          final items = _store.items;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(tr('offline.empty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 9 / 16,
                mainAxisSpacing: 2, crossAxisSpacing: 2),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final r = items[i];
              return GestureDetector(
                onTap: () => Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => _OfflinePlayer(reel: r))),
                onLongPress: () => _confirmDelete(r),
                child: Stack(fit: StackFit.expand, children: [
                  Container(color: AppColors.surface),
                  if (r.thumbPath.isNotEmpty)
                    Image.file(File(r.thumbPath), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox()),
                  Positioned(
                    left: 6, bottom: 6, right: 6,
                    child: Text('@${r.username}', maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(OfflineReel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('offline.deleteTitle')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('common.cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('offline.delete'),
                  style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) await _store.remove(r.id);
  }
}

class _OfflinePlayer extends StatefulWidget {
  final OfflineReel reel;
  const _OfflinePlayer({required this.reel});
  @override
  State<_OfflinePlayer> createState() => _OfflinePlayerState();
}

class _OfflinePlayerState extends State<_OfflinePlayer> {
  late final VideoPlayerController _c =
      VideoPlayerController.file(File(widget.reel.videoPath));
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (!mounted) return;
      _c..setLooping(true)..play();
      setState(() => _ready = true);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (_ready)
          GestureDetector(
            onTap: () => _c.value.isPlaying ? _c.pause() : _c.play(),
            child: FittedBox(fit: BoxFit.cover, child: SizedBox(
                width: _c.value.size.width, height: _c.value.size.height,
                child: VideoPlayer(_c))),
          )
        else if (widget.reel.thumbPath.isNotEmpty)
          Image.file(File(widget.reel.thumbPath), fit: BoxFit.cover),
        SafeArea(child: Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            icon: const Icon(AppIcons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        )),
        if (widget.reel.caption.isNotEmpty)
          Positioned(left: 16, right: 16, bottom: 32,
            child: Text(widget.reel.caption, maxLines: 3,
                style: const TextStyle(color: Colors.white,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]))),
      ]),
    );
  }
}
