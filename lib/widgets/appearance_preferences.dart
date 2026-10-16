import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization.dart';
import '../models/settings.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'app_dropdown.dart';
import '../core/theme/app_palettes.g.dart';

/// Shared appearance controls for the welcome page and settings.
class AppearancePreferences extends StatelessWidget {
  const AppearancePreferences({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppDropdown<String>.settings(
          key: const Key('language-selector'),
          title: context.l10n.language,
          value: vm.settings.language,
          onChanged: (value) {
            if (value != null) vm.setLanguage(value);
          },
          items: [
            DropdownMenuItem(
              value: 'ar',
              child: Text(context.l10n.arabicLanguage),
            ),
            DropdownMenuItem(
              value: 'en',
              child: Text(context.l10n.englishLanguage),
            ),
          ],
        ),
        AppDropdown<ThemePreference>.settings(
          key: const Key('theme-selector'),
          title: context.l10n.theme,
          value: vm.settings.theme,
          onChanged: (value) {
            if (value != null) vm.setTheme(value);
          },
          items: [
            for (final theme in ThemePreference.values)
              DropdownMenuItem(
                value: theme,
                child: Text(theme.label(context.l10n)),
              ),
          ],
        ),
        AppDropdown<ColorSchemePreference>.settings(
          key: const Key('color-scheme-selector'),
          title: context.l10n.colorScheme,
          value: vm.settings.colorScheme,
          onChanged: (value) {
            if (value != null) vm.setColorScheme(value);
          },
          items: [
            for (final scheme in ColorSchemePreference.values)
              DropdownMenuItem(
                value: scheme,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 16,
                      color: AppPalettes.resolve(
                        scheme,
                        Theme.of(context).brightness,
                      ).primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(scheme.label(context.l10n))),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
