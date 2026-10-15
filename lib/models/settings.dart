import 'package:flutter/material.dart';

/// App settings for theme and hadith display preferences.
class AppSettings {
  final ThemePreference theme;
  final String language;
  final String fontFamily;
  final FontWeightPreference fontWeight;
  final int fontSize;
  final int padding;

  const AppSettings({
    this.theme = ThemePreference.system,
    this.language = 'ar',
    this.fontFamily = 'Roboto',
    this.fontWeight = FontWeightPreference.bold,
    this.fontSize = 20,
    this.padding = 10,
  });

  /// Creates settings from database row.
  factory AppSettings.fromDatabase(Map<String, dynamic> row) {
    return AppSettings(
      theme: ThemePreference.fromString(row['theme'] ?? 'system'),
      language: row['language'] == 'en' ? 'en' : 'ar',
      fontFamily: row['fontfamily'] ?? 'Roboto',
      fontWeight: FontWeightPreference.fromString(row['fontweight'] ?? 'bold'),
      fontSize: row['fontsize'] ?? 20,
      padding: row['padding'] ?? 10,
    );
  }

  /// Default settings.
  static const AppSettings defaults = AppSettings();

  /// Flutter ThemeMode based on preference.
  ThemeMode get themeMode => theme.toThemeMode();

  /// Flutter FontWeight based on preference.
  FontWeight get flutterFontWeight => fontWeight.toFontWeight();

  /// EdgeInsets based on padding value.
  EdgeInsets get paddingInsets => EdgeInsets.all(padding.toDouble());

  /// Creates a copy with updated values.
  AppSettings copyWith({
    ThemePreference? theme,
    String? language,
    String? fontFamily,
    FontWeightPreference? fontWeight,
    int? fontSize,
    int? padding,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      fontSize: fontSize ?? this.fontSize,
      padding: padding ?? this.padding,
    );
  }
}

/// Theme preference enum.
enum ThemePreference {
  system,
  light,
  dark;

  /// Converts string from database to enum.
  static ThemePreference fromString(String value) {
    switch (value) {
      case 'light':
        return ThemePreference.light;
      case 'dark':
        return ThemePreference.dark;
      default:
        return ThemePreference.system;
    }
  }

  /// Converts to string for database storage.
  String toDbString() {
    switch (this) {
      case ThemePreference.light:
        return 'light';
      case ThemePreference.dark:
        return 'dark';
      case ThemePreference.system:
        return 'system';
    }
  }

  /// Converts to Flutter ThemeMode.
  ThemeMode toThemeMode() {
    switch (this) {
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
      case ThemePreference.system:
        return ThemeMode.system;
    }
  }
}

/// Font weight preference enum.
enum FontWeightPreference {
  normal,
  bold;

  /// Converts string from database to enum.
  static FontWeightPreference fromString(String value) {
    switch (value) {
      case 'bold':
        return FontWeightPreference.bold;
      default:
        return FontWeightPreference.normal;
    }
  }

  /// Converts to string for database storage.
  String toDbString() {
    switch (this) {
      case FontWeightPreference.normal:
        return 'normal';
      case FontWeightPreference.bold:
        return 'bold';
    }
  }

  /// Converts to Flutter FontWeight.
  FontWeight toFontWeight() {
    switch (this) {
      case FontWeightPreference.normal:
        return FontWeight.normal;
      case FontWeightPreference.bold:
        return FontWeight.bold;
    }
  }
}
