# Architecture

Hadith Searcher is a Flutter app with Android platform code for incoming text shares and distribution updates. [`lib/main.dart`](../lib/main.dart) initializes telemetry, the database, and appearance settings. [`lib/app.dart`](../lib/app.dart) wires the services and view models through Provider. [`StartupFlow`](../lib/views/startup_flow.dart) manages onboarding before the main navigation opens.

## UI and data

| Area | Where to look |
| --- | --- |
| Screens and shared UI | [`lib/views/`](../lib/views/) and [`lib/widgets/`](../lib/widgets/) |
| Search, similar hadiths, favourites, and settings state | [`lib/viewmodels/`](../lib/viewmodels/) |
| Dorar API queries and response mapping | [`ApiService`](../lib/services/api_service.dart) and [`lib/models/`](../lib/models/) |
| Cached filter choices | [`FilterCatalogService`](../lib/services/filter_catalog_service.dart) |
| Saved hadiths and preferences | [`DatabaseService`](../lib/services/database_service.dart) stores saved hadiths in SQLite. [`SettingsService`](../lib/services/settings_service.dart) stores preferences with SharedPreferences. |
| Appearance and translated UI | [`lib/core/theme/`](../lib/core/theme/) and [`lib/l10n/`](../lib/l10n/) |

## Android distribution

The `play` and `foss` flavors share the Dart app and package ID. The native [Play implementation](../android/app/src/play/kotlin/com/moaymandev/hadithsearcher/DistributionUpdates.kt) uses Google Play updates. The Dart [`UpdateService`](../lib/services/update_service.dart) checks GitHub and F-Droid for the FOSS build. GitHub downloads use the device ABI.

The Play build includes Shorebird and starts telemetry automatically. The FOSS build uses the saved onboarding choices for telemetry. See [Publishing](publishing.md) for how the flavors are built and [Telemetry](telemetry.md) for configuration.
