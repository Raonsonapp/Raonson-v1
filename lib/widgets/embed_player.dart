// lib/widgets/embed_player.dart
// Видеоро аз силкаи берунӣ (Aparat / YouTube / ғ.) дар WebView-и embed
// бозӣ мекунад — чун онҳо файли мустақими видео нестанд.
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../app/app_theme.dart';

class EmbedUtils {
  /// Оё ин силка embed аст (на файли мустақими видео)?
  static bool isEmbed(String url) {
    final u = url.toLowerCase();
    if (u.isEmpty) return false;
    return u.contains('aparat.com') ||
        u.contains('youtube.com') ||
        u.contains('youtu.be') ||
        u.contains('vimeo.com') ||
        u.contains('dailymotion.com') ||
        u.contains('/embed');
  }

  /// Силкаро ба URL-и embed табдил медиҳад.
  static String embedUrl(String url) {
    final u = url.trim();
    // ── Aparat ──
    if (u.contains('aparat.com')) {
      final hash = _aparatHash(u);
      if (hash != null) {
        return 'https://www.aparat.com/video/video/embed/videohash/$hash/vt/frame';
      }
    }
    // ── YouTube ──
    final yt = _youtubeId(u);
    if (yt != null) {
      return 'https://www.youtube.com/embed/$yt?playsinline=1&rel=0';
    }
    return u; // аллакай embed ё навъи дигар
  }

  static String? _aparatHash(String u) {
    // .../v/HASH  ё  .../embed/videohash/HASH/...
    final m1 = RegExp(r'aparat\.com/v/([A-Za-z0-9]+)').firstMatch(u);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r'videohash/([A-Za-z0-9]+)').firstMatch(u);
    if (m2 != null) return m2.group(1);
    return null;
  }

  static String? _youtubeId(String u) {
    final m1 = RegExp(r'youtu\.be/([A-Za-z0-9_-]{6,})').firstMatch(u);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r'[?&]v=([A-Za-z0-9_-]{6,})').firstMatch(u);
    if (m2 != null) return m2.group(1);
    final m3 = RegExp(r'youtube\.com/embed/([A-Za-z0-9_-]{6,})').firstMatch(u);
    if (m3 != null) return m3.group(1);
    return null;
  }
}

class EmbedPlayer extends StatefulWidget {
  final String url; // силкаи аслӣ (embed ё саҳифа)
  const EmbedPlayer({super.key, required this.url});

  @override
  State<EmbedPlayer> createState() => _EmbedPlayerState();
}

class _EmbedPlayerState extends State<EmbedPlayer> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final u = request.url.toLowerCase();
          if (u.contains('aparat.com') ||
              u.contains('youtube.com') ||
              u.contains('youtu.be') ||
              u.contains('vimeo.com') ||
              u.contains('dailymotion.com') ||
              u.startsWith('about:blank')) {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(EmbedUtils.embedUrl(widget.url)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: AppColors.bg),
        WebViewWidget(controller: _controller),
        if (_loading)
          Center(
            child: CircularProgressIndicator(color: AppColors.textPrimary, strokeWidth: 2),
          ),
      ],
    );
  }
}
