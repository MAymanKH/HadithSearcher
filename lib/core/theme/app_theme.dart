import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App theme configuration.
class AppTheme {
  AppTheme._();

  static CheckboxThemeData _checkboxTheme(Color foreground, Color background) =>
      CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: WidgetStateBorderSide.resolveWith(
          (_) => BorderSide(color: foreground, width: 1.5),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? foreground
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(background),
      );

  static SystemUiOverlayStyle systemUiOverlayStyle(Brightness brightness) {
    final icons = brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarBrightness: brightness,
      statusBarIconBrightness: icons,
      systemNavigationBarIconBrightness: icons,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: true,
    );
  }

  /// Light theme.
  static ThemeData get lightTheme {
    return ThemeData(
      fontFamilyFallback: const ['Cairo'],
      brightness: Brightness.light,
      checkboxTheme: _checkboxTheme(Colors.black, Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(color: Color(0xFF757575)),
        labelStyle: const TextStyle(color: Colors.black),
        floatingLabelStyle: const TextStyle(color: Colors.black),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(width: 1.5, color: Colors.black),
          borderRadius: BorderRadius.circular(50),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(width: 1.5, color: Colors.black),
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: systemUiOverlayStyle(Brightness.light),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Colors.blue,
        onPrimary: Colors.white,
        primaryContainer: Color.fromARGB(255, 225, 226, 230),
        secondaryContainer: Colors.black,
        secondary: Colors.blue,
        onSecondary: Colors.blue,
        error: Colors.red,
        onError: Colors.red,
        surface: Colors.white,
        onSurface: Colors.black,
      ),
    );
  }

  /// Dark theme.
  static ThemeData get darkTheme {
    return ThemeData(
      fontFamilyFallback: const ['Cairo'],
      brightness: Brightness.dark,
      checkboxTheme: _checkboxTheme(Colors.white, Colors.black),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        labelStyle: const TextStyle(color: Colors.white),
        floatingLabelStyle: const TextStyle(color: Colors.white),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(width: 1.5, color: Colors.white),
          borderRadius: BorderRadius.circular(50),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(width: 1.5, color: Colors.white),
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: systemUiOverlayStyle(Brightness.dark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Colors.blue,
        onPrimary: Colors.white,
        primaryContainer: Color.fromARGB(255, 40, 38, 41),
        secondaryContainer: Colors.white,
        secondary: Colors.blue,
        onSecondary: Colors.blue,
        error: Colors.red,
        onError: Colors.red,
        surface: Colors.black,
        onSurface: Colors.white,
      ),
    );
  }
}
