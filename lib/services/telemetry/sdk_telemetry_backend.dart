import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/telemetry_config.dart' as config;
import 'posthog_analytics.dart';
import 'posthog_replay.dart';
import 'replay_upload_queue.dart';
import 'telemetry_service.dart';

class SdkTelemetryBackend implements TelemetryBackend, TelemetryReplayBackend {
  static const _native = MethodChannel('hadithsearcher/telemetry');
  static const _nativeReplay = MethodChannel('hadithsearcher/replay');
  static const _nativeReplayEncoder = MethodChannel(
    'hadithsearcher/replay_encoder',
  );
  static const _installationIdKey = 'diagnostics_installation_id';
  final String sentryDsn;
  final String posthogToken;
  final String posthogHost;
  final String environment;
  final String distribution;
  final bool replayWebp;
  final bool replayWifiOnly;
  bool _diagnostics = false;
  PostHogAnalytics? _analytics;

  SdkTelemetryBackend({
    this.sentryDsn = config.sentryDsn,
    this.posthogToken = config.posthogProjectToken,
    this.posthogHost = config.posthogHost,
    this.environment = kReleaseMode ? 'production' : 'development',
    this.distribution = config.telemetryDistribution,
    this.replayWebp = config.posthogReplayWebp,
    this.replayWifiOnly = config.posthogReplayWifiOnly,
  });

