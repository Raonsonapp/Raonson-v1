import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/reel_model.dart';
import '../../core/services/network_quality.dart';
import '../../app/app_theme.dart';
import '../../core/ui/app_icons.dart';
import '../../widgets/embed_player.dart';
import 'reel_controls.dart';
import 'reel_gestures.dart';

class ReelPlayer extends StatefulWidget {
  final ReelModel reel;
  final VoidCallback onLike;

  const ReelPlayer({
    super.key,
    required this.reel,
    required this.onLike,
  });

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  // Барои линкҳои embed (Aparat/YouTube) контроллер сохта намешавад.
  VideoPlayerController? _videoController;
  bool _initialized = false;
  bool _failed = false;

  bool get _isEmbed => EmbedUtils.isEmbed(widget.reel.videoUrl);

  @override
  void initState() {
    super.initState();
    // Embed файли видео нест — VideoPlayer онро ҳеҷ гоҳ кушода наметавонад
    // (спиннери абадӣ); ҳамон EmbedPlayer-и reels_screen истифода мешавад.
    if (_isEmbed) return;
    final url = NetworkQuality.pick(
        widget.reel.videoUrl, widget.reel.videoUrlLow);
    if (url.isEmpty) {
      _failed = true;
      return;
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = c;
    c.initialize().then((_) {
      if (!mounted) return;
      c
        ..setLooping(true)
        ..play();
      setState(() => _initialized = true);
    }).catchError((Object e) {
      // Видеои ҳазфшуда/вайрон — ба ҷои спиннери абадӣ хато нишон медиҳем.
      debugPrint('[ReelPlayer] видео кушода нашуд: $e');
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _videoController;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (_isEmbed)
          EmbedPlayer(url: widget.reel.videoUrl)
        else if (_initialized && ctrl != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: ctrl.value.size.width,
              height: ctrl.value.size.height,
              child: VideoPlayer(ctrl),
            ),
          )
        else if (widget.reel.thumbnailUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: widget.reel.thumbnailUrl,
            fit: BoxFit.cover,
            memCacheWidth: 720,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (_, __, ___) => Container(color: AppColors.bg),
          )
        else
          Container(color: AppColors.bg),

        if (_failed)
          const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(AppIcons.videocam_off_rounded,
                  color: Colors.white70, size: 40),
              SizedBox(height: 10),
              Text('Видео кушода нашуд',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          )
        else if (!_initialized && !_isEmbed)
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Colors.white70),
            ),
          ),

        ReelGestures(
          onLike: widget.onLike,
          onPauseToggle: () {
            if (ctrl == null || !_initialized) return;
            if (ctrl.value.isPlaying) {
              ctrl.pause();
            } else {
              ctrl.play();
            }
            setState(() {});
          },
        ),

        ReelControls(
          reel: widget.reel,
          isPlaying: ctrl?.value.isPlaying ?? false,
        ),
      ],
    );
  }
}
