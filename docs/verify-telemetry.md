# Verify telemetry

Use [Telemetry](telemetry.md) for configuration, consent policy, and event coverage.

## Run local checks

Run the regression tests and static analysis:

```sh
flutter analyze
flutter test test
flutter test test/telemetry/consent_test.dart --dart-define=UPDATE_CHANNEL=github
```

Run the native delivery test on a disposable Android emulator. This test clears the test app's preferences:

```sh
flutter test integration_test/telemetry_test.dart -d emulator-5554 --flavor fdroid
```

The test uses a local HTTP receiver with the real Sentry and PostHog SDKs. It asserts delivery of analytics, handled exceptions, Flutter errors, and platform-dispatcher errors. It also checks scrubbing, consent withdrawal, queue deletion, and a new anonymous identity after consent is restored. It does not send to the configured cloud projects.

## Check cloud delivery

To check whether the default ingestion configuration accepts events, run:

```sh
python3 scripts/verify_telemetry_ingestion.py --send
```

The script sends one synthetic event to each service in the `verification` environment. It checks HTTP response bodies and exits with a failure status if either service rejects the event. It does not exercise the Flutter SDKs or query stored events.

To send a synthetic event to the configured projects, run this test on a disposable emulator:

```sh
flutter test integration_test/cloud_telemetry_test.dart -d emulator-5554 --flavor fdroid --dart-define=VERIFY_TELEMETRY_CLOUD=true
```

In PostHog, check for `telemetry_integration_verified` with `app_environment=verification`. In Sentry, check for `operation=verification.sentry` in the `verification` environment. The test sends through the SDKs, but its assertions do not prove ingestion. Confirm both events in the project dashboards before claiming cloud delivery.
