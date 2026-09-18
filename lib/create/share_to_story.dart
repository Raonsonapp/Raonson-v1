import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';
import '../stories/story_repository.dart';
import 'upload/upload_manager.dart';

// ══════════════════════════════════════════════════════════════════
//  Пост ё Reel → стори (мисли Instagram).
//
//  Ин хусусият ТАМОМАН вуҷуд надошт: дар менюи пост банде набуд ва
//  дар база ҷое барои он набуд.
//
//  Чӣ тавр кор мекунад: корти пост ҳамчун РАСМ кашида мешавад, он
//  расм бор карда мешавад ва стори бо ишора ба пости аслӣ сохта
//  мешавад. Ҳангоми тамошо занед — пости аслӣ кушода мешавад.
// ══════════════════════════════════════════════════════════════════

/// Пост ё Reel-ро ҳамчун стори паҳн мекунад.
///
/// [mediaUrl] — расми пост (ё муқоваи Reel).
/// [isReel] — навъи мундариҷа; аз он роҳи кушодан вобаста аст.
Future<void> shareToStory(
  BuildContext context, {
  required String id,
  required String mediaUrl,
  required String username,
  String avatarUrl = '',
  bool isReel = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _Preview(
      mediaUrl: mediaUrl,
      username: username,
      avatarUrl: avatarUrl,
      isReel: isReel,
    ),
  );
  if (confirmed != true) return;

  messenger.showSnackBar(
      const SnackBar(content: Text('Ба стори гузошта мешавад…')));

  try {
    final file = await _renderCard(
      mediaUrl: mediaUrl,
      username: username,
      isReel: isReel,
    );
    if (file == null) throw Exception('карт сохта нашуд');

    final uploaded = await UploadManager().uploadFile(file);
    if (uploaded.isEmpty) throw Exception('бор нашуд');

    final res = await ApiClient.instance.post('/stories/', body: {
      'mediaUrl': uploaded,
      'mediaType': 'image',
      'caption': '',
      'audience': 'all',
      // Маҳз ин стори-ро ба пости аслӣ мепайвандад.
      if (isReel) 'sharedReelId': id else 'sharedPostId': id,
    });
    if (res.statusCode >= 400) throw Exception('${res.statusCode}');

    await StoryRepository.clearAllCaches();
    messenger.showSnackBar(
        const SnackBar(content: Text('Ба стори гузошта шуд')));
  } catch (e) {
    debugPrint('[shareToStory] $e');
    messenger.showSnackBar(
        const SnackBar(content: Text('Гузошта нашуд')));
  }
}

/// Корти постро ҳамчун PNG мекашад.
///
/// Андоза 1080×1920 — ҳамон нисбати стори. Бе ин карт дар телефонҳои
/// гуногун гуногун менамуд.
Future<File?> _renderCard({
  required String mediaUrl,
  required String username,
  required bool isReel,
}) async {
  try {
    final bytes = await _widgetToPng(
      _StoryCard(
        mediaUrl: mediaUrl,
        username: username,
        isReel: isReel,
      ),
      const Size(1080, 1920),
    );
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final f = File(
        '${dir.path}/story_share_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(bytes);
    return f;
  } catch (e) {
    debugPrint('[shareToStory] render: $e');
    return null;
  }
}

/// Виҷетро берун аз дарахти намоён ба расм табдил медиҳад.
Future<Uint8List?> _widgetToPng(Widget widget, Size size) async {
  final repaint = RenderRepaintBoundary();
  final view = WidgetsBinding.instance.platformDispatcher.views.first;

  final pipeline = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());

  final root = RenderView(
    view: view,
    child: RenderPositionedBox(
        alignment: Alignment.center, child: repaint),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      devicePixelRatio: 1.0,
    ),
  );

  pipeline.rootNode = root;
  root.prepareInitialFrame();

  final element = RenderObjectToWidgetAdapter<RenderBox>(
    container: repaint,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: SizedBox(width: size.width, height: size.height, child: widget),
      ),
    ),
  ).attachToRenderTree(buildOwner);

  buildOwner
    ..buildScope(element)
    ..finalizeTree();
  pipeline
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();

  final image = await repaint.toImage(pixelRatio: 1.0);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

// ─────────────────────────────────────────────────────────────────
//  Худи карт — он чи дар стори намоён мешавад
// ─────────────────────────────────────────────────────────────────
class _StoryCard extends StatelessWidget {
  final String mediaUrl;
  final String username;
  final bool isReel;
  const _StoryCard({
    required this.mediaUrl,
    required this.username,
    required this.isReel,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.musicGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(90),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(mediaUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.black26)),
                  ),
                ),
                const SizedBox(height: 40),
                Text('@$username',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Text(isReel ? 'Reel' : 'Публикатсия',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 38)),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────
//  Пешнамоиш пеш аз нашр
// ─────────────────────────────────────────────────────────────────
class _Preview extends StatelessWidget {
  final String mediaUrl, username, avatarUrl;
  final bool isReel;
  const _Preview({
    required this.mediaUrl,
    required this.username,
    required this.avatarUrl,
    required this.isReel,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textFaint,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Ба стори гузоштан',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 150,
                height: 150,
                child: CachedNetworkImage(
                  imageUrl: mediaUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.card),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('@$username',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: AppColors.musicGradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.add_circle_outline,
                          color: AppColors.white, size: 19),
                      SizedBox(width: 8),
                      Text('Ба стори',
                          style: TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}
