import '../core/content_sync.dart';
import '../core/utils/server_time.dart';
import '../core/music/song_info.dart';
import '../stories/story_seen_sync.dart';
import 'user_model.dart';

class PostModel {
  final String id;
  final UserModel user;
  final String caption;
  final List<Map<String, String>> media;
  final int  likesCount;
  final int  commentsCount;
  final bool liked;
  final bool saved;
  final bool isPinned;
  final DateTime createdAt;
  final String       location;
  /// id-и ҷой аз рӯйхати /places ('' — ҷойи дастӣ ё пости кӯҳна).
  final String       locationId;
  final List<String> taggedUsers;
  final List<String> collaborators;
  /// Ҳамкорони тасдиқкарда: {_id, username, avatar}. `collaborators`
  /// танҳо шиноса аст — пеш ҳамон шиноса ҳамчун ном нишон дода мешуд.
  final List<Map<String, String>> collaboratorUsers;
  final String       musicTitle;   // ✅ НАВ
  final String       musicArtist;  // ✅ НАВ

  /// Суруди пурра — бо суроға ва ҷои оғоз.
  ///
  /// `musicTitle`/`musicArtist` боқӣ мемонанд, чунки серверҳои
  /// кӯҳна танҳо ҳамонҳоро бармегардонанд.
  final SongInfo     song;

  /// Чанд нафар ин постро паҳн карданд.
  ///
  /// Reel ин майдонро дошт, пост НЕ — пас дар назди тугмаи «паҳн
  /// кардан» ҳеҷ рақам набуд.
  final int          sharesCount;

  /// Тамошоҳо — ҲАМОН рақам дар Explore, профил, пост ва омори соҳиб
  /// (сервер: COUNT(post_views); калидҳо `viewsCount` ва `views`).
  final int          viewsCount;
  final bool         hideLikes;        // лайкҳо пинҳонанд (танҳо соҳиб мебинад)
  final bool         commentsDisabled; // шарҳҳо хомӯшанд
  // ── Магоза (пости маҳсулот) ──
  final bool         isProduct;
  final double       price;
  final String       currency;
  final String       productName;
  final bool         contactRaonson;
  final String       shopWhatsapp;
  final String       shopPhone;
  /// Тахфифи фаъол (Flash Sale), 0–90. Сервер фармоишро бо нархи
  /// тахфифӣ сабт мекунад — «Харид» бояд ҳамонро нишон диҳад.
  final int          salePct;

  /// Кай ин маълумот аз сервер гирифта шуд. ContentSync бо ин мефаҳмад,
  /// ки рӯйхати куҳна амали навтари корбарро пахш накунад.
  final DateTime?    fetchedAt;

  const PostModel({
    required this.id,
    required this.user,
    required this.caption,
    required this.media,
    required this.likesCount,
    required this.commentsCount,
    required this.liked,
    required this.saved,
    required this.createdAt,
    this.isPinned    = false,
    this.location    = '',
    this.locationId  = '',
    this.taggedUsers = const [],
    this.collaborators = const [],
    this.collaboratorUsers = const [],
    this.musicTitle  = '',
    this.musicArtist = '',
    this.song        = SongInfo.none,
    this.sharesCount = 0,
    this.viewsCount  = 0,
    this.hideLikes        = false,
    this.commentsDisabled = false,
    this.isProduct      = false,
    this.price          = 0,
    this.currency       = 'TJS',
    this.productName    = '',
    this.contactRaonson = true,
    this.shopWhatsapp   = '',
    this.shopPhone      = '',
    this.salePct        = 0,
    this.fetchedAt,
  });

  String get priceLabel =>
      '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} $currency';

  bool   get onSale    => salePct > 0;
  /// Нархе, ки харидор воқеан пардохт мекунад (бо тахфифи фаъол).
  double get salePrice => price * (1 - salePct / 100);
  String get salePriceLabel =>
      '${salePrice.toStringAsFixed(salePrice % 1 == 0 ? 0 : 2)} $currency';

  bool get isLiked  => liked;
  bool get isSaved  => saved;
  bool get isOwner  => false;
  List get comments => const [];

  /// Ҳолати лайк/шарҳ/... -и ҳамин модел — барои ContentSync.view.
  ContentState get syncState => ContentState(
        liked: liked, likesCount: likesCount, saved: saved,
        commentsCount: commentsCount, sharesCount: sharesCount,
        hideLikes: hideLikes, commentsOff: commentsDisabled);

