import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TelemetryPolicy { optIn, alwaysOn }

const buildTelemetryPolicy = appFlavor == 'play'
    ? TelemetryPolicy.alwaysOn
    : TelemetryPolicy.optIn;

class TelemetryConsent {
  final bool decided;
  final bool diagnostics;
  final bool analytics;
  final bool analyticsScopeCurrent;

  const TelemetryConsent({
    this.decided = false,
    this.diagnostics = false,
    this.analytics = false,
    this.analyticsScopeCurrent = true,
  });

  static TelemetryConsent read(Object? value) {
    if (value is! String) return const TelemetryConsent();
    try {
      final data = jsonDecode(value);
      if (data is! Map ||
          (data['version'] != 1 && data['version'] != 2) ||
          data['decided'] != true) {
        return const TelemetryConsent();
      }
      return TelemetryConsent(
        decided: true,
        diagnostics: data['diagnostics'] == true,
        analytics: data['analytics'] == true,
        analyticsScopeCurrent: data['version'] == 2,
      );
    } on FormatException {
      return const TelemetryConsent();
    }
  }

  String encode() => jsonEncode({
    'version': 2,
    'decided': decided,
    'diagnostics': diagnostics,
    'analytics': analytics,
  });
}

abstract class TelemetryBackend {
  Future<void> setDiagnosticsEnabled(bool enabled);
  Future<void> setAnalyticsEnabled(bool enabled);
  Future<void> capture(String event, Map<String, Object> properties);
  Future<void> report(
    Object error,
    StackTrace stack,
    String operation, {
    Map<String, Object> details = const {},
  });
  Future<T> trace<T>(String operation, Future<T> Function() action);
  Future<String?> analyticsId();
}

abstract interface class TelemetryReplayBackend {
  Future<void> captureReplay(Size size, List<Rect> controls, Offset? tap);
}

class TelemetryService extends ChangeNotifier {
  static const consentKey = 'telemetry_consent_v1';
  static TelemetryService? instance;

  final SharedPreferences preferences;
  final TelemetryBackend backend;
  final TelemetryPolicy policy;
  TelemetryConsent _consent;
  bool _saving = false;
  String? _error;

  TelemetryService({
    required this.preferences,
    required this.backend,
    this.policy = TelemetryPolicy.optIn,
  }) : _consent = TelemetryConsent.read(preferences.get(consentKey));

  TelemetryConsent get consent => _consent;
  bool get canChangeConsent => policy == TelemetryPolicy.optIn;
  bool get _needsAnalyticsRenewal =>
      canChangeConsent && _consent.analytics && !_consent.analyticsScopeCurrent;
  bool get needsConsent =>
      canChangeConsent && (!_consent.decided || _needsAnalyticsRenewal);
  bool get analyticsEnabled =>
      !canChangeConsent || (_consent.analytics && !_needsAnalyticsRenewal);
  bool get diagnosticsEnabled => !canChangeConsent || _consent.diagnostics;
  bool get replayEnabled =>
      analyticsEnabled && backend is TelemetryReplayBackend;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> initialize() async {
    await _configure();
  }

  Future<bool> save({
    required bool diagnostics,
    required bool analytics,
  }) async {
    if (!canChangeConsent || _saving) return false;
    _saving = true;
    _error = null;
    final previous = _consent;
    // Withdraw immediately, including while persistence or SDK calls are pending.
    _consent = TelemetryConsent(
      decided: previous.decided,
      diagnostics: previous.diagnostics && diagnostics,
      analytics: previous.analytics && analytics,
      analyticsScopeCurrent: previous.analyticsScopeCurrent,
    );
    notifyListeners();
    try {
      // A failing SDK must not prevent the other SDK from stopping or leave
      // consent enabled on the next launch.
      if (!analytics) {
        try {
          await backend.setAnalyticsEnabled(false);
        } catch (_) {
          _error = 'تعذر تشغيل إحصاءات الاستخدام حالياً.';
        }
      }
      if (!diagnostics) {
        try {
          await backend.setDiagnosticsEnabled(false);
        } catch (_) {
          _error = 'تعذر تشغيل تقارير الأعطال حالياً.';
        }
      }
      final next = TelemetryConsent(
        decided: true,
        diagnostics: diagnostics,
        analytics: analytics,
      );
      if (!await preferences.setString(consentKey, next.encode())) {
        throw StateError('Consent could not be saved');
      }
      _consent = next;
      await _configure();
      return _error == null;
    } catch (_) {
      _error = 'تعذر حفظ الاختيار أو تشغيل الخدمة. حاول مرة أخرى.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> _configure() async {
    // SDK failures must not prevent searching or returning to the app.
    try {
      await backend.setDiagnosticsEnabled(diagnosticsEnabled);
    } catch (_) {
      _error = 'تعذر تشغيل تقارير الأعطال حالياً.';
    }
    if (_needsAnalyticsRenewal) return;
    try {
      await backend.setAnalyticsEnabled(analyticsEnabled);
    } catch (_) {
      _error = 'تعذر تشغيل إحصاءات الاستخدام حالياً.';
    }
  }

  Future<void> captureReplay(
    Size size,
    List<Rect> controls,
    Offset? tap,
  ) async {
    if (!replayEnabled) return;
    if (backend case final TelemetryReplayBackend recorder) {
      await recorder.captureReplay(size, controls, tap);
    }
  }

  static void event(String name, [Map<String, Object> properties = const {}]) {
    final service = instance;
    if (service == null || !service.analyticsEnabled) return;
    unawaited(
      service.backend.capture(name, properties).catchError((Object _) {}),
    );
  }

  static void report(
    Object error,
    StackTrace stack,
    String operation, {
    Map<String, Object> details = const {},
  }) {
    final service = instance;
    if (service == null || !service.diagnosticsEnabled) return;
    unawaited(
      service.backend
          .report(error, stack, operation, details: details)
          .catchError((Object _) {}),
    );
  }

  static Future<T> trace<T>(String operation, Future<T> Function() action) {
    final service = instance;
    if (service == null || !service.diagnosticsEnabled) return action();
    return service.backend.trace(operation, action);
  }
}
