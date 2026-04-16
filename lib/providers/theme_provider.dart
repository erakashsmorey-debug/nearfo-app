import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All available theme definitions for Nearfo
class NearfoTheme {
  final String id;
  final String name;
  final String icon;
  final Color bg;
  final Color card;
  final Color cardHover;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color accent;
  final Color text;
  final Color textMuted;
  final Color textDim;
  final Color border;
  final Color success;
  final Color warning;
  final Color danger;
  final Color pink;

  const NearfoTheme({
    required this.id,
    required this.name,
    required this.icon,
    required this.bg,
    required this.card,
    required this.cardHover,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
    required this.text,
    required this.textMuted,
    required this.textDim,
    required this.border,
    required this.success,
    required this.warning,
    required this.danger,
    required this.pink,
  });

  LinearGradient get primaryGradient => LinearGradient(
        colors: [primary, accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get secondaryGradient => LinearGradient(
        colors: [pink, primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Premium gradient ring: Purple → Red → Orange (for profile avatars)
  LinearGradient get gradientRing => const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFFF0050), Color(0xFFFF8800)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Danger gradient (for live button, etc.)
  LinearGradient get gradientDanger => const LinearGradient(
        colors: [Color(0xFFFF0050), Color(0xFFFF4444)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

/// All built-in themes
class NearfoThemes {
  static const List<NearfoTheme> all = [
    // 1. Default Dark Purple (Original)
    NearfoTheme(
      id: 'dark_purple',
      name: 'Midnight Purple',
      icon: '🌙',
      bg: Color(0xFF0A0A0F),
      card: Color(0xFF14141F),
      cardHover: Color(0xFF1A1A2E),
      primary: Color(0xFF7C3AED),
      primaryLight: Color(0xFFA78BFA),
      primaryDark: Color(0xFF5B21B6),
      accent: Color(0xFF06B6D4),
      text: Color(0xFFF1F5F9),
      textMuted: Color(0xFF94A3B8),
      textDim: Color(0xFF64748B),
      border: Color(0xFF1E1E30),
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      danger: Color(0xFFEF4444),
      pink: Color(0xFFEC4899),
    ),

    // 2. Ocean Blue
    NearfoTheme(
      id: 'ocean_blue',
      name: 'Ocean Blue',
      icon: '🌊',
      bg: Color(0xFF0B1426),
      card: Color(0xFF111D35),
      cardHover: Color(0xFF162544),
      primary: Color(0xFF3B82F6),
      primaryLight: Color(0xFF60A5FA),
      primaryDark: Color(0xFF1D4ED8),
      accent: Color(0xFF22D3EE),
      text: Color(0xFFE2E8F0),
      textMuted: Color(0xFF94A3B8),
      textDim: Color(0xFF64748B),
      border: Color(0xFF1E293B),
      success: Color(0xFF34D399),
      warning: Color(0xFFFBBF24),
      danger: Color(0xFFF87171),
      pink: Color(0xFFF472B6),
    ),

    // 3. Emerald Green
    NearfoTheme(
      id: 'emerald_green',
      name: 'Emerald Night',
      icon: '🌿',
      bg: Color(0xFF071210),
      card: Color(0xFF0D1F1B),
      cardHover: Color(0xFF132C26),
      primary: Color(0xFF10B981),
      primaryLight: Color(0xFF6EE7B7),
      primaryDark: Color(0xFF059669),
      accent: Color(0xFF2DD4BF),
      text: Color(0xFFECFDF5),
      textMuted: Color(0xFF94A3B8),
      textDim: Color(0xFF64748B),
      border: Color(0xFF1A2E28),
      success: Color(0xFF10B981),
      warning: Color(0xFFFBBF24),
      danger: Color(0xFFF87171),
      pink: Color(0xFFF472B6),
    ),

    // 4. Rose Gold
    NearfoTheme(
      id: 'rose_gold',
      name: 'Rose Gold',
      icon: '🌹',
      bg: Color(0xFF150A10),
      card: Color(0xFF1F1018),
      cardHover: Color(0xFF2A1520),
      primary: Color(0xFFEC4899),
      primaryLight: Color(0xFFF9A8D4),
      primaryDark: Color(0xFFDB2777),
      accent: Color(0xFFF59E0B),
      text: Color(0xFFFDF2F8),
      textMuted: Color(0xFFA3A3A3),
      textDim: Color(0xFF737373),
      border: Color(0xFF2E1A24),
      success: Color(0xFF34D399),
      warning: Color(0xFFFBBF24),
      danger: Color(0xFFF87171),
      pink: Color(0xFFEC4899),
    ),

    // 5. Sunset Orange
    NearfoTheme(
      id: 'sunset_orange',
      name: 'Sunset Blaze',
      icon: '🌅',
      bg: Color(0xFF120C08),
      card: Color(0xFF1C1510),
      cardHover: Color(0xFF251C16),
      primary: Color(0xFFF97316),
      primaryLight: Color(0xFFFDBA74),
      primaryDark: Color(0xFFEA580C),
      accent: Color(0xFFFBBF24),
      text: Color(0xFFFFF7ED),
      textMuted: Color(0xFFA3A3A3),
      textDim: Color(0xFF737373),
      border: Color(0xFF2E2218),
      success: Color(0xFF34D399),
      warning: Color(0xFFFBBF24),
      danger: Color(0xFFF87171),
      pink: Color(0xFFF472B6),
    ),

    // 6. AMOLED Black
    NearfoTheme(
      id: 'amoled_black',
      name: 'AMOLED Black',
      icon: '🖤',
      bg: Color(0xFF000000),
      card: Color(0xFF0A0A0A),
      cardHover: Color(0xFF141414),
      primary: Color(0xFF8B5CF6),
      primaryLight: Color(0xFFC4B5FD),
      primaryDark: Color(0xFF6D28D9),
      accent: Color(0xFF06B6D4),
      text: Color(0xFFFFFFFF),
      textMuted: Color(0xFF9CA3AF),
      textDim: Color(0xFF6B7280),
      border: Color(0xFF1A1A1A),
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      danger: Color(0xFFEF4444),
      pink: Color(0xFFEC4899),
    ),

    // 7. Neon Cyber
    NearfoTheme(
      id: 'neon_cyber',
      name: 'Neon Cyber',
      icon: '⚡',
      bg: Color(0xFF0A0014),
      card: Color(0xFF12001F),
      cardHover: Color(0xFF1A002E),
      primary: Color(0xFFD946EF),
      primaryLight: Color(0xFFF0ABFC),
      primaryDark: Color(0xFFC026D3),
      accent: Color(0xFF00F0FF),
      text: Color(0xFFF5F3FF),
      textMuted: Color(0xFFA78BFA),
      textDim: Color(0xFF7C3AED),
      border: Color(0xFF2A0040),
      success: Color(0xFF4ADE80),
      warning: Color(0xFFFDE047),
      danger: Color(0xFFFB7185),
      pink: Color(0xFFFF6FF0),
    ),

    // 8. Premium Dark (Premium UI Theme)
    NearfoTheme(
      id: 'premium_dark',
      name: 'Premium Dark',
      icon: '💎',
      bg: Color(0xFF0A0A0F),
      card: Color(0xFF12121A),
      cardHover: Color(0xFF1A1A28),
      primary: Color(0xFF8B5CF6),
      primaryLight: Color(0xFFA78BFA),
      primaryDark: Color(0xFF6D28D9),
      accent: Color(0xFF06B6D4),
      text: Color(0xFFF1F5F9),
      textMuted: Color(0xFF94A3B8),
      textDim: Color(0xFF475569),
      border: Color(0xFF1E1E30),
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      danger: Color(0xFFFF0050),
      pink: Color(0xFFEC4899),
    ),

    // 9. Arctic White (Light Theme)
    NearfoTheme(
      id: 'arctic_white',
      name: 'Arctic White',
      icon: '❄️',
      bg: Color(0xFFF8FAFC),
      card: Color(0xFFFFFFFF),
      cardHover: Color(0xFFF1F5F9),
      primary: Color(0xFF7C3AED),
      primaryLight: Color(0xFFA78BFA),
      primaryDark: Color(0xFF5B21B6),
      accent: Color(0xFF0891B2),
      text: Color(0xFF0F172A),
      textMuted: Color(0xFF64748B),
      textDim: Color(0xFF94A3B8),
      border: Color(0xFFE2E8F0),
      success: Color(0xFF059669),
      warning: Color(0xFFD97706),
      danger: Color(0xFFDC2626),
      pink: Color(0xFFDB2777),
    ),
  ];

  static NearfoTheme getById(String id) {
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }
}

/// Provider that manages the current theme
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'nearfo_theme_id';
  NearfoTheme _currentTheme = NearfoThemes.all.first;

  ThemeProvider() {
    _loadTheme();
  }

  NearfoTheme get current => _currentTheme;
  String get currentId => _currentTheme.id;

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeId = prefs.getString(_themeKey) ?? 'dark_purple';
      _currentTheme = NearfoThemes.getById(themeId);
      notifyListeners();
    } catch (e) {
      // Use default theme
    }
  }

  Future<void> setTheme(String themeId) async {
    _currentTheme = NearfoThemes.getById(themeId);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, themeId);
    } catch (e) {
      // Silently fail
    }
  }

  // Convenience getters that match NearfoColors static API
  Color get bg => _currentTheme.bg;
  Color get card => _currentTheme.card;
  Color get cardHover => _currentTheme.cardHover;
  Color get primary => _currentTheme.primary;
  Color get primaryLight => _currentTheme.primaryLight;
  Color get primaryDark => _currentTheme.primaryDark;
  Color get accent => _currentTheme.accent;
  Color get text => _currentTheme.text;
  Color get textMuted => _currentTheme.textMuted;
  Color get textDim => _currentTheme.textDim;
  Color get border => _currentTheme.border;
  Color get success => _currentTheme.success;
  Color get warning => _currentTheme.warning;
  Color get danger => _currentTheme.danger;
  Color get pink => _currentTheme.pink;
}
