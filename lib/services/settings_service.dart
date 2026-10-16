import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';

/// Service for managing app settings using SharedPreferences.
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _themeKey = 'theme';
  static const String _colorSchemeKey = 'colorScheme';
  static const String _fontFamilyKey = 'fontFamily';
  static const String _fontWeightKey = 'fontWeight';
  static const String _fontSizeKey = 'fontSize';
  static const String _paddingKey = 'padding';
  static const String _languageKey = 'language';
  static const String _welcomeKey = 'welcomeCompleted';

  /// Initialize SharedPreferences instance.
  Future<SharedPreferences> get prefs async {
    return SharedPreferences.getInstance();
  }

  /// Get app settings.
  Future<AppSettings> getSettings() async {
    try {
      final p = await prefs;
      return AppSettings(
        theme: ThemePreference.fromString(p.getString(_themeKey) ?? 'system'),
        colorScheme: ColorSchemePreference.fromString(
          p.getString(_colorSchemeKey),
        ),
        language: p.getString(_languageKey) == 'en' ? 'en' : 'ar',
        fontFamily: p.getString(_fontFamilyKey) ?? 'Roboto',
        fontWeight: FontWeightPreference.fromString(
          p.getString(_fontWeightKey) ?? 'bold',
        ),
        fontSize: p.getInt(_fontSizeKey) ?? 20,
        padding: p.getInt(_paddingKey) ?? 10,
      );
    } catch (e) {
      // Return default settings on error
      return AppSettings(
        theme: ThemePreference.system,
        fontFamily: 'Roboto',
        fontWeight: FontWeightPreference.bold,
        fontSize: 20,
        padding: 10,
      );
    }
  }

  Future<bool> hasCompletedWelcome() async =>
      (await prefs).getBool(_welcomeKey) ?? false;

  Future<bool> completeWelcome() async =>
      (await prefs).setBool(_welcomeKey, true);

  Future<bool> updateLanguage(String language) async =>
      (await prefs).setString(_languageKey, language);

  /// Update theme setting.
  Future<bool> updateTheme(ThemePreference theme) async {
    try {
      final p = await prefs;
      await p.setString(_themeKey, theme.toDbString());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateColorScheme(ColorSchemePreference scheme) async {
    try {
      return await (await prefs).setString(_colorSchemeKey, scheme.name);
    } catch (_) {
      return false;
    }
  }

  /// Update font family setting.
  Future<bool> updateFontFamily(String fontFamily) async {
    try {
      final p = await prefs;
      await p.setString(_fontFamilyKey, fontFamily);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update font weight setting.
  Future<bool> updateFontWeight(FontWeightPreference fontWeight) async {
    try {
      final p = await prefs;
      await p.setString(_fontWeightKey, fontWeight.toDbString());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update font size setting.
  Future<bool> updateFontSize(int fontSize) async {
    try {
      final p = await prefs;
      await p.setInt(_fontSizeKey, fontSize);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update padding setting.
  Future<bool> updatePadding(int padding) async {
    try {
      final p = await prefs;
      await p.setInt(_paddingKey, padding);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reset all settings to defaults.
  Future<bool> resetSettings() async {
    try {
      final p = await prefs;
      await p.setString(_themeKey, 'system');
      await p.setString(_colorSchemeKey, ColorSchemePreference.classic.name);
      await p.setString(_languageKey, 'ar');
      await p.setString(_fontFamilyKey, 'Roboto');
      await p.setString(_fontWeightKey, 'bold');
      await p.setInt(_fontSizeKey, 20);
      await p.setInt(_paddingKey, 10);
      return true;
    } catch (e) {
      return false;
    }
  }
}
