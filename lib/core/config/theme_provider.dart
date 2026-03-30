import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to manage app theme (dark mode) and language
class ThemeProvider extends ChangeNotifier {
  static const String _darkModeKey = 'dark_mode';
  static const String _themeModeKey = 'theme_mode';
  static const String _languageKey = 'language';

  static ThemeProvider? _instance;

  static ThemeProvider get instance {
    _instance ??= ThemeProvider._();
    return _instance!;
  }

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('ar');

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  bool _isInitialized = false;

  ThemeProvider._() {
    _initialize();
  }

  /// Initialize and load saved preferences
  Future<void> _initialize() async {
    if (_isInitialized) return;
    await _loadPreferences();
    _isInitialized = true;
  }

  /// Load saved preferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedThemeMode = prefs.getString(_themeModeKey);
      if (storedThemeMode != null) {
        _themeMode = _parseThemeMode(storedThemeMode);
      } else {
        final legacyIsDark = prefs.getBool(_darkModeKey);
        if (legacyIsDark != null) {
          _themeMode = legacyIsDark ? ThemeMode.dark : ThemeMode.light;
        } else {
          _themeMode = ThemeMode.system;
        }
      }
      final languageCode = prefs.getString(_languageKey) ?? 'ar';
      _locale = Locale(languageCode);
      notifyListeners();
    } catch (e) {
      // Use defaults if loading fails
      _themeMode = ThemeMode.system;
      _locale = const Locale('ar');
    }
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'system':
        return ThemeMode.system;
      case 'dark':
        return ThemeMode.dark;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  String _serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, _serializeThemeMode(_themeMode));
      await prefs.setBool(_darkModeKey, _themeMode == ThemeMode.dark);
    } catch (e) {
      // Ignore save errors
    }
  }

  Future<void> useSystemTheme() => setThemeMode(ThemeMode.system);

  /// Ensure preferences are loaded (call this before using the provider)
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await _initialize();
    }
  }

  /// Toggle dark mode
  Future<void> toggleDarkMode() async {
    if (_themeMode == ThemeMode.system) {
      return setThemeMode(ThemeMode.dark);
    }
    return setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  /// Set dark mode
  Future<void> setDarkMode(bool value) async {
    return setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  /// Set language
  Future<void> setLanguage(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, locale.languageCode);
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Get language display name
  String getLanguageName() {
    switch (_locale.languageCode) {
      case 'ar':
        return 'العربية';
      case 'en':
        return 'English';
      default:
        return 'العربية';
    }
  }
}
