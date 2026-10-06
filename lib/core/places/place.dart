/// Як ҷой барои «Ҷой»-и пост.
///
/// [id] — id аз рӯйхати сервер (/places); холӣ — ҷойи дастӣ, ки корбар
/// худаш навишт («Илова кардани «…»»).
class Place {
  final String id;
  final String name;
  final String region;
  final String kind; // country | region | city | district | town | poi | custom
  final double? lat;
  final double? lon;
  final double? distanceKm;

  const Place({
    required this.id,
    required this.name,
    this.region = '',
    this.kind = 'custom',
    this.lat,
    this.lon,
    this.distanceKm,
  });

  /// Ҷойи дастӣ (берун аз рӯйхат).
  factory Place.custom(String name) => Place(id: '', name: name.trim());

  bool get isCustom => id.isEmpty;

  static double? _d(Object? v) => v is num ? v.toDouble() : null;

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        region: (j['region'] ?? '').toString(),
        kind: (j['kind'] ?? 'custom').toString(),
        lat: _d(j['lat']),
        lon: _d(j['lon']),
        distanceKm: _d(j['distanceKm']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'region': region,
        'kind': kind,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
      };

  @override
  bool operator ==(Object other) =>
      other is Place && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Place($id, $name)';
}

/// Натиҷаи «Ҷойи ҳозираи ман».
class NearestResult {
  /// Ҷое, ки корбар дар он аст (null — дар наздикӣ ҷойи маълум нест).
  final Place? place;
  final List<Place> nearby;
  const NearestResult({this.place, this.nearby = const []});
}
