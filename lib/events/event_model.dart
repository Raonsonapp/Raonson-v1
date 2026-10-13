// lib/events/event_model.dart
// «Даъватнома» — модел ва дархостҳо. Сервер: backend/handlers/events.go.
import '../core/links/deep_links.dart';
import '../core/ui/feature_kit.dart';
import '../core/utils/server_time.dart';

class EventModel {
  final String id, title, kind, description, coverUrl;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String placeName, placeId;
  final bool isPublic, cancelled, isHost, isOwner, invited;
  final bool albumOpen, canUpload, canRsvp, pendingReview;
  final String status; // upcoming | live | past | cancelled
  final String myRsvp; // pending | going | maybe | declined
  final int myPlus, maxPlus;
  final int going, maybe, declined, pendingCount, guests;
  final MiniUser? host;
  final List<MiniUser> cohosts;
  final String shareCode;

  const EventModel({
    required this.id,
    required this.title,
    this.kind = 'other',
    this.description = '',
    this.coverUrl = '',
    required this.startsAt,
    this.endsAt,
    this.placeName = '',
    this.placeId = '',
    this.isPublic = false,
    this.cancelled = false,
    this.isHost = false,
    this.isOwner = false,
    this.invited = false,
    this.albumOpen = false,
    this.canUpload = false,
    this.canRsvp = false,
    this.pendingReview = false,
    this.status = 'upcoming',
    this.myRsvp = 'pending',
    this.myPlus = 0,
    this.maxPlus = 3,
    this.going = 0,
    this.maybe = 0,
    this.declined = 0,
    this.pendingCount = 0,
    this.guests = 0,
    this.host,
    this.cohosts = const [],
    this.shareCode = '',
  });

  factory EventModel.fromJson(Map<String, dynamic> j) {
    final c = (j['counts'] as Map?) ?? const {};
    final p = (j['place'] as Map?) ?? const {};
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return EventModel(
      id: (j['_id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      kind: (j['kind'] ?? 'other').toString(),
      description: (j['description'] ?? '').toString(),
      coverUrl: (j['coverUrl'] ?? '').toString(),
      startsAt: parseServerTime(j['startsAt']) ?? DateTime.now(),
      endsAt: parseServerTime(j['endsAt']),
      placeName: (p['name'] ?? '').toString(),
      placeId: (p['id'] ?? '').toString(),
      isPublic: j['isPublic'] == true,
      cancelled: j['cancelled'] == true,
      isHost: j['isHost'] == true,
      isOwner: j['isOwner'] == true,
      invited: j['invited'] == true,
      albumOpen: j['albumOpen'] == true,
      canUpload: j['canUpload'] == true,
      canRsvp: j['canRsvp'] == true,
      pendingReview: j['pendingReview'] == true,
      status: (j['status'] ?? 'upcoming').toString(),
      myRsvp: (j['myRsvp'] ?? 'pending').toString(),
      myPlus: n(j['myPlus']),
      maxPlus: n(j['maxPlus']),
      going: n(c['going']),
      maybe: n(c['maybe']),
      declined: n(c['declined']),
      pendingCount: n(c['pending']),
      guests: n(c['guests']),
      host: MiniUser.fromJson(j['host']),
      cohosts: ((j['cohosts'] as List?) ?? const [])
          .map(MiniUser.fromJson)
          .whereType<MiniUser>()
          .toList(),
      shareCode: (j['shareCode'] ?? '').toString(),
    );
  }

  /// Линки даъват: `raonson://event/<id>[/<code>]` ва линки веб.
  String get appLink =>
      DeepLinks.appLink(DeepLinkKind.event, id, extra: shareCode);
  String get webLink =>
      DeepLinks.share(DeepLinkKind.event, id, extra: shareCode);
}

class EventPhoto {
  final String id, url;
  final MiniUser? user;
  final bool canDelete, pendingReview;
  const EventPhoto(this.id, this.url, this.user, this.canDelete, this.pendingReview);
  factory EventPhoto.fromJson(Map<String, dynamic> j) => EventPhoto(
      (j['_id'] ?? '').toString(),
      (j['url'] ?? '').toString(),
      MiniUser.fromJson(j['user']),
      j['canDelete'] == true,
      j['pendingReview'] == true);
}

class EventGuest {
  final MiniUser user;
  final String rsvp;
  final int plus;
  const EventGuest(this.user, this.rsvp, this.plus);
}

class EventsRepository {
  EventsRepository._();
  static final EventsRepository instance = EventsRepository._();

  Future<List<EventModel>> list(String tab) async {
    final r = await apiJson('GET', '/events', query: {'tab': tab});
    return ((r['events'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => EventModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<EventModel> get(String id, {String code = ''}) async {
    final r = await apiJson('GET', '/events/$id',
        query: code.isEmpty ? null : {'code': code});
    return EventModel.fromJson((r as Map).cast<String, dynamic>());
  }

  Future<EventModel> create(Map<String, dynamic> body) async =>
      EventModel.fromJson(
          ((await apiJson('POST', '/events', body: body)) as Map)
              .cast<String, dynamic>());

  Future<EventModel> rsvp(String id, String status, int plus) async =>
      EventModel.fromJson(((await apiJson('POST', '/events/$id/rsvp',
              body: {'status': status, 'plus': plus})) as Map)
          .cast<String, dynamic>());

  Future<int> invite(String id, List<String> userIds) async {
    final r = await apiJson('POST', '/events/$id/invite',
        body: {'userIds': userIds});
    return (r['invited'] as num?)?.toInt() ?? 0;
  }

  Future<void> cancel(String id) => apiJson('DELETE', '/events/$id');

  Future<List<EventGuest>> guests(String id) async {
    final r = await apiJson('GET', '/events/$id/guests');
    return ((r['guests'] as List?) ?? const [])
        .whereType<Map>()
        .map((g) {
          final u = MiniUser.fromJson(g['user']);
          return u == null
              ? null
              : EventGuest(u, (g['rsvp'] ?? '').toString(),
                  (g['plus'] as num?)?.toInt() ?? 0);
        })
        .whereType<EventGuest>()
        .toList();
  }

  Future<List<EventPhoto>> photos(String id) async {
    final r = await apiJson('GET', '/events/$id/photos');
    return ((r['photos'] as List?) ?? const [])
        .whereType<Map>()
        .map((p) => EventPhoto.fromJson(p.cast<String, dynamic>()))
        .toList();
  }

  Future<void> addPhoto(String id, String url) =>
      apiJson('POST', '/events/$id/photos', body: {'url': url});

  Future<void> deletePhoto(String id, String photoId) =>
      apiJson('DELETE', '/events/$id/photos/$photoId');
}
