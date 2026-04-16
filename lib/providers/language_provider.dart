import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app locale (language switching).
/// Persists user's language choice to SharedPreferences.
class LanguageProvider extends ChangeNotifier {
  static const String _prefKey = 'app_locale';

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  /// Load saved locale from SharedPreferences (call once at startup)
  Future<void> loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      final supported = ['en', 'hi', 'fr', 'es', 'ar', 'zh', 'ru', 'pt'];
      if (saved != null && supported.contains(saved)) {
        _locale = Locale(saved);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[LanguageProvider] Error loading locale: $e');
    }
  }

  /// Change the app locale and persist to SharedPreferences
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, locale.languageCode);
    } catch (e) {
      debugPrint('[LanguageProvider] Error saving locale: $e');
    }
  }

  /// Toggle between English and Hindi
  Future<void> toggleLocale() async {
    final newLocale = _locale.languageCode == 'en'
        ? const Locale('hi')
        : const Locale('en');
    await setLocale(newLocale);
  }

  /// Get display name for current locale
  String get currentLanguageName {
    switch (_locale.languageCode) {
      case 'hi': return 'हिन्दी';
      case 'fr': return 'Français';
      case 'es': return 'Español';
      case 'ar': return 'العربية';
      case 'zh': return '中文';
      case 'ru': return 'Русский';
      case 'pt': return 'Português';
      default: return 'English';
    }
  }
}
