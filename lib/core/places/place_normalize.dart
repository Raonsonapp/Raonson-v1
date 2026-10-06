// «Хуҷанд» = «Худжанд» = «Khujand» = «xujand».
//
// ⚠️ Нусхаи айнии Normalize дар backend/places/places.go — ҳар тағйир
// бояд дар ҳарду ҷо бошад (test/places_test.dart ва places_test.go
// ҳамон мисолҳоро месанҷанд). Сервер ҷустуҷӯи асосӣ аст; ин танҳо
// барои рӯйхати офлайн аст.

const Map<String, String> _runeMap = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'ғ': 'g', 'ґ': 'g', 'д': 'd',
  'е': 'e', 'ё': 'io', 'є': 'e', 'ж': 'j', 'з': 'z', 'и': 'i', 'ӣ': 'i',
  'і': 'i', 'ї': 'i', 'й': 'i', 'к': 'k', 'қ': 'k', 'л': 'l', 'м': 'm',
  'н': 'n', 'ң': 'n', 'о': 'o', 'ө': 'o', 'п': 'p', 'р': 'r', 'с': 's',
  'т': 't', 'у': 'u', 'ӯ': 'u', 'ў': 'u', 'ү': 'u', 'ф': 'f', 'х': 'h',
  'ҳ': 'h', 'һ': 'h', 'ц': 's', 'ч': 'ch', 'ҷ': 'j', 'ш': 'sh', 'щ': 'sh',
  'ъ': '', 'ы': 'i', 'ь': '', 'э': 'e', 'ә': 'a', 'ю': 'iu', 'я': 'ia',
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a', 'æ': 'ae', 'ç': 'ch', 'č': 'ch', 'ć': 'ch', 'ď': 'd',
  'đ': 'd', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e',
  'ę': 'e', 'ě': 'e', 'ğ': 'g', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ī': 'i', 'ı': 'i', 'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n', 'ò': 'o',
  'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ō': 'o', 'ő': 'o', 'ø': 'o',
  'ř': 'r', 'ś': 's', 'š': 'sh', 'ş': 'sh', 'ș': 'sh', 'ß': 'ss', 'ť': 't',
  'ţ': 't', 'ț': 't', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ŭ': 'u', 'ű': 'u', 'ů': 'u', 'ý': 'i', 'ÿ': 'i', 'ž': 'j', 'ź': 'z',
  'ż': 'z', '\u0307': '', // «İzmir»: нуқтаи иловагии toLowerCase
};

const List<List<String>> _pairRules = [
  ['kh', 'h'], ['zh', 'j'], ['dj', 'j'], ['gh', 'g'], ['ph', 'f'],
  ['ts', 's'], ['x', 'h'], ['q', 'k'], ['w', 'v'], ['y', 'i'],
];

const String _apostrophes = '\'’‘`ʼʻ';

/// Калиди ҷустуҷӯ барои номи ҷой.
String normalizePlace(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final m = _runeMap[ch];
    if (m != null) {
      b.write(m);
    } else if ((r >= 0x61 && r <= 0x7a) || (r >= 0x30 && r <= 0x39)) {
      b.write(ch);
    } else if (_apostrophes.contains(ch)) {
      // апостроф: «Mu'minobod» = «Мӯъминобод»
    } else {
      b.write(' ');
    }
  }
  var out = b.toString();
  for (final p in _pairRules) {
    out = out.replaceAll(p[0], p[1]);
  }
  // «c» бе «h» → «k».
  final cs = out.split('');
  for (var i = 0; i < cs.length; i++) {
    if (cs[i] == 'c' && (i + 1 >= cs.length || cs[i + 1] != 'h')) cs[i] = 'k';
  }
  final words = cs.join().split(' ').where((w) => w.isNotEmpty).map((w) {
    if (w.length > 1 && w[0] == 'i' && 'aeiou'.contains(w[1])) {
      w = w.substring(1);
    }
    final c = StringBuffer();
    for (var j = 0; j < w.length; j++) {
      if (j > 0 && w[j] == w[j - 1]) continue;
      c.write(w[j]);
    }
    return c.toString();
  });
  return words.join(' ');
}
