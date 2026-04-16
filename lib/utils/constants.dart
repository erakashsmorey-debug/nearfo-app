import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

// ===== VIBE APP CONSTANTS =====

class NearfoColors {
  static ThemeProvider? _provider;

  /// Called once from Consumer<ThemeProvider> in main.dart
  static void setProvider(ThemeProvider p) => _provider = p;

  // Dynamic colors — read from ThemeProvider, fallback to defaults
  static Color get bg => _provider?.bg ?? const Color(0xFF0A0A0F);
  static Color get card => _provider?.card ?? const Color(0xFF14141F);
  static Color get cardHover => _provider?.cardHover ?? const Color(0xFF1A1A2E);
  static Color get primary => _provider?.primary ?? const Color(0xFF7C3AED);
  static Color get primaryLight => _provider?.primaryLight ?? const Color(0xFFA78BFA);
  static Color get primaryDark => _provider?.primaryDark ?? const Color(0xFF5B21B6);
  static Color get accent => _provider?.accent ?? const Color(0xFF06B6D4);
  static Color get text => _provider?.text ?? const Color(0xFFF1F5F9);
  static Color get textMuted => _provider?.textMuted ?? const Color(0xFF94A3B8);
  static Color get textDim => _provider?.textDim ?? const Color(0xFF64748B);
  static Color get border => _provider?.border ?? const Color(0xFF1E1E30);
  static Color get success => _provider?.success ?? const Color(0xFF10B981);
  static Color get warning => _provider?.warning ?? const Color(0xFFF59E0B);
  static Color get danger => _provider?.danger ?? const Color(0xFFEF4444);
  static Color get pink => _provider?.pink ?? const Color(0xFFEC4899);

  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get secondaryGradient => LinearGradient(
    colors: [pink, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Premium gradients
  static const LinearGradient gradientRing = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFFF0050), Color(0xFFFF8800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientDanger = LinearGradient(
    colors: [Color(0xFFFF0050), Color(0xFFFF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color gold = Color(0xFFFFD700);
}

class NearfoConfig {
  static const String appName = 'Nearfo';
  static const String tagline = 'Know Your Circle';
  static const String apiBaseUrl = 'https://api.nearfo.com/api/v1';
  static const String wsUrl = 'wss://api.nearfo.com';

  /// Metered.ca TURN server API key (free tier: 500GB/month)
  /// Get your key at: https://www.metered.ca/stun-turn → Create App → Copy API Key
  static const String meteredTurnApiKey = '';

  /// Base host extracted from apiBaseUrl (e.g. "https://api.nearfo.com")
  static String get _apiHost {
    final uri = Uri.parse(apiBaseUrl);
    return '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}';
  }

  /// Resolves a media URL to an absolute URL.
  /// Handles: absolute URLs (returned as-is), relative with leading '/',
  /// and relative without leading '/' (e.g. "uploads/voice/abc.mp3").
  static String resolveMediaUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$_apiHost$url';
    // Relative path without leading slash (e.g. "uploads/voice/abc.mp3")
    return '$_apiHost/$url';
  }

  static const double defaultRadius = 500.0; // km (user can adjust 100-500km)
  // 80/20 split is fixed at all radius intervals (100-500km)
  static const double localFeedPercentage = 0.80;
  static const double globalFeedPercentage = 0.20;
  static const int maxPostLength = 500;
  static const int maxBioLength = 150;
  static const int feedPageSize = 20;
  static const String mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String mapAttribution = '© OpenStreetMap contributors';
}

class NearfoRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String otpVerify = '/otp-verify';
  static const String setupProfile = '/setup-profile';
  static const String home = '/home';
  static const String discover = '/discover';
  static const String chat = '/chat';
  static const String chatDetail = '/chat-detail';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String settings = '/settings';
  static const String compose = '/compose';
  static const String savedPosts = '/saved-posts';
  static const String analytics = '/analytics';
  static const String myCircle = '/my-circle';
  static const String premium = '/premium';
  static const String permissions = '/permissions';
  static const String savedReels = '/saved-reels';
  static const String userProfile = '/user-profile';
  static const String nearfoScore = '/nearfo-score';
  static const String createStory = '/create-story';
  static const String bossCommand = '/boss-command';
  static const String adminPanel = '/admin-panel';
  static const String monetization = '/monetization';
}

/// Admin/Owner check — only these handles can see admin features
class NearfoAdmin {
  static const List<String> ownerHandles = ['akash_nearfo', 'akash'];
  static const List<String> ownerPhones = ['+919860400438', '9860400438'];

  static bool isOwner(String? handle, {String? phone}) {
    if (handle != null && ownerHandles.contains(handle.toLowerCase())) return true;
    if (phone != null && ownerPhones.contains(phone)) return true;
    return false;
  }
}
