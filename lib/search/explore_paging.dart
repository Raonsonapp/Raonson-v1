import 'dart:math';

/// Саҳифабандии Explore (GET /explore?page=&seed=).
///
/// Пеш барнома ҳамеша танҳо /explore-ро мегирифт (сервер `page`-ро
/// нодида мегирифт) ва онро омехта мекард: лента баъди ~60 плитка
/// тамом мешуд ва «аз нав кашидан» ҳамон чизро бо тартиби дигар медод.
///
/// Акнун: як [seed] барои ҷаласа (тартиб дар сервер устувор аст,
/// саҳифаҳо такрор надоранд), саҳифаҳо бо ғелондан бор мешаванд ва
/// id-ҳои дидашуда дубора илова намешаванд.
class ExplorePager {
  ExplorePager({Random? random}) : _random = random ?? Random();

  final Random _random;
  String seed = '';
  int page = 0;
  bool hasMore = true;
  bool loading = false;
  final Set<String> _seen = <String>{};

  /// Ҷаласаи нав (кушодан ё «аз нав кашидан»): seed-и нав, саҳифаи 1.
  void reset() {
    seed = _newSeed();
    page = 0;
    hasMore = true;
    loading = false;
    _seen.clear();
  }

  String _newSeed() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(12, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  Map<String, String> queryFor(int page) => {'page': '$page', 'seed': seed};

  /// Танҳо унсурҳои ҳанӯз нодида (бо id). [ids] худашон низ дар
  /// дохили як саҳифа такрор намешаванд.
  List<T> fresh<T>(Iterable<T> items, String Function(T) idOf) {
    final out = <T>[];
    for (final e in items) {
      final id = idOf(e);
      if (id.isEmpty || _seen.add(id)) out.add(e);
    }
    return out;
  }

  /// Рӯйхати намоён иваз шуд (кэш → шабака): «дидашуда» маҳз ҳамин аст.
  void replaceSeen(Iterable<String> ids) {
    _seen
      ..clear()
      ..addAll(ids);
  }
}

/// Reels-ро дар ҷойҳои баланди гриди quilted мегузорад (ҳар [every]-ум
/// плитка, аз [startIndex]-и умумӣ ҳисоб), постҳо — дар боқимонда.
///
/// Пеш ҳама чиз тасодуфӣ омехта мешуд ва reel метавонист дар ҳуҷайраи
/// хурди мураббаъ афтад.
List<T> interleaveExplore<T>(int startIndex, List<T> posts, List<T> reels,
    {int every = 4}) {
  final out = <T>[];
  var p = 0, r = 0;
  var i = startIndex;
  while (p < posts.length || r < reels.length) {
    final tall = i % every == 0;
    if ((tall && r < reels.length) || p >= posts.length) {
      out.add(reels[r++]);
    } else {
      out.add(posts[p++]);
    }
    i++;
  }
  return out;
}
