// lib/core/ads/ad_slot_layout.dart
// ════════════════════════════════════════════════════════════════════
//  Ҷойҳои реклама дар рӯйхат — мисли Instagram.
//
//  Реклама ҳамчун як унсури оддии рӯйхат меояд (пост ё саҳифаи
//  Reels), ки корбар онро фавран гузашта метавонад. Ҳеҷ равзанаи
//  болопӯш, ҳеҷ ҳисобкунаки баръакс, ҳеҷ «X»-и маҷбурӣ.
//
//  Лента: баъди `first` пост, баъд ҳар `every` пост.
//
//      p0 p1 p2 p3 [AD0] p4 … p11 [AD1] p12 …
//
//  Ҳисоб дар як ҷост ва тест мешавад: хатои классикӣ — пост дар
//  зери карти реклама гум мешавад.
// ════════════════════════════════════════════════════════════════════

class AdSlotLayout {
  /// Пеш аз рекламаи аввал чанд унсур.
  final int first;

  /// Баъд байни рекламаҳо чанд унсур.
  final int every;

  /// false — реклама нест (VIP): индексҳо бетағйир.
  final bool enabled;

  const AdSlotLayout({
    required this.first,
    required this.every,
    this.enabled = true,
  })  : assert(first >= 1),
        assert(every >= 1);

  AdSlotLayout copyWith({bool? enabled}) =>
      AdSlotLayout(first: first, every: every, enabled: enabled ?? this.enabled);

  int get _stride => every + 1;

  /// Оё дар ин ҷой реклама аст.
  bool isAdAt(int index) =>
      enabled && index >= first && (index - first) % _stride == 0;

  /// Рақами ҷойи реклама (0, 1, 2 …) — барои «як бор бор кардан
  /// дар ҳар ҷой» ва интихоби рекламаи дохилӣ.
  int slotAt(int index) => (index - first) ~/ _stride;

  /// Чанд реклама ПЕШ аз ин ҷой аст.
  int adsBefore(int index) {
    if (!enabled || index <= first) return 0;
    return (index - first - 1) ~/ _stride + 1;
  }

  /// Индекси унсур (пост) дар ин ҷой.
  int itemIndexAt(int index) => index - adsBefore(index);

  /// Шумораи рекламаҳо барои `items` унсур. Реклама танҳо байни
  /// унсурҳо меояд — ҳеҷ гоҳ дар охири холии рӯйхат.
  int adCountFor(int items) {
    if (!enabled || items <= first) return 0;
    return (items - 1 - first) ~/ every + 1;
  }

  /// Шумораи умумии ҷойҳо: унсурҳо + рекламаҳо.
  int totalFor(int items) => items + adCountFor(items);
}

/// Лента: баъди пости 4-ум, баъд ҳар 8 пост.
const kFeedAdLayout = AdSlotLayout(first: 4, every: 8);

/// Reels: баъди 4 видео, баъд ҳар 7 видео.
const kReelsAdFirst = 4;
const kReelsAdEvery = 7;

/// Ҷойҳои реклама дар Reels.
///
/// Лента пешакӣ ҳисоб мешавад, вале Reels не: дар Reels саҳифаи
/// холӣ бад аст, пас реклама ТАНҲО вақте илова мешавад, ки манбаъ
/// дастрас бошад. Ва танҳо ПЕШ аз саҳифаи ҷорӣ (на камтар аз +2):
/// саҳифаи ҷорӣ ва навбатии аллакай сохташуда ҳеҷ гоҳ ҷой иваз
/// намекунанд — вагарна видео зери ангушт иваз мешуд.
class ReelsAdPlan {
  final int first;
  final int every;
  ReelsAdPlan({this.first = kReelsAdFirst, this.every = kReelsAdEvery});

  final List<int> _positions = [];

  /// Ҷойҳои рекламаи аллакай гузошташуда (барои тест).
  List<int> get positions => List.unmodifiable(_positions);

  void reset() => _positions.clear();

  bool isAdAt(int page) => _positions.contains(page);

  /// Рақами ҷойи реклама.
  int slotAt(int page) => _positions.indexOf(page);

  int adsBefore(int page) => _positions.where((p) => p < page).length;

  /// Индекси видео дар ин саҳифа. Барои саҳифаи реклама — видеои
  /// навбатӣ (барои preload).
  int reelIndexAt(int page) => page - adsBefore(page);

  /// Шумораи саҳифаҳо барои `reels` видео.
  int pageCount(int reels) {
    var ads = 0;
    for (var k = 0; k < _positions.length; k++) {
      // Реклама танҳо агар баъди он ҳадди ақал як видео бошад.
      if (_positions[k] - k < reels) ads++;
    }
    return reels + ads;
  }

  /// Рекламаи навбатиро пешакӣ мегузорад, агар вақташ расида бошад.
  ///
  /// `available` — оё ҳоло манбаъ ҳаст (VIP нест, реклама ҳаст).
  /// Бармегардонад true, агар ҷой илова шуд.
  bool planAhead({required int currentPage, required bool available}) {
    if (!available) return false;
    final ads = _positions.length;
    final reelsBefore = ads == 0
        ? first
        : (_positions.last - (ads - 1)) + every;
    var pos = reelsBefore + ads;
    // Ҳеҷ гоҳ дар ҷойи ҷорӣ ё навбатӣ — онҳо аллакай дар экрананд.
    final minPos = currentPage + 2;
    if (pos > currentPage + every + 1) return false; // ҳанӯз барвақт
    if (pos < minPos) pos = minPos;
    if (_positions.isNotEmpty && pos <= _positions.last) return false;
    _positions.add(pos);
    return true;
  }
}
