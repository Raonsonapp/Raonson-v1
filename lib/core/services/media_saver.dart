// lib/core/services/media_saver.dart
// Захираи акс/видеои пост, рилс ва сторис бо хабари воқеӣ.
//
// Пеш «Зеркашӣ» танҳо браузерро мекушод ва ҳеҷ чиз захира намешуд.
// Акнун файл воқеан ба дастгоҳ меафтад ва корбар натиҷаро мебинад:
// муваффақият ё хато.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../anime/download_service.dart';
import '../../app/app_config.dart';
import '../api/api_client.dart';

/// Файлро аз [url] захира мекунад ва натиҷаро дар SnackBar нишон медиҳад.
/// Бармегардонад: `true` агар файл захира шуда бошад.
Future<bool> saveMediaWithFeedback(BuildContext context, String url,
    {String name = 'raonson'}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (url.isEmpty) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Файл барои захира нест')));
    return false;
  }
  messenger.showSnackBar(const SnackBar(
      content: Text('Захира шуда истодааст…'),
      duration: Duration(seconds: 1)));
  try {
    final path = await DownloadService.saveMedia(url, name: name);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: const Text('Дар дастгоҳ захира шуд'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 4),
      // Ба галерея ё барномаи дигар тавассути варақаи системавӣ.
      action: SnackBarAction(
        label: 'Кушодан',
        textColor: Colors.white,
        onPressed: () => Share.shareXFiles([XFile(path)]),
      ),
    ));
    return true;
  } catch (_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(
        content: Text('Захира нашуд. Интернетро санҷед ва боз кӯшиш кунед.')));
    return false;
  }
}

/// Боргирӣ бо тамғаи Raonson (логотип + «@муаллиф»), мисли TikTok.
///
/// Сервер ([kind]: post | reel | story) суроға ва номи муаллифро худаш аз
/// база мегирад ва тамға мегузорад. Агар натавонад (анбори беруна, сервер
/// банд) — файли асл бе тамға захира мешавад, то корбар бе чиз намонад.
Future<bool> saveContentWithFeedback(BuildContext context,
    {required String kind, required String id, int index = 0,
     required String fallbackUrl, required String name, bool isVideo = false}) async {
  final messenger = ScaffoldMessenger.of(context);
  final token = ApiClient.instance.authToken ?? '';
  if (id.isEmpty || token.isEmpty) {
    return saveMediaWithFeedback(context, fallbackUrl, name: name);
  }
  messenger.showSnackBar(SnackBar(
      content: Text(isVideo ? 'Видео омода шуда истодааст…' : 'Захира шуда истодааст…'),
      duration: const Duration(seconds: 2)));
  final url = '${AppConfig.apiBaseUrl}/media/download'
      '?kind=$kind&id=${Uri.encodeComponent(id)}&index=$index';
  try {
    final path = await DownloadService.saveMedia(url,
        name: name, headers: {'Authorization': 'Bearer $token'},
        ext: isVideo ? 'mp4' : 'jpg');
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: const Text('Дар дастгоҳ захира шуд'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Кушодан',
        textColor: Colors.white,
        onPressed: () => Share.shareXFiles([XFile(path)]),
      ),
    ));
    return true;
  } catch (_) {
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return false;
    return saveMediaWithFeedback(context, fallbackUrl, name: name);
  }
}
