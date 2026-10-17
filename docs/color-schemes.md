# App color schemes

`lib/core/theme/colors.json` owns every authored UI color. It groups values by palette, brightness, and purpose. `scripts/generate_colors.py` emits the complete Material `ColorScheme` catalog, Android color resources, and the color entries in `pubspec.yaml`. `scripts/generate_branding.py` reads the same shared colors for generated artwork. Both scripts support `--check` to detect stale output.

The ten palettes are Classic, Sepia, Slate, Forest, High contrast, Lavender, Rose, Ocean, Amber, and Graphite. Each has a light variant and a dark variant. `AppSettings.colorScheme` chooses the palette independently from `AppSettings.theme`, which chooses System, Light, or Dark. Both settings are available on the welcome screen and in Settings. Startup reads both before the first Flutter frame.

## Color ownership

| Manifest category | Purpose | Widget roles |
| --- | --- | --- |
| `surfaces` | Canvas, cards, and nested panels | `surface`, `surfaceContainer`, `surfaceContainerHigh` |
| `content` | Reading text, labels, narrator text, hints, and empty states | `onSurface`, `onSurfaceVariant` |
| `accent` | Links, selection indicators, checkboxes, and switches | `primary`, `onPrimary` |
| `boundaries` | Required control outlines and decorative dividers | `outline`, `outlineVariant` |
| `feedback` | Errors and error containers | `error`, `onError`, `errorContainer`, `onErrorContainer` |
| `shared` | Native branding, shadow, scrim, and transparency | Generated constants and native resources |

Generated roles reuse these pairs deliberately. Selected list rows use `primaryContainer` and `onPrimaryContainer`. Bottom navigation uses `secondaryContainer` and `onSecondaryContainer`. Filled buttons use `secondary` and `onSecondary`. The card action strip, snackbars, and tooltips use `inverseSurface` and `onInverseSurface`.

`AppTheme.build(palette, brightness)` owns component themes and state-layer opacity. Widgets consume final semantic roles. The only additional color policy is `AppTheme.unavailableActionForeground`, which keeps tappable unavailable card actions readable against the inverse action strip.

Native splash screens appear before Flutter can read preferences. They use the shared white and black branding pair selected by Android night mode. Launcher artwork also uses static shared branding colors. The runtime logo is a monochrome SVG mask tinted with `onSurface`; its encoded mask fill does not select a rendered color.

## Validation contract

`test/theme_test.dart` checks normal text at 4.5:1 and High contrast text at 7:1. It checks outlines and selected control marks at 3:1. `test/theme_control_contrast_test.dart` also checks unchecked checkbox outlines, off-switch thumbs and boundaries, button focus borders, and keyboard activation of dropdowns across all twenty variants. Unavailable card actions remain tappable, so their labels meet the normal text threshold. These targets follow [WCAG contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html). Decorative dividers use `outlineVariant` and have no required control-boundary threshold.

The matrix covers each palette in both brightness variants, including muted text, links, errors, container pairs, inverse pairs, and unavailable card actions. Widget tests inspect actual reading and action styles. A source-policy test permits raw colors only in the generated catalog and color calculations only in `lib/core/theme`. Preference tests cover persistence, fallback, reset, and independence from brightness.

Capture actual search, filter-sheet, and focused settings screens with cached filter data and telemetry disabled:

```sh
flutter test test/theme_accessibility_capture_test.dart \
  --dart-define=CAPTURE_SCREENSHOTS=true \
  --dart-define=THEME_SCREENSHOT_DIR=/tmp/hadith-themes
```

`test/theme_test.dart` accepts the same flags to capture reading cards. The capture tests load real fonts and write Flutter-rendered PNGs at 390 by 844 pixels. Use the same capture tests and settings in each checkout for before/after comparisons.

These checks establish color contrast for the specified pairs. They do not establish full application accessibility or guarantee comfortable reading on every display.

## Design decision

Two designs were compared: standard Material roles and a categorized `AppColors` extension with a Material adapter. The independent review chose Material roles because current app colors fit them without a second widget vocabulary. The extension design contributed mandatory native generation and the ban on widget-local color calculations. A future domain-specific status may justify a small extension when Material has no suitable role.

The chosen interface hides all twenty palette variants behind `AppTheme.build`. Explicit authored colors avoid SDK-dependent seed palette changes. The generated catalog is larger than a seed-based implementation, while the editable manifest stays compact and categorized.
