# Change app colors

Edit `lib/core/theme/colors.json`, then regenerate and check the runtime and Android colors:

```sh
python3 scripts/generate_colors.py
python3 scripts/generate_colors.py --check
flutter test test/theme_test.dart test/color_scheme_app_test.dart test/theme_control_contrast_test.dart
```

To add a palette, add its identifier to `ColorSchemePreference` in `lib/models/settings.dart` and both brightness variants to `colors.json`. Add its labels to both ARB catalogs and the `LocalizedColorScheme` extension, then run `flutter gen-l10n`.

If you change shared branding colors, regenerate the artwork and splash resources:

```sh
python3 scripts/generate_branding.py
dart run flutter_launcher_icons
dart run flutter_native_splash:create
python3 scripts/generate_colors.py
python3 scripts/generate_branding.py --check
```

Branding generation requires `rsvg-convert` and ImageMagick. Run `generate_colors.py` after the splash plugin to restore Android resource references. Inspect the generated artwork and Android splash screens in light and dark mode.
