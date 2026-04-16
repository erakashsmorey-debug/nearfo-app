import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight API response cache using SharedPreferences.
/// Strategy: cache-first → show cached data instantly → refresh in background.
class CacheService {
  static SharedPreferences? _prefs;
  static const String _prefix = 'api_cache_';
  static const String _tsPrefix = 'api_cache_ts_';

  /// Initialize once at app start (call from main or splash)
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save a JSON-encodable response to cache.
  static Future<void> put(String key, dynamic data, {Duration maxAge = const Duration(minutes: 30)}) async {
    _prefs ??= await SharedPreferences.getInstance();
    try {
      final json = jsonEncode(data);
      await _prefs!.setString('$_prefix$key', json);
      await _prefs!.setInt('$_tsPrefix$key', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Silently fail — caching is best-effort
    }
  }

  /// Get cached data. Returns null if not cached or expired.
  static dynamic get(String key, {Duration maxAge = const Duration(minutes: 30)}) {
    if (_prefs == null) return null;
    try {
      final ts = _prefs!.getInt('$_tsPrefix$key');
      if (ts == null) return null;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age < 0 || age > maxAge.inMilliseconds) return null;
      final json = _prefs!.getString('$_prefix$key');
      if (json == null) return null;
      return jsonDecode(json);
    } catch (_) {
      return null;
    }
  }

  /// Get cached data regardless of age (for instant display before refresh).
  static dynamic getStale(String key) {
    if (_prefs == null) return null;
    try {
      final json = _prefs!.getString('$_prefix$key');
      if (json == null) return null;
      return jsonDecode(json);
    } catch (_) {
      return null;
    }
  }

  /// Remove a specific cache entry.
  static Future<void> remove(String key) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('$_prefix$key');
    await _prefs!.remove('$_tsPrefix$key');
  }

  /// Clear all cached API responses.
  static Future<void> clearAll() async {
    _prefs ??= await SharedPreferences.getInstance();
    final keys = _prefs!.getKeys().where((k) => k.startsWith(_prefix) || k.startsWith(_tsPrefix));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }
}
