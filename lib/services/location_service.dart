import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static double nearfoRadiusKm = 500.0;

  /// Load saved radius from SharedPreferences (call once at app startup)
  static Future<void> loadSavedRadius() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble('discover_radius_km');
      if (saved != null) {
        nearfoRadiusKm = saved.clamp(100.0, 500.0);
        debugPrint('[Location] Loaded saved radius: ${nearfoRadiusKm}km');
      }
    } catch (e) {
      debugPrint('[Location] Error loading saved radius: $e');
    }
  }

  /// Get current position with permission handling
  /// Returns null with a reason string for debugging if location cannot be obtained
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[Location] Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        // Don't request permission here — PermissionsScreen handles that.
        // Requesting here causes race conditions with other permission dialogs
        // on Android 13+ (multiple system dialogs freeze and become untappable).
        debugPrint('[Location] Permission not granted ($permission) — skipping location update');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('[Location] Error getting position: $e');
      return null;
    }
  }

  /// Calculate distance between two coordinates in km
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// Check if a point is within the user's selected Vibe radius (100-500km)
  static bool isWithinNearfoRadius(
    double userLat, double userLon,
    double targetLat, double targetLon,
  ) {
    final distance = calculateDistance(userLat, userLon, targetLat, targetLon);
    return distance <= nearfoRadiusKm;
  }

  /// Feed split: always 80% local + 20% global — same at every radius interval.
  /// The radius only controls the "local" area size (100–500km), not the split ratio.
  static List<T> mixFeed<T>({
    required List<T> localPosts,
    required List<T> globalPosts,
    int totalCount = 20,
  }) {
    final localCount = (totalCount * 0.8).round();
    final globalCount = totalCount - localCount;

    final selectedLocal = localPosts.take(localCount).toList();
    final selectedGlobal = globalPosts.take(globalCount).toList();

    final mixed = [...selectedLocal, ...selectedGlobal];
    mixed.shuffle(Random());
    debugPrint('[Feed] mixFeed: radius=${nearfoRadiusKm}km, local=$localCount/$totalCount (80%), global=$globalCount/$totalCount (20%)');
    return mixed;
  }
}
