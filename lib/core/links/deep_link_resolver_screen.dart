// lib/core/links/deep_link_resolver_screen.dart
// ════════════════════════════════════════════════════════════════════
//  Кушодани мӯҳтаво аз линки чуқур.
//
//  Линк танҳо ШИНОСА дорад, вале экранҳои мавҷуда объекти пурраро
//  мехоҳанд. Ин экран мӯҳтаворо мегирад ва баъд экрани МАВҶУДАро
//  нишон медиҳад — ҳеҷ экрани мавҷуда тағйир дода намешавад.
//
//  Дастрасӣ дар СЕРВЕР санҷида мешавад: пости нестшуда, аккаунти
//  пӯшида ё корбари блоккарда хатои муқаррарӣ бармегардонад ва ин ҷо
//  ҳамчун «дастнорас» нишон дода мешавад.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../feed/post/post_detail_screen.dart';
import '../../models/post_model.dart';
import '../api/api_client.dart';
import '../i18n/strings.dart';
import '../ui/app_icons.dart';
import 'deep_links.dart';

class DeepLinkResolverScreen extends StatefulWidget {
  final DeepLink link;
  const DeepLinkResolverScreen({super.key, required this.link});

  @override
  State<DeepLinkResolverScreen> createState() => _DeepLinkResolverScreenState();
}

class _DeepLinkResolverScreenState extends State<DeepLinkResolverScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    try {
      switch (widget.link.kind) {
        case DeepLinkKind.post:
          await _openPost(widget.link.id);
          return;
        case DeepLinkKind.reel:
          // Рилси ягона ҳамчун пост кушода мешавад: экрани рилс
          // рӯйхат мехоҳад ва тағйир додани он хатари регрессия дорад.
          await _openPost(widget.link.id, reel: true);
          return;
        default:
          setState(() => _error = tr('link.unavailable'));
      }
    } catch (_) {
      if (mounted) setState(() => _error = tr('link.unavailable'));
    }
  }

  Future<void> _openPost(String id, {bool reel = false}) async {
    final res = await ApiClient.instance.get(reel ? '/reels/$id' : '/posts/$id');
    if (res.statusCode >= 400) {
      // Сервер дастрасиро рад кард — сабабро ихтироъ намекунем.
      if (mounted) setState(() => _error = tr('link.unavailable'));
      return;
    }
    final body = jsonDecode(res.body);
    final map = (body is Map && body['post'] is Map)
        ? (body['post'] as Map).cast<String, dynamic>()
        : (body as Map).cast<String, dynamic>();

    final post = PostModel.fromJson(map);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PostDetailScreen(posts: [post], initialIndex: 0),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(AppIcons.error_outline,
                        size: 40, color: AppColors.textFaint),
                    const SizedBox(height: 12),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14)),
                  ]),
                ),
        ),
      );
}
