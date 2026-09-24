// lib/core/services/media_saver.dart
// Захираи акс/видеои пост, рилс ва сторис бо хабари воқеӣ.
//
// Пеш «Зеркашӣ» танҳо браузерро мекушод ва ҳеҷ чиз захира намешуд.
// Акнун файл воқеан ба дастгоҳ меафтад ва корбар натиҷаро мебинад:
// муваффақият ё хато.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../anime/download_service.dart';

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
