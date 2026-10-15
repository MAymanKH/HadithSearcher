# App translations

`app_en.arb` and `app_ar.arb` contain app-owned UI text. Flutter generates the typed `AppLocalizations` classes from these catalogs with `flutter gen-l10n`. `l10n.yaml` configures generation.

Widgets read translations through `context.l10n`. `localization.dart` also maps theme, font weight, search enums, and citation labels to catalog entries. Whole messages use typed placeholders so each language controls word order.

API content remains in its source language, including hadiths, explanations, grades, and catalog names. Only the app's surrounding labels are translated. Saved Arabic citation formats and legacy search preference values remain unchanged for compatibility. `localizedError` translates exact app-owned service errors at the presentation boundary.

`SettingsService` stores `language` as `ar` or `en` and records `welcomeCompleted` separately from telemetry consent. Arabic is the default. `HadithSearcherApp` waits for preferences, shows welcome until completion, then checks the existing telemetry policy. F-Droid and GitHub builds require a consent choice. Play builds open search directly.

To add or change UI text:

1. Add the same descriptive key to both ARB files.
2. For dynamic values, declare typed placeholders in `app_en.arb`.
3. Run `flutter gen-l10n`.
4. Use the generated getter or method through `context.l10n`.
5. Run `flutter test test/localization_test.dart`.

The tests check catalog parity, build-policy routing, preference persistence, text direction, API content preservation, and welcome layouts. To render welcome screenshots, run `flutter test --dart-define=CAPTURE_SCREENSHOTS=true test/localization_test.dart`. Images are written to `build/localization`.
