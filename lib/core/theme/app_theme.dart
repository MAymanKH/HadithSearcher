import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/settings.dart';
import 'app_palettes.g.dart';

/// Component color policy. Raw palette values live in colors.json.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme =>
      build(ColorSchemePreference.classic, Brightness.light);
  static ThemeData get darkTheme =>
      build(ColorSchemePreference.classic, Brightness.dark);

  static Color unavailableActionForeground(ColorScheme colors) =>
      Color.alphaBlend(
        colors.onInverseSurface.withValues(alpha: .52),
        colors.inverseSurface,
      );

  static Color disabledForeground(ColorScheme colors) =>
      colors.onSurface.withValues(alpha: .6);

  static Color disabledBackground(ColorScheme colors) =>
      colors.onSurface.withValues(alpha: .12);

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

  static ThemeData build(ColorSchemePreference palette, Brightness brightness) {
    final colors = AppPalettes.resolve(palette, brightness);
    final transparent = AppPalettes.transparent;
    final border = OutlineInputBorder(
      borderSide: BorderSide(width: 1.5, color: colors.outline),
      borderRadius: BorderRadius.circular(50),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      colorScheme: colors,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadePageTransitionsBuilder(),
          TargetPlatform.linux: _FadePageTransitionsBuilder(),
          TargetPlatform.macOS: _FadePageTransitionsBuilder(),
          TargetPlatform.windows: _FadePageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      cardColor: colors.surfaceContainer,
      dividerColor: colors.outlineVariant,
      disabledColor: colors.onSurfaceVariant,
      hintColor: colors.onSurfaceVariant,
      shadowColor: colors.shadow,
      focusColor: colors.primary.withValues(alpha: .18),
      hoverColor: colors.primary.withValues(alpha: .08),
      highlightColor: colors.primary.withValues(alpha: .10),
      splashColor: colors.primary.withValues(alpha: .12),
      iconTheme: IconThemeData(color: colors.onSurface),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide.none,
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.outlineVariant,
        ),
        checkColor: WidgetStatePropertyAll(colors.onPrimary),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.outlineVariant,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.onSurfaceVariant,
        ),
        trackOutlineColor: WidgetStatePropertyAll(transparent),
        trackOutlineWidth: const WidgetStatePropertyAll(0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        labelStyle: TextStyle(color: colors.onSurface),
        floatingLabelStyle: TextStyle(color: colors.primary),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(width: 2, color: colors.primary),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(width: 1.5, color: colors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(width: 2, color: colors.error),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: transparent,
        systemOverlayStyle: systemUiOverlayStyle(brightness),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.secondary,
          foregroundColor: colors.onSecondary,
          disabledBackgroundColor: colors.surfaceContainer,
          disabledForegroundColor: colors.onSurfaceVariant,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          disabledForegroundColor: disabledForeground(colors),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              disabledForegroundColor: disabledForeground(colors),
              disabledBackgroundColor: disabledBackground(colors),
            ).copyWith(
              side: WidgetStateBorderSide.resolveWith(
                (states) => BorderSide(
                  // Keep the shape visible when disabled; only the content dims.
                  color: colors.outline,
                ),
              ),
            ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          disabledForegroundColor: disabledForeground(colors),
          disabledBackgroundColor: disabledBackground(colors),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty<Color?>.fromMap({
            WidgetState.disabled: disabledForeground(colors),
          }),
          iconColor: WidgetStateProperty<Color?>.fromMap({
            WidgetState.disabled: disabledForeground(colors),
          }),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: colors.secondary,
        foregroundColor: colors.onSecondary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: transparent,
        indicatorColor: colors.secondaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.bold
                : FontWeight.normal,
            color: colors.onSurface,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: 'Cairo',
          color: colors.onInverseSurface,
        ),
        actionTextColor: colors.onInverseSurface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: transparent,
        modalBarrierColor: colors.scrim.withValues(alpha: .54),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: transparent,
        barrierColor: colors.scrim.withValues(alpha: .54),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(
          fontFamily: 'Cairo',
          color: colors.onInverseSurface,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: .25),
        selectionHandleColor: colors.primary,
      ),
    );
  }
}

class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}
