/// Typed JSON helpers to satisfy strict-casts.
/// Usage: `json.asString('name')` instead of `json['name'] ?? ''`
extension TypedJson on Map<String, dynamic> {
  String asString(String key, [String defaultValue = '']) {
    final v = this[key];
    if (v is String) return v;
    if (v != null) return v.toString();
    return defaultValue;
  }

  int asInt(String key, [int defaultValue = 0]) {
    final v = this[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? defaultValue;
    return defaultValue;
  }

  double asDouble(String key, [double defaultValue = 0]) {
    final v = this[key];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? defaultValue;
    return defaultValue;
  }

  bool asBool(String key, [bool defaultValue = false]) {
    final v = this[key];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return defaultValue;
  }

  Map<String, dynamic> asMap(String key) {
    final v = this[key];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<dynamic> asList(String key) =>
      (this[key] as List<dynamic>?) ?? <dynamic>[];

  List<String> asStringList(String key) {
    final raw = this[key];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return <String>[];
  }

  /// Extract a list of URL strings from a field that may contain:
  ///  - plain strings:  ["https://...", "/uploads/..."]
  ///  - objects with url key: [{"url": "/uploads/...", ...}]
  ///  - mixed
  List<String> asUrlList(String key) {
    final raw = this[key];
    if (raw is! List) return <String>[];
    return raw
        .map<String?>((e) {
          if (e is String) return e;
          if (e is Map) return (e['url'] ?? e['secure_url'] ?? e['path'])?.toString();
          return null;
        })
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
  }

  DateTime asDateTime(String key) =>
      DateTime.tryParse((this[key] as String?) ?? '')?.toLocal() ??
      DateTime.now();

  DateTime? asDateTimeOrNull(String key) =>
      DateTime.tryParse((this[key] as String?) ?? '')?.toLocal();

  String? asStringOrNull(String key) {
    final v = this[key];
    if (v is String) return v;
    if (v != null) return v.toString();
    return null;
  }

  int? asIntOrNull(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    return null;
  }

  Map<String, dynamic>? asMapOrNull(String key) {
    final v = this[key];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  List<dynamic>? asListOrNull(String key) {
    final v = this[key];
    return v is List ? v : null;
  }
}
