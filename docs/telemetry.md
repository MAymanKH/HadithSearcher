# Telemetry

## Configuration and consent

`lib/core/constants/telemetry_config.dart` supplies the public ingestion configuration. Build overrides are `SENTRY_DSN`, `POSTHOG_PROJECT_TOKEN`, and `POSTHOG_HOST`. An empty override reports a setup error instead of silently skipping the SDK.

Play builds enable diagnostics and analytics automatically. F-Droid and GitHub builds require separate choices for each service. Withdrawal blocks app events immediately, attempts to stop each SDK independently, and persists the choice even if an SDK shutdown fails. SDK errors do not block searching.

Release builds use the `production` environment. Debug and profile builds use `development`. Distribution values are `play`, `fdroid`, and `github`. GitHub builds select their distribution through `--dart-define=UPDATE_CHANNEL=github`.

## Coverage

Sentry handles Flutter framework errors, uncaught errors on the main isolate, and native crashes after diagnostics initialization. Handled failures in API requests, favourites, offline detail storage, settings, and update checks report an operation tag. Errors returned by a background computation reach the calling service through its future.

Sentry removes exception messages, user identity, requests, breadcrumbs, extra data, and Flutter error details from Dart error events. Native error processing removes messages, requests, identity, and breadcrumbs. Session replay and screenshots are disabled. Manual API and database transactions use a 5% sample rate.

PostHog records main-tab screens, welcome, privacy, and similar-hadith screens, search and API outcomes, favourite changes, sharing, appearance changes, language changes, and settings resets. Explanation, alternate-hadith, and source-detail opening events also cover cached content. App navigation uses the custom `screen_viewed` event, not PostHog's `$screen` event. Automatic lifecycle events, error tracking, session replay, surveys, and person profiles are disabled.

See [Verify telemetry](verify-telemetry.md) for local and cloud checks.
