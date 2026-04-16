import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// Supported locales for the Nearfo app
class L10n {
  static const supportedLocales = [
    Locale('en'), // English
    Locale('hi'), // Hindi
    Locale('fr'), // French
    Locale('es'), // Spanish
    Locale('ar'), // Arabic
    Locale('zh'), // Chinese (Simplified)
    Locale('ru'), // Russian
    Locale('pt'), // Portuguese (Brazilian)
  ];

  static const localizationsDelegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Map of locale code → display name (shown in language picker)
  static const localeNames = {
    'en': 'English',
    'hi': 'हिन्दी (Hindi)',
    'fr': 'Français (French)',
    'es': 'Español (Spanish)',
    'ar': 'العربية (Arabic)',
    'zh': '中文 (Chinese)',
    'ru': 'Русский (Russian)',
    'pt': 'Português (Portuguese)',
  };

  /// Map of locale code → flag emoji
  static const localeFlags = {
    'en': '🇬🇧',
    'hi': '🇮🇳',
    'fr': '🇫🇷',
    'es': '🇪🇸',
    'ar': '🇸🇦',
    'zh': '🇨🇳',
    'ru': '🇷🇺',
    'pt': '🇧🇷',
  };
}

/// Extension on BuildContext for easy access to AppLocalizations
extension L10nExtension on BuildContext {
  /// Shorthand: context.l10n.appName instead of AppLocalizations.of(context).appName
  AppLocalizations get l10n => AppLocalizations.of(this);
}
