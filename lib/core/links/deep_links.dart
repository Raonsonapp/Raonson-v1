// lib/core/links/deep_links.dart
// ════════════════════════════════════════════════════════════════════
//  Линкҳои чуқур (deep links).
//
//  Ин ҷо системаи дуюми routing сохта НАМЕШАВАД. Flutter худаш URI-и
//  воридшударо ба onGenerateRoute-и мавҷуда мерасонад; вазифаи ин
//  файл танҳо таҷзияи роҳ ва сохтани линки берунӣ аст.
//
//  Ду шакл дастгирӣ мешавад:
//    raonson://profile/ali          — схемаи худӣ, ҳамеша кор мекунад
//    https://<host>/Raonson-v1/l/profile/ali — App Link + fallback-и веб
// ════════════════════════════════════════════════════════════════════

/// Навъи мӯҳтавои линк.
enum DeepLinkKind { profile, post, reel, topic, referral, unknown }

/// Натиҷаи таҷзия.
class DeepLink {
  final DeepLinkKind kind;

  /// Шиноса: username барои профил, id барои пост/рилс, slug барои мавзӯъ.
  final String id;

  const DeepLink(this.kind, this.id);

  bool get isValid => kind != DeepLinkKind.unknown && id.isNotEmpty;

  @override
  String toString() => 'DeepLink($kind, $id)';
}

/// Сохтан ва хондани линкҳои Raonson.
class DeepLinks {
  DeepLinks._();

  /// Схемаи худии барнома.
  static const scheme = 'raonson';

  /// Асоси линки веб. Ҳамон домене, ки app-ads.txt дар он ҷойгир аст.
  ///
  /// Роҳи `/l/` кӯтоҳ аст ва аз саҳифаҳои дигари сайт ҷудо мемонад.
  static const webBase = 'https://raonsonapp.github.io/Raonson-v1/l';

  /// Асоси саҳифаи ПЕШНАМОИШ (сервер).
  ///
  /// Чаро ду асос ҳаст: GitHub Pages саҳифаи статикист ва ҳеҷ тегҳои
  /// OpenGraph надорад. Ҳангоми фиристодан ба WhatsApp ё Telegram
  /// мессенҷер маҳз ҳамон саҳифаро мехонад ва тегҳоро меҷӯяд — бе
  /// онҳо гиранда танҳо СATРИ УРЁНро мебинад, на видео.
  ///
  /// Саҳифаҳои /p/ ва /r/ дар сервер видео, аксбардор ва тавсифро
  /// медиҳанд, ва баъд корбарро ба барнома мебаранд.
  static const previewBase = String.fromEnvironment(
    'RAONSON_PREVIEW_BASE',
    defaultValue: 'https://mahmadmurodov-raonson.hf.space',
  );

  /// Роҳҳои кӯтоҳи саҳифаи пешнамоиш.
  static const _previewPaths = {
    DeepLinkKind.post: 'p',
    DeepLinkKind.reel: 'r',
  };

  static const _paths = {
    DeepLinkKind.profile: 'profile',
    DeepLinkKind.post: 'post',
    DeepLinkKind.reel: 'reel',
    DeepLinkKind.topic: 'topic',
    DeepLinkKind.referral: 'invite',
  };

  /// Линки берунӣ барои мубодила.
  ///
  /// Ҳамеша линки ВЕБ бармегардад, на схемаи худӣ: агар гиранда
  /// барномаро надошта бошад, схемаи `raonson://` дар ҳеҷ ҷо кушода
  /// намешавад ва линк мурда менамояд.
  ///
  /// Барои пост ва рилс линки САҲИФАИ ПЕШНАМОИШ дода мешавад, то
  /// дар чати гиранда видео ва аксбардор бароянд — на сатри урён.
  static String share(DeepLinkKind kind, String id) {
    if (id.isEmpty) return webBase;
    final preview = _previewPaths[kind];
    if (preview != null) {
      return '$previewBase/$preview/${Uri.encodeComponent(id)}';
    }
    final path = _paths[kind];
    if (path == null) return webBase;
    return '$webBase/$path/${Uri.encodeComponent(id)}';
  }

  /// Линки дохилии барнома (барои тест ва QR).
  static String appLink(DeepLinkKind kind, String id) {
    final path = _paths[kind];
    if (path == null || id.isEmpty) return '$scheme://';
    return '$scheme://$path/${Uri.encodeComponent(id)}';
  }

  /// URI ё роҳро ба DeepLink табдил медиҳад.
  ///
  /// Ҳам `raonson://profile/ali`, ҳам `https://.../l/profile/ali` ва ҳам
  /// роҳи оддии `/profile/ali` қабул мешавад — Flutter вобаста ба
  /// вазъият яке аз инҳоро медиҳад.
  static DeepLink parse(String raw) {
    if (raw.trim().isEmpty) return const DeepLink(DeepLinkKind.unknown, '');

    Uri? uri;
    try {
      uri = Uri.parse(raw.trim());
    } catch (_) {
      return const DeepLink(DeepLinkKind.unknown, '');
    }

    // Сегментҳои роҳ; барои `raonson://profile/ali` host худи «profile» аст.
    final segments = <String>[
      if (uri.scheme == scheme && uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ].where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) return const DeepLink(DeepLinkKind.unknown, '');

    // Префикси веб (`Raonson-v1`, `l`) партофта мешавад, то ҳарду
    // шакли линк ба як натиҷа расанд.
    //
    // Ба ғайр аз номҳои пурра, шаклҳои кӯтоҳи саҳифаи пешнамоиш
    // (`/p/<id>`, `/r/<id>`) низ фаҳмида мешаванд — маҳз онҳо ба
    // мессенҷерҳо фиристода мешаванд.
    final known = {..._paths.values, ..._previewPaths.values};
    var i = 0;
    while (i < segments.length && !known.contains(segments[i].toLowerCase())) {
      i++;
    }
    if (i >= segments.length) return const DeepLink(DeepLinkKind.unknown, '');

    final name = segments[i].toLowerCase();
    final id = i + 1 < segments.length
        ? Uri.decodeComponent(segments[i + 1])
        : '';

    var kind = _paths.entries
        .firstWhere((e) => e.value == name,
            orElse: () => const MapEntry(DeepLinkKind.unknown, ''))
        .key;
    if (kind == DeepLinkKind.unknown) {
      kind = _previewPaths.entries
          .firstWhere((e) => e.value == name,
              orElse: () => const MapEntry(DeepLinkKind.unknown, ''))
          .key;
    }

    if (id.isEmpty) return const DeepLink(DeepLinkKind.unknown, '');
    return DeepLink(kind, id);
  }

  /// Роҳи дохилии барнома барои onGenerateRoute.
  ///
  /// Номҳо ҳамонанд, ки дар app_routes.dart ҳастанд — ҳеҷ роҳи нав
  /// ихтироъ намешавад.
  static String? routeFor(DeepLink link) {
    if (!link.isValid) return null;
    switch (link.kind) {
      case DeepLinkKind.profile:
        return '/profile-by-username';
      case DeepLinkKind.post:
        return '/post';
      case DeepLinkKind.reel:
        return '/reel';
      case DeepLinkKind.topic:
        return '/topic';
      case DeepLinkKind.referral:
      case DeepLinkKind.unknown:
        return null;
    }
  }
}
