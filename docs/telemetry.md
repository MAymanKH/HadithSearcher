# Telemetry

## Configuration and privacy

`lib/core/constants/telemetry_config.dart` contains the public ingestion configuration. Override it at build time with `SENTRY_DSN`, `POSTHOG_PROJECT_TOKEN`, and `POSTHOG_HOST`.

For more details, see the [privacy policy](https://hadith-searcher-privacy-policy.pages.dev).

Release builds use the `production` environment. Debug and profile builds use `development`. Both GitHub and F-Droid use the `foss` flavor.

## Verify delivery

Run consent checks locally:

```sh
flutter test test/telemetry
```

On a disposable Android emulator, run the delivery test. It clears app preferences and uses a local receiver without sending to cloud projects:

```sh
flutter test integration_test/telemetry_test.dart -d emulator-5554 --flavor foss
```

To send a synthetic event to each configured service from Android:

```sh
flutter test integration_test/cloud_telemetry_test.dart -d emulator-5554 --flavor foss --dart-define=VERIFY_TELEMETRY_CLOUD=true
```

Confirm `telemetry_integration_verified` in PostHog with `app_environment=verification`, and `operation=verification.sentry` in Sentry. Passing the test alone does not confirm cloud ingestion.

For an HTTP ingestion check without the Flutter SDKs, run `python3 scripts/verify_telemetry_ingestion.py --send`. This sends synthetic events and checks acceptance responses.
