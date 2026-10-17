# Dropdown experiments

A separate Flutter entry point for comparing three dropdown and selection-sheet styles against the current controls. Production widgets are unchanged.

- **Outlined:** outlined fields, divided choice rows, and a checkmark for single selection.
- **Soft:** filled fields and an inset list with outlined selected rows.
- **Compact:** underlined fields and a floating sheet with leading selection controls.

Run on a configured Flutter device:

```sh
flutter run -d <device-id> -t tool/dropdown_lab/main.dart
```

The toolbar switches style, language, brightness, and palette. Search mode uses immediate single selection. Books supports search and multiple selection. In the new prototypes, Apply saves the book selection; closing or dismissing the sheet discards edits. The current-style book sheet is a visual baseline using the existing sheet and row widgets, not the full production search picker.

Rebuild the portable comparison gallery:

```sh
flutter test test/dropdown_lab_test.dart --dart-define=CAPTURE_SCREENSHOTS=true
python3 tool/dropdown_lab/gallery.py
```

Open `build/dropdown-lab/index.html`. It includes the rendered Flutter screens for Arabic light, dark, forest, English light, and a 320 px screen with 2× text. Choose fields, single choice, or searchable multi-select. Enable the current style for comparison, or enlarge a screen to inspect it.

The tests exercise single selection, filtering, applying multiple selections, and discarding edits. They also capture layouts and fail on Flutter rendering exceptions. Generated captures and the gallery stay under the ignored build directory.