  /// Маълумоти серверии ин постро ба ContentSync медиҳад. Рӯйхати
  /// куҳна амали навтари корбарро пахш намекунад (ниг. ContentSync).
  void primeSync() {
    ContentSync.instance.prime(id,
        liked: liked, likesCount: likesCount, saved: saved,
        commentsCount: commentsCount, sharesCount: sharesCount,
        hideLikes: hideLikes, commentsOff: commentsDisabled,
        caption: caption, fetchedAt: fetchedAt);
    // Ҳалқаи сториси муаллиф — ҳамон манбаъ барои ҳамаи экранҳо.
    StorySeenSync.instance.primeUser(user, fetchedAt: fetchedAt);
  }

  String get mediaUrl  => media.isNotEmpty ? media.first['url']  ?? '' : '';
  String get mediaType => media.isNotEmpty ? media.first['type'] ?? 'image' : 'image';

  PostModel copyWith({
    String? id, UserModel? user, String? caption,
    List<Map<String, String>>? media,
    int? likesCount, int? commentsCount,
    bool? liked, bool? saved, bool? isPinned,
    DateTime? createdAt, String? location, String? locationId,
    List<String>? taggedUsers,
    List<String>? collaborators,
    List<Map<String, String>>? collaboratorUsers,
    String? musicTitle, String? musicArtist, SongInfo? song,
    int? sharesCount, int? viewsCount,
    bool? hideLikes, bool? commentsDisabled,
    bool? isProduct, double? price, String? currency, String? productName,
    bool? contactRaonson, String? shopWhatsapp, String? shopPhone,
    int? salePct,
    DateTime? fetchedAt,
  }) => PostModel(
    id:            id            ?? this.id,
    user:          user          ?? this.user,
    caption:       caption       ?? this.caption,
    media:         media         ?? this.media,
    likesCount:    likesCount    ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    liked:         liked         ?? this.liked,
    saved:         saved         ?? this.saved,
    isPinned:      isPinned      ?? this.isPinned,
    createdAt:     createdAt     ?? this.createdAt,
    location:      location      ?? this.location,
    locationId:    locationId    ?? this.locationId,
    taggedUsers:   taggedUsers   ?? this.taggedUsers,
    collaborators: collaborators ?? this.collaborators,
    collaboratorUsers: collaboratorUsers ?? this.collaboratorUsers,
    musicTitle:    musicTitle    ?? this.musicTitle,
    musicArtist:   musicArtist   ?? this.musicArtist,
    song:          song          ?? this.song,
    sharesCount:   sharesCount   ?? this.sharesCount,
    viewsCount:    viewsCount    ?? this.viewsCount,
    hideLikes:        hideLikes        ?? this.hideLikes,
    commentsDisabled: commentsDisabled ?? this.commentsDisabled,
    isProduct:      isProduct      ?? this.isProduct,
    price:          price          ?? this.price,
    currency:       currency       ?? this.currency,
    productName:    productName    ?? this.productName,
    contactRaonson: contactRaonson ?? this.contactRaonson,
    shopWhatsapp:   shopWhatsapp   ?? this.shopWhatsapp,
    shopPhone:      shopPhone      ?? this.shopPhone,
    salePct:        salePct        ?? this.salePct,
    fetchedAt:      fetchedAt      ?? this.fetchedAt,
  );

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final rawMedia = (json['media'] ?? []) as List;
    final media = rawMedia.map((m) {
      final map = m as Map;
      return <String, String>{
        'url':  (map['url']  ?? '').toString(),
        'type': (map['type'] ?? 'image').toString(),
        if ((map['aspectRatio'] ?? '').toString().isNotEmpty)
          'aspectRatio': map['aspectRatio'].toString(),
        // Тавсифи расм барои нобиноён (Alt text).
        if ((map['alt'] ?? '').toString().isNotEmpty)
          'alt': map['alt'].toString(),
      };
    }).toList();

    const empty = UserModel(id:'',username:'',avatar:'',verified:false,
        isPrivate:false,postsCount:0,followersCount:0,followingCount:0);

    // Сервер вақте лайкҳо пинҳонанд ва бинанда соҳиб нест → likesCount = -1.
    final rawLikes = (json['likesCount'] as num?)?.toInt() ?? 0;
    final likesHidden = (json['hideLikes'] == true) || rawLikes < 0;

