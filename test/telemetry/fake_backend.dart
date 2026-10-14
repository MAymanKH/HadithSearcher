import 'dart:async';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';

class FakeBackend implements TelemetryBackend {
  bool diagnostics = false;
  bool analytics = false;
  final events = <String>[];
  final properties = <Map<String, Object>>[];
  final reports = <String>[];
  final transitions = <String>[];
  Completer<void>? stoppingAnalytics;

  @override
  Future<void> setDiagnosticsEnabled(bool enabled) async {
    diagnostics = enabled;
    transitions.add('diagnostics:$enabled');
  }

  @override
  Future<void> setAnalyticsEnabled(bool enabled) async {
    analytics = enabled;
    transitions.add('analytics:$enabled');
    if (!enabled) await stoppingAnalytics?.future;
  }

  @override
  Future<void> capture(String event, Map<String, Object> properties) async {
    events.add(event);
    this.properties.add(properties);
  }

  @override
  Future<void> report(Object error, StackTrace stack, String operation) async {
    reports.add(operation);
  }

  @override
  Future<T> trace<T>(String operation, Future<T> Function() action) => action();

  @override
  Future<String?> analyticsId() async => analytics ? 'test-installation' : null;
}
