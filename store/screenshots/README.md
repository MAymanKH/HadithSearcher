# Arabic store screenshots

Six 1080 × 1920 RGB PNGs for the Android phone listing are in
[`ar/phone`](ar/phone). Open [`ar/index.html`](ar/index.html) to review the set.
The numbered filenames define the upload order. No store listing is changed by
these scripts.

The artwork uses a charcoal background with a soft gray curve, dark mode, a
single large heading, and 20:9 phone captures. The compositions alternate phone
angles, centered and offset placement, top and bottom headings, and curved
background shapes within the same charcoal palette.
Headings and layouts remain editable in `scripts/generate_store_screenshots.py`.
The customization panel combines six diagonal sections from real Sepia, Forest,
Ocean, Lavender, Rose, and Amber captures, in that order. The source images are retained in
`ar/sources` without retouching. Google Play's [screenshot guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)
recommends portrait 9:16 images at a minimum of 1080 × 1920.

## Refresh the UI captures

Use a disposable Android emulator. This capture test clears the app's settings
and database on the selected device. It disables telemetry and uses a local HTTP
fixture for repeatable content. `integration_test/fixtures/store_hadiths.dart`
contains the first eight results of the app API's [search for الأعمال بالنيات](https://hadith-searcher-dorar-api-amx.vercel.app/v1/site/hadith/search?value=%D8%A7%D9%84%D8%A3%D8%B9%D9%85%D8%A7%D9%84%20%D8%A8%D8%A7%D9%84%D9%86%D9%8A%D8%A7%D8%AA&page=1&st=a&t=*),
including the source's text, grading, and citations. Search contains the eight-item list. Saved hadiths use four distinct texts,
including «الكلمة الطيبة صدقة» and «من لا يرحم لا يرحم». These are real app screens with replayed API
data. The capture records six dark palettes for customization. The third panel
opens «أصول الحديث وطرق إخراجه» from the first result and displays the original
source text and transmission chains. The sixth panel opens «معلومات المحدث
والكتاب» and shows both the scholar biography and book details.
`integration_test/fixtures/store_sources.dart` retains complete API responses for
[the hadith's origins](https://hadith-searcher-dorar-api-amx.vercel.app/v1/site/hadith/usul/JIDbtVSz),
[الزرقاني](https://hadith-searcher-dorar-api-amx.vercel.app/v1/site/mohdith/1122), and
[مختصر المقاصد](https://hadith-searcher-dorar-api-amx.vercel.app/v1/site/book/3664).
`integration_test/fixtures/store_collections.dart` retains the saved-hadith samples
fetched with these search phrases: «الكلمة الطيبة صدقة», «من لا يرحم لا يرحم»,
«إن الله جميل يحب الجمال», and «الدين النصيحة».
The advanced-filter capture has an empty search field.

Use the Medium Phone API 36.1 emulator at its default 1080 × 2400 resolution and
420 dpi. Reset any display overrides before running the capture:

```sh
adb -s emulator-5554 shell wm size reset
adb -s emulator-5554 shell wm density reset
flutter drive --driver=test_driver/store_screenshots.dart \
  --target=integration_test/store_screenshots_test.dart \
  -d emulator-5554 --flavor fdroid \
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

The generator writes the six phone PNGs and the gallery, saves self-contained
editable HTML layouts and a ZIP bundle in `build/store-screenshots`, and checks
each export's size, PNG bit depth, and RGB color type. It leaves the source captures intact.
Upload the artwork to the Arabic phone listing after reviewing it. The original
captures can also be used where a store wants screenshots without promotional
text. This repository currently targets Android; no iPhone frames are included.
