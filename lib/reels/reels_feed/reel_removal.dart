/// Хориҷ кардани reel аз лента («Ба ман шавқовар нест»).
///
/// ⚠️ Сабаби «гуфт пинҳон шуд, вале ҳамон видео бозӣ мекунад»:
/// плеерҳои пешакӣ боршуда бо ИНДЕКСИ reel нигоҳ дошта мешуданд. Вақте
/// reel-и i аз рӯйхат мебаромад, reel-и навбатӣ ба ҷои i меомад ва
/// плеери ҳамон i-ро — яъне видеои ПИНҲОНШУДА-ро — мегирифт.
///
/// [shiftAfterRemoval] калидҳоро баъд аз [removed] як қадам ба паст
/// мекашад ва плеери reel-и хориҷшударо бармегардонад (барои dispose).
T? shiftAfterRemoval<T>(Map<int, T> byIndex, int removed) {
  final gone = byIndex.remove(removed);
  final later = byIndex.keys.where((k) => k > removed).toList()..sort();
  for (final k in later) {
    byIndex[k - 1] = byIndex.remove(k) as T;
  }
  return gone;
}

/// Рӯйхати нав бе id-ҳои пинҳоншуда — барои саҳифаҳои навбатӣ ва кэш,
/// то reel-и пинҳоншуда бо `loadMore` ё навсозии фонӣ барнагардад.
List<T> withoutHidden<T>(
        Iterable<T> items, Set<String> hidden, String Function(T) idOf) =>
    hidden.isEmpty
        ? items.toList()
        : items.where((e) => !hidden.contains(idOf(e))).toList();
