# Telemetry

## Configuration and privacy

`lib/core/constants/telemetry_config.dart` contains the public ingestion configuration. Override it at build time with `SENTRY_DSN`, `POSTHOG_PROJECT_TOKEN`, and `POSTHOG_HOST`.

For more details, see the [privacy policy](https://hadith-searcher-privacy-policy.pages.dev).

Release builds use the `production` environment. Debug and profile builds use `development`. Both GitHub and F-Droid use the `foss` flavor.

Replay uploads use gzip and send one snapshot per request. On Android 11 or later, the app uses WebP at quality 50 when encoding succeeds and produces a smaller image. Other frames use PNG. Build with `--dart-define=POSTHOG_REPLAY_WEBP=false` to use PNG for every frame.

Build with `--dart-define=POSTHOG_REPLAY_WIFI_ONLY=true` to upload replays only over the active Wi-Fi connection on Android. The app stores pending requests in app-private storage excluded from backups. It queues up to 32 MiB or 1,024 requests, pauses queuing at the limit, and expires pending recordings after 24 hours. Withdrawing analytics consent clears the queue.

## Verify delivery

Run consent checks locally:

```sh
flutter test test/telemetry
```

On a disposable Android emulator, run the delivery test. It clears app preferences and uses a local receiver without sending to cloud projects:

```sh
flutter test integration_test/telemetry_test.dart -d emulator-5554 --flavor foss
```

Measure compressed request sizes and verify that PNG and WebP decode at the same dimensions on an Android 11 or later emulator.

```sh
flutter test integration_test/replay_upload_test.dart -d emulator-5554 --flavor foss
```

To test deferral, turn Wi-Fi off and run the same test with `--dart-define=VERIFY_REPLAY_WIFI_RECONNECT=true`. Turn Wi-Fi on when the test prints `REPLAY_WAITING_FOR_WIFI`.

To send a synthetic event to each configured service from Android:

```sh
flutter test integration_test/cloud_telemetry_test.dart -d emulator-5554 --flavor foss --dart-define=VERIFY_TELEMETRY_CLOUD=true
```

Confirm `telemetry_integration_verified` in PostHog with `app_environment=verification`, and `operation=verification.sentry` in Sentry. Passing the test alone does not confirm cloud ingestion.