  @override
  Future<void> setDiagnosticsEnabled(bool enabled) async {
    if (!enabled) {
      _diagnostics = false;
      try {
        if (Sentry.isEnabled) {
          try {
            await _native.invokeMethod<void>('prepareDiagnosticsShutdown');
          } finally {
            await Sentry.close();
          }
        }
      } finally {
        try {
          await _native.invokeMethod<void>('clearDiagnosticsCache');
        } finally {
          final preferences = await SharedPreferences.getInstance();
          if (!await preferences.remove(_installationIdKey)) {
            throw StateError('Could not clear diagnostics installation ID');
          }
        }
      }
      return;
    }
    if (_diagnostics) return;
    if (sentryDsn.isEmpty) throw StateError('SENTRY_DSN is empty');
    final package = await PackageInfo.fromPlatform();
    final preferences = await SharedPreferences.getInstance();
    var installationId = preferences.getString(_installationIdKey);
    if (installationId == null) {
      installationId = const Uuid().v4();
      if (!await preferences.setString(_installationIdKey, installationId)) {
        throw StateError('Could not save diagnostics installation ID');
      }
    }
    final diagnosticUserId = installationId;
    try {
      await SentryFlutter.init((options) {
        options
          ..dsn = sentryDsn
          ..release =
              '${package.packageName}@${package.version}+${package.buildNumber}'
          ..environment = environment
          ..sendDefaultPii = false
          ..tracesSampleRate = 1.0
          ..enableAutoPerformanceTracing = false
          ..enableAutoNativeBreadcrumbs = false
          ..enablePrintBreadcrumbs = false
          ..attachScreenshot = false
          ..enableLogs = false;
        options.beforeSend = (event, hint) => _diagnostics
            ? scrubError(event, installationId: diagnosticUserId)
            : null;
        options.beforeSendTransaction = (event, hint) =>
            _diagnostics ? event : null;
        options.replay.sessionSampleRate = 0;
        options.replay.onErrorSampleRate = 0;
      });
      await _native.invokeMethod<void>('configureDiagnosticsPrivacy', {
        'installationId': diagnosticUserId,
        'distribution': distribution,
      });
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

  static SentryEvent scrubError(SentryEvent event, {String? installationId}) {
    event.user = installationId == null ? null : SentryUser(id: installationId);
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
      final analytics = _analytics;
      _analytics = null;
      try {
        if (analytics == null) {
          await PostHogAnalytics.clearStored(
            await SharedPreferences.getInstance(),
          );
        } else {
          await analytics.stop();
        }
      } finally {
        try {
          if (defaultTargetPlatform == TargetPlatform.android) {
            await _nativeReplay.invokeMethod<void>('clearQueue');
          }
        } finally {
          await _clearLegacyAnalytics();
        }
      }
      return;
    }
    if (_analytics != null) return;
    final host = Uri.tryParse(posthogHost);
    final local = host?.scheme == 'http' && host?.host == '127.0.0.1';
    if (posthogToken.isEmpty ||
        host == null ||
        host.host.isEmpty ||
        host.userInfo.isNotEmpty ||
        host.hasQuery ||
        host.hasFragment ||
        (host.scheme != 'https' && !local)) {
      throw StateError('Invalid PostHog ingestion configuration');
    }
    final package = await PackageInfo.fromPlatform();
    final android = defaultTargetPlatform == TargetPlatform.android
        ? await _native.invokeMapMethod<String, String>(
            'analyticsDeviceContext',
            {'projectToken': posthogToken},
          )
        : null;
    final queuePath =
        replayWifiOnly && defaultTargetPlatform == TargetPlatform.android
        ? await _nativeReplay.invokeMethod<String>('queuePath') ??
              (throw StateError('Could not locate replay upload queue'))
        : null;
    final replayEndpoint = PostHogReplay.endpoint(host, 's/').toString();
    final analytics = PostHogAnalytics(
      preferences: await SharedPreferences.getInstance(),
      token: posthogToken,
      host: host,
      createReplay: (id) => PostHogReplay(
        posthogToken,
        host,
        encodeWebp:
            replayWebp && defaultTargetPlatform == TargetPlatform.android
            ? (png) => _nativeReplayEncoder.invokeMethod<Uint8List>(
                'encodeWebp',
                png,
              )
            : null,
        wifiQueue: queuePath == null
            ? null
            : ReplayUploadQueue(
                path: queuePath,
                scope: jsonEncode([replayEndpoint, posthogToken, id]),
                upload: (body) => _nativeReplay.invokeMethod<int>(
                  'uploadOnWifi',
                  {'endpoint': replayEndpoint, 'body': body},
                ),
                cancelUpload: () =>
                    _nativeReplay.invokeMethod<void>('cancelUpload'),
              ),
      ),
      context: {
        'app_environment': environment,
        'app_distribution': distribution,
        r'$app_name': package.appName,
        r'$app_namespace': package.packageName,
        r'$app_version': package.version,
        r'$app_build': int.tryParse(package.buildNumber) ?? package.buildNumber,
        r'$lib': 'hadithsearcher-dart',
        r'$lib_version': package.version,
        if (android?['deviceType'] case final String value)
          r'$device_type': value,
        if (android?['osVersion'] case final String value) ...{
          r'$os': 'Android',
          r'$os_version': value,
        },
      },
    );
    await analytics.start(previousId: android?['previousId']);
    _analytics = analytics;
    await _clearLegacyAnalytics();
  }

  Future<void> _clearLegacyAnalytics() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _native.invokeMethod<void>('clearLegacyAnalytics', {
        'projectToken': posthogToken,
      });
    }
  }

  @override
  Future<void> capture(String event, Map<String, Object> properties) async {
    await _analytics?.capture(event, properties);
  }

  @override
  Future<String?> analyticsId() async => _analytics?.distinctId;

  Future<void> flushAnalytics() async => _analytics?.flush();

  @override
  Future<void> captureReplay(
    CaptureReplayFrame captureFrame,
    Offset? tap,
  ) async {
    await _analytics?.captureReplay(captureFrame, tap);
  }

  @override
  Future<void> report(
    Object error,
    StackTrace stack,
    String operation, {
    Map<String, Object> details = const {},
  }) async {
    if (!_diagnostics) return;
    await Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) async {
        scope.setTag('operation', operation);
        scope.fingerprint = [operation, error.runtimeType.toString()];
        if (details.isNotEmpty) await scope.setContexts('failure', details);
      },
    );
  }

  @override
  Future<T> trace<T>(String operation, Future<T> Function() action) async {
    if (!_diagnostics) return action();
    final transaction = Sentry.startTransaction(operation, 'app.operation');
    try {
      final result = await action();
      transaction.status = const SpanStatus.ok();
      return result;
    } catch (_) {
      transaction.status = const SpanStatus.internalError();
      rethrow;
    } finally {
      try {
        await transaction.finish();
      } catch (_) {
        // Reporting must not change the result of the operation.
      }
    }
  }
}
