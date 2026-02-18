class ReelModel {
  final String id;
  final String videoUrl;
  final String caption;

  const ReelModel({
    required this.id,
    required this.videoUrl,
    required this.caption,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['_id'],
      videoUrl: json['videoUrl'] ?? '',
      caption: json['caption'] ?? '',
    );
  }
}
