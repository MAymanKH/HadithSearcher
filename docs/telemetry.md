# Telemetry

## Configuration and privacy

`lib/core/constants/telemetry_config.dart` contains the public ingestion configuration. Override it at build time with `SENTRY_DSN`, `POSTHOG_PROJECT_TOKEN`, and `POSTHOG_HOST`.

Play builds enable crash reports and usage analytics automatically. FOSS builds preselect both options on first launch and apply the selections only after Continue. Either option can be unchecked. In those builds, users can change consent in Settings. SDK errors do not block searching.

Sentry collects errors and samples manual API and database transactions at 5%. Error processing removes messages, identity, requests, and breadcrumbs. PostHog records app interactions and operation outcomes without person profiles. Session replay and screenshots are disabled.

Release builds use the `production` environment. Debug and profile builds use `development`. Both GitHub and F-Droid use the `foss` flavor.

## Verify delivery

Run consent checks locally:

```sh
flutter test test/telemetry
```

On a disposable Android emulator, run the native SDK delivery test. It clears app preferences and uses a local receiver without sending to cloud projects:

```sh
flutter test integration_test/telemetry_test.dart -d emulator-5554 --flavor foss
```

To send a synthetic event to each configured service through the Flutter SDKs:

```sh
flutter test integration_test/cloud_telemetry_test.dart -d emulator-5554 --flavor foss --dart-define=VERIFY_TELEMETRY_CLOUD=true
```

Confirm `telemetry_integration_verified` in PostHog with `app_environment=verification`, and `operation=verification.sentry` in Sentry. Passing the test alone does not confirm cloud ingestion.

For an HTTP ingestion check without the Flutter SDKs, run `python3 scripts/verify_telemetry_ingestion.py --send`. This sends synthetic events and checks acceptance responses.
