# Set up and verify the app

## Set up Android development

Install the Flutter version in [`.flutter-version`](../.flutter-version) for release parity. For local development, see the Dart and Flutter constraints in [`pubspec.yaml`](../pubspec.yaml). Install Android SDK platform 37 and NDK `29.0.13113456` as specified in [`android/app/build.gradle.kts`](../android/app/build.gradle.kts). Use a Gradle-compatible JDK and an Android emulator or physical device. The release and verification scripts require Python 3.

```sh
git clone https://github.com/MAymanKH/HadithSearcher.git
cd HadithSearcher
flutter doctor
flutter pub get
flutter run --flavor foss
```

Run `flutter run --flavor play` to develop against the Google Play flavor.

The app has default API and public telemetry settings. To use another API, add `--dart-define=HADITH_API_BASE_URL=https://your-api.example` to the run or build command. See [Telemetry](telemetry.md) for overrides. Keep private signing credentials and account administration tokens outside tracked files.

## Run the checks

```sh
flutter analyze
flutter test test
python3 -m unittest discover -s test -p '*_test.py'
```

To verify the live API contract, run the opt-in tests:

```sh
flutter test test/hadith_details_live_test.dart --dart-define=VERIFY_LIVE_DETAILS=true
flutter test test/filter_catalog_live_test.dart --dart-define=VERIFY_LIVE_FILTERS=true
```

For an end-to-end check of advanced filters and source details, use a disposable emulator. The test clears app preferences and runs a local fixture server. Replace `emulator-5554` with the target device ID.

```sh
flutter drive --driver=test_driver/api_capabilities.dart \
  --target=integration_test/api_capabilities_test.dart \
  -d emulator-5554 --flavor foss \
  --dart-define=HADITH_API_BASE_URL=http://127.0.0.1:8717
```
