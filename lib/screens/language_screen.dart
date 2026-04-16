import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../utils/constants.dart';
import '../l10n/l10n_helper.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final currentCode = langProvider.locale.languageCode;

    return Scaffold(
      backgroundColor: NearfoColors.bg,
      appBar: AppBar(
        backgroundColor: NearfoColors.bg,
        title: Text(
          context.l10n.languageTitle,
          style: TextStyle(color: NearfoColors.text, fontWeight: FontWeight.w700, fontSize: 20),
        ),
        iconTheme: IconThemeData(color: NearfoColors.text),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.languageSubtitle,
              style: TextStyle(color: NearfoColors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: L10n.supportedLocales.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final locale = L10n.supportedLocales[index];
                  final code = locale.languageCode;
                  final displayName = L10n.localeNames[code] ?? code;
                  final flag = L10n.localeFlags[code] ?? '';
                  // Extract native name (before the parenthesis) or use full name
                  final nativeName = displayName.contains('(')
                      ? displayName.split(' (').first
                      : displayName;
                  // Extract English name from parenthesis, or use display name
                  final englishName = displayName.contains('(')
                      ? displayName.split('(').last.replaceAll(')', '')
                      : displayName;
                  return _LanguageTile(
                    flag: flag,
                    name: englishName,
                    nativeName: nativeName,
                    isSelected: currentCode == code,
                    onTap: () => _changeLocale(context, locale),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeLocale(BuildContext context, Locale locale) {
    final langProvider = context.read<LanguageProvider>();
    langProvider.setLocale(locale);
    final displayName = L10n.localeNames[locale.languageCode] ?? 'English';
    // Use native name (before parenthesis) for the snackbar
    final name = displayName.contains('(')
        ? displayName.split(' (').first
        : displayName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.languageChanged(language: name)),
        backgroundColor: NearfoColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String flag;
  final String name;
  final String nativeName;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.flag,
    required this.name,
    required this.nativeName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? NearfoColors.primary.withOpacity(0.15) : NearfoColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? NearfoColors.primary : NearfoColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nativeName,
                    style: TextStyle(
                      color: NearfoColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    name,
                    style: TextStyle(
                      color: NearfoColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: NearfoColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
