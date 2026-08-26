import 'user_model.dart';

/// Стикери пурсиш дар сторис (мисли Instagram).
class StoryPoll {
  final String question;
  final String optionA;
  final String optionB;
  final double x;        // ҷойгиршавӣ 0..1
  final double y;
  final int votesA;
  final int votesB;
  final int myVote;      // -1 = ҳанӯз овоз надодаам, 0 = A, 1 = B

  const StoryPoll({
    required this.question,
    required this.optionA,
    required this.optionB,
    this.x = 0.5, this.y = 0.5,
    this.votesA = 0, this.votesB = 0, this.myVote = -1,
  });

  int  get total   => votesA + votesB;
  bool get didVote => myVote >= 0;
  double get pctA  => total == 0 ? 0 : votesA / total;
  double get pctB  => total == 0 ? 0 : votesB / total;

  StoryPoll copyWith({int? votesA, int? votesB, int? myVote}) => StoryPoll(
    question: question, optionA: optionA, optionB: optionB, x: x, y: y,
    votesA: votesA ?? this.votesA,
    votesB: votesB ?? this.votesB,
    myVote: myVote ?? this.myVote,
  );

  static StoryPoll? fromJson(dynamic j) {
    if (j is! Map) return null;
    final q = (j['question'] ?? '').toString();
    if (q.isEmpty) return null;
    double d(dynamic v, double def) =>
        v is num ? v.toDouble() : def;
    int i(dynamic v, int def) => v is num ? v.toInt() : def;
    return StoryPoll(
      question: q,
      optionA: (j['optionA'] ?? 'Ҳа').toString(),
      optionB: (j['optionB'] ?? 'Не').toString(),
      x: d(j['x'], 0.5), y: d(j['y'], 0.5),
      votesA: i(j['votesA'], 0), votesB: i(j['votesB'], 0),
      myVote: i(j['myVote'], -1),
    );
  }
}

class StoryModel {
  final String id;
  final UserModel user;
  final String mediaUrl;
  final String mediaType;
  final bool viewed;
  final bool isLiked;
  final int likesCount;
  final int viewsCount;
  final bool repliesOff;
  final String audience;
  final DateTime expiresAt;
  final StoryPoll? poll;

  const StoryModel({
    required this.id,
    required this.user,
    required this.mediaUrl,
    required this.mediaType,
    required this.viewed,
    this.isLiked = false,
    this.likesCount = 0,
    this.viewsCount = 0,
    this.repliesOff = false,
    this.audience = 'all',
    required this.expiresAt,
    this.poll,
  });

  bool get isVideo => mediaType == 'video';
  bool get isImage => mediaType == 'image';
  String get userAvatar => user.avatar;
  String get username => user.username;

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final likes = json['likes'];
    final views = json['views'];
    return StoryModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : const UserModel(id:'',username:'',avatar:'',verified:false,
              isPrivate:false,postsCount:0,followersCount:0,followingCount:0),
      mediaUrl: json['mediaUrl'] ?? '',
      mediaType: json['mediaType'] ?? 'image',
      viewed: json['viewed'] ?? false,
      isLiked: json['isLiked'] ?? false,
      likesCount: likes is List ? likes.length : (json['likesCount'] ?? 0),
      viewsCount: views is List ? views.length : (json['viewsCount'] ?? 0),
      repliesOff: json['repliesOff'] == true,
      audience: (json['audience'] ?? 'all').toString(),
      expiresAt: DateTime.tryParse(json['expiresAt'] ?? '') ?? DateTime.now().add(const Duration(hours: 24)),
      poll: StoryPoll.fromJson(json['poll']),
    );
  }
}
