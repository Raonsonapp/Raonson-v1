// lib/profile/highlight_model.dart
class HighlightItem {
  final String url;
  final String type; // "image" | "video"
  const HighlightItem({required this.url, this.type = 'image'});

  factory HighlightItem.fromJson(Map<String, dynamic> j) => HighlightItem(
        url:  (j['url'] ?? '').toString(),
        type: (j['type'] ?? 'image').toString(),
      );

  Map<String, dynamic> toJson() => {'url': url, 'type': type};
}

class HighlightModel {
  final String id;
  final String title;
  final String coverUrl;
  final List<String> storyIds;
  final List<HighlightItem> items;

  const HighlightModel({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.storyIds = const [],
    this.items = const [],
  });

  HighlightModel copyWith({String? title, String? coverUrl, List<HighlightItem>? items}) =>
      HighlightModel(
        id:       id,
        title:    title    ?? this.title,
        coverUrl: coverUrl ?? this.coverUrl,
        storyIds: storyIds,
        items:    items    ?? this.items,
      );

  factory HighlightModel.fromJson(Map<String, dynamic> j) => HighlightModel(
    id:       (j['_id'] ?? j['id'] ?? '').toString(),
    title:    j['title']?.toString()    ?? '',
    coverUrl: j['coverUrl']?.toString() ?? '',
    storyIds: (j['storyIds'] as List? ?? []).map((e)=>e.toString()).toList(),
    items:    (j['items'] as List? ?? [])
        .map((e) => HighlightItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
