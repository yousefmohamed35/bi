import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Helper class to easily access localization strings
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  bool get isArabicLocale => Localizations.localeOf(this).languageCode == 'ar';

  /// Resolves bilingual API fields like:
  /// - base + _ar + _en (snake_case)
  /// - base + Ar + En (camelCase)
  /// Falls back to [fallback] when all values are empty/null.
  String localizedApiText(
    Map<String, dynamic>? data,
    String base, {
    String fallback = '',
  }) {
    if (data == null) return fallback;

    String? pick(dynamic value) {
      final text = value?.toString().trim();
      return (text == null || text.isEmpty) ? null : text;
    }

    final snakeAr = pick(data['${base}_ar']);
    final snakeEn = pick(data['${base}_en']);
    final camelAr = pick(data['${base}Ar']);
    final camelEn = pick(data['${base}En']);
    final plain = pick(data[base]);

    if (isArabicLocale) {
      return snakeAr ?? camelAr ?? plain ?? snakeEn ?? camelEn ?? fallback;
    }
    return snakeEn ?? camelEn ?? plain ?? snakeAr ?? camelAr ?? fallback;
  }
}
