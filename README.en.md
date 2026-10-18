<div align="center">
<img src="assets/icons/logo_readme.svg" width="200" alt="Hadith Searcher">

# Hadith Searcher

English | [العربية](README.md)

Search prophetic hadiths, read explanations, and check scholars' authenticity assessments.

<a href="https://play.google.com/store/apps/details?id=com.moaymandev.hadithsearcher"><img alt="Get it on Google Play" src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" height="80"/></a>

</div>

## About the app

Hadith Searcher is a free, open-source Android app built with Flutter. It brings together hadith texts, explanations, sources, and scholars' assessments from Dorar al-Saniyyah.

## Features

- Search for any word, all words, or an exact phrase. Choose the search scope and exclude words or phrases.
- View the narrator, source, scholar, authenticity assessment, source references, and related original narrations.
- Read hadith explanations and find similar hadiths.
- Filter results by authenticity grade, scholar, book, or narrator.
- Save hadiths for offline reading.
- Customize hadith font size, font family, and app colors.

## Screenshots

<div align="center">

| Search | Advanced search |
|:---:|:---:|
| <img src="store/screenshots/ar/phone/01-search.png" width="250" alt="Hadith search"> | <img src="store/screenshots/ar/phone/02-filters.png" width="250" alt="Advanced search filters"> |

| Original narrations | Saved hadiths |
|:---:|:---:|
| <img src="store/screenshots/ar/phone/03-origins.png" width="250" alt="Original hadith narrations"> | <img src="store/screenshots/ar/phone/04-saved.png" width="250" alt="Saved hadiths"> |

| Appearance | Scholar and book details |
|:---:|:---:|
| <img src="store/screenshots/ar/phone/05-appearance.png" width="250" alt="App appearance settings"> | <img src="store/screenshots/ar/phone/06-sources.png" width="250" alt="Scholar and book information"> |

</div>

See the [store screenshot guide](store/screenshots/README.md) for screenshot designs and update instructions.

## Data sources

Hadiths and related information come from [Dorar al-Saniyyah](https://dorar.net/) through the [Dorar Hadith API](https://github.com/MAymanKH/dorar-hadith-api).

## Requirements

- Flutter `3.47.0` or later, with Dart `>=3.12.0 <4.0.0`, as specified in `pubspec.yaml`.
- Android SDK platform `37` and NDK `29.0.13113456`, as specified in `android/app/build.gradle.kts`.
- A JDK compatible with Gradle. You can use the JDK bundled with Android Studio.
- An Android emulator or physical device.
- Python 3 for the release and color generation scripts.

## Set up and run

### 1. Clone the repository

```bash
git clone https://github.com/MAymanKH/HadithSearcher.git
cd HadithSearcher
```

### 2. Configure services

The default API URL is in `lib/core/constants/app_config.dart`. Public Sentry and PostHog ingestion settings are in `lib/core/constants/telemetry_config.dart`. Builds do not require a `.env` file. Keep account administration tokens and private signing credentials out of source files.

To use another API server, pass `--dart-define=HADITH_API_BASE_URL=https://your-api.example` to the run or build command.

Play builds enable crash reports and usage analytics automatically. F-Droid and GitHub builds request separate consent for each service. See [Telemetry](docs/telemetry.md) for configuration, privacy details, and delivery checks.

### 3. Install dependencies

```bash
flutter doctor
flutter pub get
```

### 4. Run the app

```bash
flutter run --flavor fdroid
```

To run the Google Play flavor:

```bash
flutter run --flavor play
```

## Build Android releases

Update `version` in `pubspec.yaml` once for each new release. The About page displays the actual app version.

The release script requires Python 3 and Flutter. Play releases also require Shorebird and a prior login with `shorebird login`. The script uses Flutter `3.47.7` through Shorebird for Play releases.

For Play and GitHub releases, prepare `android/key.properties` and a local signing keystore. The properties file must contain `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. Relative keystore paths resolve from `android/app/`. Keep signing credentials out of version control.

GitHub releases also require `android/local.properties` with `sdk.dir` and Android SDK Build Tools containing `apksigner` and `zipalign`.

| Command | Result |
| --- | --- |
| `./scripts/release.py play` | Build a Google Play AAB and register the release with Shorebird. |
| `./scripts/release.py fdroid` | Build an unsigned F-Droid APK. |
| `./scripts/release.py github` | Build and sign an APK for direct installation. |
| `./scripts/release.py all` | Build F-Droid, GitHub, and Google Play releases in sequence. |
| `./scripts/release.py play --dry-run` | Build the Play bundle without registering a release with Shorebird. |
| `./scripts/release.py patch-play` | Send a Dart update for the Play release version currently specified in `pubspec.yaml`. |

Artifacts are saved in `build/releases/play/`, `build/releases/fdroid/`, and `build/releases/github/`, with the version in each filename. The script does not upload artifacts to Google Play, F-Droid, or GitHub.

Play builds use an isolated workspace under `build/hadith-play-*` to avoid system temporary filesystem quotas. Keep several GiB free on the project filesystem. The script removes the workspace after success or failure. If Play fails after the APKs finish, retry with `./scripts/release.py play`.

Android builds use one Gradle worker and compile Kotlin in the Gradle JVM with a 2 GiB heap limit. Gradle exits after each build to release memory between release steps. These settings reduce memory use at the cost of build speed. If the Gradle daemon disappears, check the system journal for memory pressure or processes terminated by the system.

The F-Droid flavor excludes the Shorebird updater and Google Play update library. To build it directly:

```bash
flutter build apk --release --flavor fdroid
```

The output is `build/app/outputs/flutter-apk/app-fdroid-release.apk`. This APK is unsigned and cannot be installed directly. F-Droid signs it for distribution.

For direct installation, use `./scripts/release.py github`. This command builds from source using the F-Droid flavor, selects the GitHub update channel, and signs the APK. It does not require an existing F-Droid build. The signed output is `build/releases/github/HadithSearcher-<version>-github.apk`, and the script verifies its signature.

App updates require the same signing key. Published Google Play and F-Droid versions may use different signing keys from your local build.

## Verify the project

Run static analysis, unit and widget tests, and the release script tests:

```bash
flutter analyze
flutter test test
python3 -m unittest discover -s test -p release_update_channel_test.py
```

To check search and source details against the live API:

```bash
flutter test test/hadith_details_live_test.dart --dart-define=VERIFY_LIVE_DETAILS=true
flutter test test/filter_catalog_live_test.dart --dart-define=VERIFY_LIVE_FILTERS=true
```

The following integration test starts a local fixture server and clears app preferences on the emulator. Use a disposable emulator and replace `emulator-5554` with its device ID. Screenshots are saved in `build/api-capabilities`.

```bash
flutter drive --driver=test_driver/api_capabilities.dart \
  --target=integration_test/api_capabilities_test.dart \
  -d emulator-5554 --flavor fdroid \
  --dart-define=HADITH_API_BASE_URL=http://127.0.0.1:8717 \
  --dart-define=API_SCREENSHOTS=true
```

## Development guides

- [Interface localization and text](lib/l10n/README.md)
- [Change colors and generate theme files](docs/change-colors.md)
- [Telemetry and privacy](docs/telemetry.md)
- [Store screenshots](store/screenshots/README.md)

## License

This project is free and open-source software licensed under the [GNU General Public License v3.0](LICENSE).
