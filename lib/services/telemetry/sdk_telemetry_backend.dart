import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/constants/telemetry_config.dart' as config;
import 'telemetry_service.dart';

class SdkTelemetryBackend implements TelemetryBackend {
  static const _native = MethodChannel('hadithsearcher/telemetry');
  final String sentryDsn;
  final String posthogToken;
  final String posthogHost;
  final String environment;
  final String distribution;
  bool _diagnostics = false;
  bool _analytics = false;

  SdkTelemetryBackend({
    this.sentryDsn = config.sentryDsn,
    this.posthogToken = config.posthogProjectToken,
    this.posthogHost = config.posthogHost,
    this.environment = kReleaseMode ? 'production' : 'development',
    this.distribution = config.telemetryDistribution,
  });

  @override
  Future<void> setDiagnosticsEnabled(bool enabled) async {
    if (!enabled) {
      _diagnostics = false;
      if (Sentry.isEnabled) {
        await _native.invokeMethod<void>('prepareDiagnosticsShutdown');
        await Sentry.close();
      }
      await _native.invokeMethod<void>('clearDiagnosticsCache');
      return;
    }
    if (_diagnostics) return;
    if (sentryDsn.isEmpty) throw StateError('SENTRY_DSN is empty');
    final package = await PackageInfo.fromPlatform();
    try {
      await SentryFlutter.init((options) {
        options
          ..dsn = sentryDsn
          ..release =
              '${package.packageName}@${package.version}+${package.buildNumber}'
          ..environment = environment
          ..sendDefaultPii = false
          ..tracesSampleRate = 0.05
          ..enableAutoPerformanceTracing = false
          ..enableAutoNativeBreadcrumbs = false
          ..enablePrintBreadcrumbs = false
          ..attachScreenshot = false
          ..enableLogs = false;
        options.beforeSend = (event, hint) =>
            _diagnostics ? scrubError(event) : null;
        options.beforeSendTransaction = (event, hint) =>
            _diagnostics ? event : null;
        options.replay.sessionSampleRate = 0;
        options.replay.onErrorSampleRate = 0;
      });
      await _native.invokeMethod<void>('configureDiagnosticsPrivacy');
      await Sentry.configureScope(
        (scope) => scope.setTag('distribution', distribution),
      );
      _diagnostics = true;
    } catch (_) {
      _diagnostics = false;
      await Sentry.close();
      rethrow;
    }
  }

  static SentryEvent scrubError(SentryEvent event) {
    event.user = null;
    event.request = null;
    event.message = null;
    event.breadcrumbs = null;
    event.contexts.remove('flutter_error_details');
    for (final exception in event.exceptions ?? <SentryException>[]) {
      exception.value = exception.type;
    }
    return SentryEvent.fromJson(event.toJson()..remove('extra'));
  }

  @override
  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (!enabled) {
      if (!_analytics) {
        await _clearAnalyticsCache();
        return;
      }
      _analytics = false;
      await Posthog().optOut();
      await _clearAnalyticsCache(clearIdentity: false);
      await Posthog().close();
      await _clearAnalyticsCache();
      return;
    }
    if (_analytics) return;
    if (posthogToken.isEmpty || posthogHost.isEmpty) {
      throw StateError('PostHog project token or host is empty');
    }
    final config = PostHogConfig(posthogToken)
      ..host = posthogHost
      ..captureApplicationLifecycleEvents = false
      ..preloadFeatureFlags = false
      ..sendFeatureFlagEvent = false
      ..personProfiles = PostHogPersonProfiles.never
      ..sessionReplay = false
      ..surveys = false
      ..capturePushNotificationSubscriptions = false
      ..capturePushNotificationOpened = false
      ..maxQueueSize = 200
      ..flushAt = 20
      ..flushInterval = const Duration(seconds: 60)
      ..beforeSend = [(event) => _analytics ? event : null];
    config.errorTrackingConfig.captureFlutterErrors = false;
    config.errorTrackingConfig.capturePlatformDispatcherErrors = false;
    config.errorTrackingConfig.captureIsolateErrors = false;
    config.errorTrackingConfig.captureNativeExceptions = false;
    config.errorTrackingConfig.captureNativeCrashes = false;
    config.logsConfig.beforeSend = [(record) => null];
    _analytics = true;
    try {
      await Posthog().setup(config);
      await Posthog().optIn();
    } catch (_) {
      await setAnalyticsEnabled(false);
      rethrow;
    }
  }

  Future<void> _clearAnalyticsCache({bool clearIdentity = true}) =>
      _native.invokeMethod<void>('clearAnalyticsCache', {
        'projectToken': posthogToken,
        'clearIdentity': clearIdentity,
      });

  @override
  Future<void> capture(String event, Map<String, Object> properties) async {
    if (!_analytics) return;
    await Posthog().capture(
      eventName: event,
      properties: {
        ...properties,
        'app_environment': environment,
        'app_distribution': distribution,
        '\$geoip_disable': true,
      },
    );
  }

  @override
  Future<String?> analyticsId() async {
    if (!_analytics) return null;
    return Posthog().getDistinctId();
  }

  @override
  Future<void> report(Object error, StackTrace stack, String operation) async {
    if (!_diagnostics) return;
    await Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) {
        scope.setTag('operation', operation);
        scope.fingerprint = [operation, error.runtimeType.toString()];
      },
    );
  }

  @override
  Future<T> trace<T>(String operation, Future<T> Function() action) async {
    if (!_diagnostics) return action();
    final transaction = Sentry.startTransaction(operation, 'app.operation');
    try {
      return await action();
    } finally {
      try {
        await transaction.finish();
      } catch (_) {
        // Reporting must not change the result of the operation.
      }
    }
  }
}
