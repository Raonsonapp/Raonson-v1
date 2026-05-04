// lib/profile/highlight_model.dart
class HighlightModel {
  final String id;
  final String title;
  final String coverUrl;
  final List<String> storyIds;

  const HighlightModel({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.storyIds = const [],
  });

  factory HighlightModel.fromJson(Map<String, dynamic> j) => HighlightModel(
    id:       (j['_id'] ?? j['id'] ?? '').toString(),
    title:    j['title']?.toString()    ?? '',
    coverUrl: j['coverUrl']?.toString() ?? '',
    storyIds: (j['storyIds'] as List? ?? []).map((e)=>e.toString()).toList(),
  );
}
