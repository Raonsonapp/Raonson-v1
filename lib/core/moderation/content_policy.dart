// lib/core/moderation/content_policy.dart
//
// Қоидаҳои мӯҳтаво дар барнома: Raonson оилавист — 18+, порнография,
// урёнӣ ва дашноми қабеҳ манъ аст.
//
// Сервер ҳакам аст (ниг. backend/moderation): он ҳар пост, Reel,
// сторис, шарҳ, паём ва bio-ро ПЕШ аз нашр месанҷад ва ҳангоми
// вайронкунӣ 403 бо `code: content_blocked` бармегардонад. Ин файл
// танҳо он ҷавобро ба корбар фаҳмо нишон медиҳад ва пеш аз фиристодани
// линк дар чат огоҳ мекунад — то корбар бехабар «огоҳӣ» (strike) нагирад.
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../ui/app_icons.dart';

/// Ҳамон матне, ки сервер мефиристад.
const String kContentBlockedMessage =
    'Ин мӯҳтаво қоидаҳои Raonson-ро вайрон мекунад';

/// Ҷавоби «рад шуд»-и сервер.
class ContentRejection implements Exception {
  /// `content_blocked` ё `account_suspended`.
  final String code;
  final String message;
  final List<String> categories;
  final DateTime? suspendedUntil;

  const ContentRejection({
    required this.code,
    required this.message,
    this.categories = const [],
    this.suspendedUntil,
  });

  bool get isSuspension => code == 'account_suspended';

  @override
  String toString() => message;
}

class ContentPolicy {
  ContentPolicy._();

  /// Ҷавоби HTTP-ро мехонад. null — ин рад шудани мӯҳтаво нест.
  static ContentRejection? fromResponse(int status, String body) {
    if (status != 403) return null;
    return fromBody(body);
  }

