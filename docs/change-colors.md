# Change an app color

1. Edit the appropriate category in `lib/core/theme/colors.json`.
2. Run `python scripts/generate_colors.py`.
3. Run `python scripts/generate_colors.py --check` to verify generated files.
4. Run `flutter test test/theme_test.dart test/color_scheme_app_test.dart` to check contrast, widget styles, persistence, and system brightness.

To add a palette, add its stable identifier to `ColorSchemePreference` in `lib/models/settings.dart`. Add both brightness variants to the manifest. Add its labels to both ARB catalogs and the `LocalizedColorScheme` extension, then run `flutter gen-l10n`. The existing selector and test matrix enumerate the new palette automatically.

To change shared branding colors, regenerate the artwork and native resources after step 2:

```sh
python scripts/generate_branding.py
dart run flutter_launcher_icons
dart run flutter_native_splash:create
python scripts/generate_colors.py
python scripts/generate_branding.py --check
```

Running `generate_colors.py` after the splash plugin restores generated Android resource references. The branding check requires `rsvg-convert` and ImageMagick. Check the generated images and Android day and night splash screens after a branding change.

To capture the palette matrix with bundled fonts:

```sh
flutter test test/theme_test.dart --dart-define=CAPTURE_SCREENSHOTS=true
```

The screenshots are written to `/tmp/hadith-themes`. Read [App color schemes](color-schemes.md) for role ownership and native splash behavior.
