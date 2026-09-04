// lib/core/links/share_sheet.dart
// ════════════════════════════════════════════════════════════════════
//  Мубодилаи мӯҳтаво: линки веб + share sheet-и системавӣ.
//
//  share_plus аллакай дар лоиҳа ҳаст — пакети нав илова намешавад.
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../i18n/strings.dart';
import 'deep_links.dart';

/// Мӯҳтаворо бо share sheet-и системавӣ мубодила мекунад.
///
/// Ҳамеша линки ВЕБ фиристода мешавад: гиранда метавонад барномаро
/// надошта бошад ва схемаи `raonson://` дар ин ҳолат мурда мемонад.
Future<void> shareDeepLink(
  BuildContext context, {
  required DeepLinkKind kind,
  required String id,
  String? text,
}) async {
  if (id.isEmpty) return;
  final link = DeepLinks.share(kind, id);
  final body = (text == null || text.isEmpty) ? link : '$text\n$link';
  try {
    await Share.share(body, subject: 'Raonson');
  } catch (_) {
    // Агар share sheet кушода нашуд, ҳадди ақал линкро нусха мекунем,
    // то амали корбар беҷавоб намонад.
    await copyDeepLink(context, kind: kind, id: id);
  }
}

/// Линкро ба clipboard мегузорад.
Future<void> copyDeepLink(
  BuildContext context, {
  required DeepLinkKind kind,
  required String id,
}) async {
  if (id.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: DeepLinks.share(kind, id)));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(tr('share.linkCopied')),
    behavior: SnackBarBehavior.floating,
  ));
}