  /// Матни JSON-и сервер → [ContentRejection] (ё null).
  static ContentRejection? fromBody(String body) {
    try {
      final j = jsonDecode(body);
      if (j is! Map) return null;
      final code = (j['code'] ?? '').toString();
      final msg = (j['message'] ?? j['error'] ?? '').toString();
      if (code != 'content_blocked' &&
          code != 'account_suspended' &&
          !msg.contains(kContentBlockedMessage)) {
        return null;
      }
      final until = DateTime.tryParse((j['suspendedUntil'] ?? '').toString());
      return ContentRejection(
        code: code.isEmpty ? 'content_blocked' : code,
        message: msg.isEmpty ? kContentBlockedMessage : msg,
        categories: ((j['categories'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        suspendedUntil: until?.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Аз хатои дилхоҳ (масалан `Exception('Upload 403: {...}')`)
  /// [ContentRejection]-ро меёбад.
  static ContentRejection? fromError(Object? error) {
    if (error == null) return null;
    if (error is ContentRejection) return error;
    final s = error.toString();
    final i = s.indexOf('{');
    final j = s.lastIndexOf('}');
    if (i >= 0 && j > i) {
      final r = fromBody(s.substring(i, j + 1));
      if (r != null) return r;
    }
    if (s.contains(kContentBlockedMessage)) {
      return const ContentRejection(
          code: 'content_blocked', message: kContentBlockedMessage);
    }
    return null;
  }

  /// Матни фаҳмо барои экран: рад шудани мӯҳтаво — матни сервер;
  /// дигар хатоҳо — бе «Exception:» ва JSON-и хом.
  static String friendlyError(Object? error, {String fallback = 'Нашр нашуд'}) {
    final r = fromError(error);
    if (r != null) return r.message;
    var s = (error ?? '').toString().replaceAll('Exception: ', '').trim();
    final i = s.indexOf('{');
    if (i >= 0) {
      try {
        final j = jsonDecode(s.substring(i));
        final m = (j is Map ? j['message'] : null)?.toString();
        if (m != null && m.isNotEmpty) return m;
      } catch (_) {}
    }
    return s.isEmpty ? fallback : s;
  }

  // ── Линкҳо дар чат ──────────────────────────────────────────────
  //
  // Нусхаи хурди рӯйхати сервер (backend/moderation/data/
  // adult_domains.txt) — танҳо барои огоҳии пешакӣ. Сервер ҳамеша
  // худаш месанҷад; ин рӯйхат набошад ҳам, паём рад мешавад.
  static const List<String> _adultDomains = [
    'pornhub.com', 'xvideos.com', 'xnxx.com', 'xhamster.com', 'redtube.com',
    'youporn.com', 'tube8.com', 'spankbang.com', 'eporner.com', 'beeg.com',
    'txxx.com', 'porn.com', 'youjizz.com', 'motherless.com', 'brazzers.com',
    'onlyfans.com', 'fansly.com', 'chaturbate.com', 'stripchat.com',
    'bongacams.com', 'livejasmin.com', 'cam4.com', 'camsoda.com',
    'myfreecams.com', 'nhentai.net', 'e-hentai.org', 'hanime.tv',
    'rule34.xxx', 'pornolab.net', 'erome.com', 'fapello.com', 'sex.com',
  ];
  static const List<String> _adultTlds = ['xxx', 'porn', 'sex', 'adult'];
  static const List<String> _adultWords = [
    'porn', 'xvideo', 'xnxx', 'xhamster', 'hentai', 'sexcam', 'sextube',
    'sexchat', 'onlyfans', 'chaturbate', 'stripchat',
  ];

  static final RegExp _urlRe = RegExp(
    r'(?:https?://|www\.)[^\s<>"]+|\b[a-z0-9][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*)*\.[a-z]{2,24}\b',
    caseSensitive: false,
  );
  static final RegExp _dotRe = RegExp(
    r'\s*(?:\[\.\]|\(\.\)|\s+dot\s+|\s+точка\s+|\s+нуқта\s+)\s*',
    caseSensitive: false,
  );

  static String _hostOf(String raw) {
    var s = raw.trim();
    if (!s.contains('://')) s = 'http://$s';
    final u = Uri.tryParse(s);
    var h = (u?.host ?? '').toLowerCase();
    if (h.endsWith('.')) h = h.substring(0, h.length - 1);
    if (h.startsWith('www.')) h = h.substring(4);
    return h;
  }

  /// Домени 18+ дар матн (ё null).
  static String? adultLinkIn(String text) {
    if (text.isEmpty) return null;
    final t = text.replaceAll(_dotRe, '.');
    for (final m in _urlRe.allMatches(t)) {
      final host = _hostOf(m.group(0)!);
      if (host.isEmpty || !host.contains('.')) continue;
      final parts = host.split('.');
      for (var i = 0; i < parts.length - 1; i++) {
        if (_adultDomains.contains(parts.sublist(i).join('.'))) return host;
      }
      if (_adultTlds.contains(parts.last)) return host;
      final labels = parts.sublist(0, parts.length - 1).join('.');
      if (_adultWords.any(labels.contains)) return host;
    }
    return null;
  }
}

/// Равзанаи «Мӯҳтаво рад шуд» — дар экранҳои сохтан ва чат.
Future<void> showContentRejection(BuildContext context, ContentRejection r) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => ContentRejectionDialog(rejection: r),
  );
}

class ContentRejectionDialog extends StatelessWidget {
  final ContentRejection rejection;
  const ContentRejectionDialog({super.key, required this.rejection});

  String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final r = rejection;
    final until = r.suspendedUntil;
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Icon(
          r.isSuspension ? AppIcons.lock_outline_rounded : AppIcons.error_outline,
          color: const Color(0xFFFF3040),
          size: 36),
      title: Text(
        r.isSuspension ? 'Нашр муваққатан маҳдуд аст' : 'Мӯҳтаво нашр нашуд',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700),
      ),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(r.message,
            key: const Key('content-rejection-message'),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 14, height: 1.4)),
        const SizedBox(height: 10),
        Text(
          r.isSuspension
              ? 'Шумо метавонед хонед ва тамошо кунед.'
              : 'Raonson барномаи оилавист: мӯҳтавои 18+, урёнӣ, '
                  'порнография ва дашноми қабеҳ манъ аст. '
                  'Вайронкунии такрорӣ ҳисобро маҳдуд мекунад.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
        ),
        if (until != null && !r.isSuspension) ...[
          const SizedBox(height: 10),
          Text('Нашр то ${_date(until)} маҳдуд шуд.',
              key: const Key('content-rejection-until'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFFF3040),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Фаҳмидам'),
        ),
      ],
    );
  }
}

/// Огоҳии пеш аз фиристодани линки 18+ дар чат. Паём фиристода
/// намешавад — сервер онро ба ҳар ҳол рад мекард ва огоҳӣ медод.
Future<void> showAdultLinkWarning(BuildContext context, String host) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: const Icon(AppIcons.error_outline,
          color: Color(0xFFFF9500), size: 36),
      title: Text('Линки манъшуда',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700)),
      content: Text(
        '«$host» — сайти 18+ аст. $kContentBlockedMessage, '
        'бинобар ин паём фиристода намешавад.',
        key: const Key('adult-link-warning'),
        textAlign: TextAlign.center,
        style: TextStyle(
            color: AppColors.textPrimary, fontSize: 14, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Фаҳмидам'),
        ),
      ],
    ),
  );
}
