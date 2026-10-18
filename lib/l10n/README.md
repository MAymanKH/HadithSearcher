# App translations

`app_ar.arb` and `app_en.arb` contain interface text. API content, including hadiths, explanations, and catalog names, stays in its source language. Arabic is the default interface language.

To add or change interface text:

1. Add the same key to both ARB files. Declare typed placeholders in `app_en.arb` for dynamic values.
2. Run `flutter gen-l10n` to update the generated classes.
3. Read the translation through `context.l10n`. Enum and citation label mappings are in `localization.dart`.
4. Run `flutter test test/localization_test.dart`.

Do not edit the generated `app_localizations*.dart` files directly.