    return PostModel(
      id:            (json['_id'] ?? json['id'] ?? '').toString(),
      user:          json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String,dynamic>) : empty,
      caption:       (json['caption']  ?? '').toString(),
      media:         media,
      likesCount:    rawLikes < 0 ? 0 : rawLikes,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      liked:         json['liked'] == true,
      saved:         json['saved'] == true,
      isPinned:      json['isPinned'] == true,
      createdAt:     parseServerTime(json['createdAt']) ?? DateTime.now(),
      location:      (json['location']    ?? '').toString(),
      locationId:    (json['locationId']  ?? '').toString(),
      taggedUsers:   (json['taggedUsers'] as List? ?? []).map((e)=>e.toString()).toList(),
      collaborators: (json['collaborators'] as List? ?? []).map((e)=>e.toString()).toList(),
      collaboratorUsers: (json['collaboratorUsers'] as List? ?? [])
          .whereType<Map>()
          .map((u) => <String, String>{
                '_id': (u['_id'] ?? u['id'] ?? '').toString(),
                'username': (u['username'] ?? '').toString(),
                'avatar': (u['avatar'] ?? '').toString(),
              })
          .where((u) => u['username']!.isNotEmpty)
          .toList(),
      musicTitle:    (json['musicTitle']  ?? json['music']?['title'] ?? '').toString(),
      musicArtist:   (json['musicArtist'] ?? json['music']?['artist'] ?? '').toString(),
      sharesCount:   (json['sharesCount'] as num?)?.toInt() ?? 0,
      viewsCount:    (json['viewsCount'] as num?)?.toInt()
          ?? (json['views'] as num?)?.toInt() ?? 0,
      // Сервери кӯҳна `song` намедиҳад — он гоҳ ном ва хонандаи
      // ҷудогона истифода мешаванд, танҳо бе садо.
      song: json['song'] != null
          ? SongInfo.fromJson(json['song'] as Map<String, dynamic>?)
          : SongInfo(
              title:  (json['musicTitle']  ?? '').toString(),
              artist: (json['musicArtist'] ?? '').toString(),
              artUrl: ''),
      hideLikes:        likesHidden,
      commentsDisabled: json['commentsOff'] == true
          || json['commentsDisabled'] == true,
      isProduct:      json['isProduct'] == true,
      price:          (json['price'] as num?)?.toDouble() ?? 0,
      currency:       (json['currency'] ?? 'TJS').toString(),
      productName:    (json['productName'] ?? '').toString(),
      contactRaonson: json['contactRaonson'] != false,
      shopWhatsapp:   (json['shopWhatsapp'] ?? '').toString(),
      shopPhone:      (json['shopPhone'] ?? '').toString(),
      salePct:        ((json['salePct'] as num?)?.toInt() ?? 0).clamp(0, 90),
      // Кэши диск вақти аслиро нигоҳ медорад; ҷавоби нав — ҳозир.
      fetchedAt:      ContentSync.fetchedAtOf(json) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id, 'caption': caption, 'media': media,
    'likesCount': likesCount, 'commentsCount': commentsCount,
    'liked': liked, 'saved': saved, 'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
    'location': location, 'locationId': locationId,
    'taggedUsers': taggedUsers,
    'collaborators': collaborators,
    'collaboratorUsers': collaboratorUsers,
    // Бе инҳо кэши диск пинҳонии лайкҳо / хомӯшии шарҳҳоро гум мекард.
    'sharesCount': sharesCount,
    'viewsCount': viewsCount,
    'hideLikes': hideLikes,
    'commentsOff': commentsDisabled,
    // ⚠️ Инҳо НАБУДАНД: лента аз кэши диск бор мешуд ва пост бе музика
    // (ва бе маълумоти маҳсулот) нишон дода мешуд.
    'musicTitle': musicTitle, 'musicArtist': musicArtist,
    if (song.isNotEmpty) 'song': song.toJson(),
    'isProduct': isProduct, 'price': price, 'currency': currency,
    'productName': productName, 'contactRaonson': contactRaonson,
    'shopWhatsapp': shopWhatsapp, 'shopPhone': shopPhone,
    'salePct': salePct,
    if (fetchedAt != null)
      ContentSync.fetchedAtKey: fetchedAt!.millisecondsSinceEpoch,
    'user': {'_id':user.id,'username':user.username,'avatar':user.avatar,
      'verified':user.verified,'isPrivate':user.isPrivate,
      'postsCount':user.postsCount,'followersCount':user.followersCount,
      'followingCount':user.followingCount,
      ...user.storyRingJson,'isFollowing':user.isFollowing},
  };
}
