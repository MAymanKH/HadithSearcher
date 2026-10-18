# Arabic store screenshots

Six 1080 × 1920 RGB PNGs for the Android phone listing are in
[`ar/phone`](ar/phone). Open [`ar/index.html`](ar/index.html) to review the set.
The numbered filenames define the upload order. No store listing is changed by
these scripts.

The artwork uses the current Flutter UI, the app's monochrome palette, its logo,
and the bundled Cairo typeface. Headings and descriptions remain editable in
`scripts/generate_store_screenshots.py`. The source captures are retained in
`ar/sources` without retouching. Google Play's current [screenshot guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)
recommends portrait 9:16 images at a minimum of 1080 × 1920.

## Refresh the UI captures

Use a disposable Android emulator. This capture test clears the app's settings
and database on the selected device. It disables telemetry and uses a local HTTP
fixture for repeatable content, based on the intentions hadith from the existing
hadith card integration test. These are real app screens with controlled sample data,
not screenshots of live search results.

```sh
flutter drive --driver=test_driver/store_screenshots.dart \
  --target=integration_test/store_screenshots_test.dart \
  -d emulator-5554 --flavor fdroid \
  --dart-define=HADITH_API_BASE_URL=http://127.0.0.1:8717
```

The captures were made with the Medium Phone API 36.1 emulator at its default
1080 × 2400 resolution and 420 dpi. Keep that resolution for the complete phone
frame to fit the artwork. Run on a dedicated emulator because port 8717 and app
data are used by the test.

## Render the store artwork

Requires Python 3 and Chromium. No Python packages are required.

```sh
python3 scripts/generate_store_screenshots.py
# Or choose a browser binary:
python3 scripts/generate_store_screenshots.py --browser /path/to/chromium
```

The generator writes the six phone PNGs and the gallery, saves self-contained
editable HTML layouts and a ZIP bundle in `build/store-screenshots`, and checks
each export's size, PNG bit depth, and RGB color type. It leaves the source captures intact.
Upload the artwork to the Arabic phone listing after reviewing it. The original
captures can also be used where a store wants screenshots without promotional
text. This repository currently targets Android; no iPhone frames are included.
