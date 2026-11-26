# Arabic store screenshots

The six 1080 × 1920 PNGs are in [`store/screenshots/ar/phone`](../store/screenshots/ar/phone). Review them in the [gallery](../store/screenshots/ar/index.html). The numbered filenames give the upload order.

## Refresh the UI captures

Use a disposable Android emulator. The capture clears app settings and the database, disables telemetry, and serves repeatable Arabic content from `integration_test/fixtures/store_*.dart`. It captures six dark palettes for the appearance panel.

Use the Medium Phone API 36.1 emulator at its default 1080 × 2400 resolution and
420 dpi. Reset any display overrides before running the capture:

```sh
adb -s emulator-5554 shell wm size reset
adb -s emulator-5554 shell wm density reset
flutter drive --driver=test_driver/store_screenshots.dart \
  --target=integration_test/store_screenshots_test.dart \
  -d emulator-5554 --flavor foss \
  --dart-define=HADITH_API_BASE_URL=http://127.0.0.1:8717
```

Keep that resolution so the complete phone frame fits the artwork. Run on a
dedicated emulator because port 8717 and app data are used by the test.

## Render the store artwork

Requires Python 3 and Chromium. No Python packages are required.

```sh
python3 scripts/generate_store_screenshots.py
# Or choose a browser binary:
python3 scripts/generate_store_screenshots.py --browser /path/to/chromium
```

The generator reads `store/screenshots/ar/sources` and writes the six phone PNGs and the gallery. It also saves editable layouts and a ZIP bundle in `build/store-screenshots`. Review the artwork before uploading it to the Arabic phone listing. To update the Fastlane screenshots, run `python3 scripts/prepare_fdroid.py`.
