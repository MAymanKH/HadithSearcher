import 'package:flutter/material.dart';
import '../models/settings.dart';
import '../services/settings_service.dart';
import '../services/telemetry/telemetry_service.dart';

/// ViewModel for app-wide settings (theme, font preferences).
/// This is shared across all views.
class SettingsViewModel extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  AppSettings _settings = AppSettings.defaults;
  bool _isLoading = true;
  bool _welcomeCompleted = false;

  bool get welcomeCompleted => _welcomeCompleted;
  Locale get locale => Locale(_settings.language);

  /// Current settings.
  AppSettings get settings => _settings;

  /// Whether settings are still loading.
  bool get isLoading => _isLoading;

  // Convenience getters for common settings
  String get fontFamily => _settings.fontFamily;
  FontWeight get fontWeight => _settings.flutterFontWeight;
  double get fontSize => _settings.fontSize.toDouble();
  EdgeInsets get padding => _settings.paddingInsets;
  ThemeMode get themeMode => _settings.themeMode;

  TextStyle get readingTextStyle => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: const [],
    fontWeight: fontWeight,
    fontSize: fontSize,
  );

  /// Available font families.
  static const List<String> fontFamilies = [
    'Roboto',
    'Cairo',
    'Tajawal',
    'Noto Naskh Arabic',
    'Amiri',
    'Lateef',
    'Gulzar',
    'Aref Ruqaa',
    'Reem Kufi',
  ];

  /// Available font sizes.
  static const List<int> fontSizes = [10, 20, 30, 40, 50];

  /// Available padding values.
  static const List<int> paddingValues = [5, 10, 15, 20, 25, 30];

  /// Load settings from SharedPreferences.
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    _settings = await _settingsService.getSettings();
    _welcomeCompleted = await _settingsService.hasCompletedWelcome();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    if (language != 'ar' && language != 'en') return;
    if (await _settingsService.updateLanguage(language)) {
      _settings = _settings.copyWith(language: language);
      notifyListeners();
    }
  }

  Future<bool> completeWelcome() async {
    if (!await _settingsService.completeWelcome()) return false;
    _welcomeCompleted = true;
    notifyListeners();
    return true;
  }

  /// Update theme preference.
  Future<void> setTheme(ThemePreference theme) async {
    if (await _settingsService.updateTheme(theme)) {
      TelemetryService.event('appearance_changed', {
        'setting': 'theme',
        'value': theme.name,
      });
    }
    _settings = _settings.copyWith(theme: theme);
    notifyListeners();
  }

  /// Update font family.
  Future<void> setFontFamily(String fontFamily) async {
    if (await _settingsService.updateFontFamily(fontFamily)) {
      TelemetryService.event('appearance_changed', {
        'setting': 'font_family',
        'value': fontFamily,
      });
    }
    _settings = _settings.copyWith(fontFamily: fontFamily);
    notifyListeners();
  }

  /// Update font weight.
  Future<void> setFontWeight(FontWeightPreference fontWeight) async {
    if (await _settingsService.updateFontWeight(fontWeight)) {
      TelemetryService.event('appearance_changed', {
        'setting': 'font_weight',
        'value': fontWeight.name,
      });
    }
    _settings = _settings.copyWith(fontWeight: fontWeight);
    notifyListeners();
  }

  /// Update font size.
  Future<void> setFontSize(int fontSize) async {
    if (await _settingsService.updateFontSize(fontSize)) {
      TelemetryService.event('appearance_changed', {
        'setting': 'font_size',
        'value': fontSize,
      });
    }
    _settings = _settings.copyWith(fontSize: fontSize);
    notifyListeners();
  }

  /// Update padding.
  Future<void> setPadding(int padding) async {
    if (await _settingsService.updatePadding(padding)) {
      TelemetryService.event('appearance_changed', {
        'setting': 'padding',
        'value': padding,
      });
    }
    _settings = _settings.copyWith(padding: padding);
    notifyListeners();
  }

  /// Reset all settings to defaults.
  Future<void> resetToDefaults() async {
    await _settingsService.resetSettings();
    _settings = AppSettings.defaults;
    TelemetryService.event('settings_reset');
    notifyListeners();
  }
}
