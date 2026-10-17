import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';
import 'package:hadithsearcher/services/telemetry/sdk_telemetry_backend.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TelemetryService service;
  late FakeBackend backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend();
    service = TelemetryService(
      preferences: await SharedPreferences.getInstance(),
      backend: backend,
    );
    TelemetryService.instance = service;
  });

  tearDown(() {
    service.dispose();
    TelemetryService.instance = null;
  });

  test('fresh install collects nothing, including before a decision', () async {
    await service.initialize();
    TelemetryService.event('search_submitted', {'query': 'test'});
    TelemetryService.report(
      StateError('test'),
      StackTrace.current,
      'api.search',
    );
    expect(service.consent.decided, false);
    expect(backend.events, isEmpty);
    expect(backend.reports, isEmpty);
    expect(backend.transitions, ['diagnostics:false', 'analytics:false']);
  });

  test(
    'Play enables both SDKs and cannot change a saved F-Droid choice',
    () async {
      final declined = const TelemetryConsent(decided: true).encode();
      await service.preferences.setString(
        TelemetryService.consentKey,
        declined,
      );
      final preferences = service.preferences;
      service.dispose();
      service = TelemetryService(
        preferences: preferences,
        backend: backend,
        policy: TelemetryPolicy.alwaysOn,
      );
      TelemetryService.instance = service;
      await service.initialize();
      expect(service.needsConsent, false);
      expect(service.canChangeConsent, false);
      expect(backend.diagnostics && backend.analytics, true);
      TelemetryService.event('search_submitted');
      TelemetryService.report(
        StateError('test'),
        StackTrace.current,
        'api.search',
      );
      expect(backend.events, ['search_submitted']);
      expect(backend.reports, ['api.search']);
      expect(await service.save(diagnostics: false, analytics: false), false);
      expect(service.analyticsEnabled && service.diagnosticsEnabled, true);
      expect(preferences.getString(TelemetryService.consentKey), declined);
      final fdroid = TelemetryService(
        preferences: preferences,
        backend: FakeBackend(),
      );
      await fdroid.initialize();
      expect(fdroid.analyticsEnabled || fdroid.diagnosticsEnabled, false);
      fdroid.dispose();
    },
  );

  test(
    'Play never records consent that a later F-Droid build can inherit',
    () async {
      final preferences = service.preferences;
      service.dispose();
      service = TelemetryService(
        preferences: preferences,
        backend: backend,
        policy: TelemetryPolicy.alwaysOn,
      );
      await service.initialize();
      expect(preferences.containsKey(TelemetryService.consentKey), false);
      final fdroid = TelemetryService(
        preferences: preferences,
        backend: FakeBackend(),
      );
      await fdroid.initialize();
      expect(fdroid.needsConsent, true);
      expect(fdroid.analyticsEnabled || fdroid.diagnosticsEnabled, false);
      fdroid.dispose();
    },
  );

  test(
    'diagnostics and analytics are independent and survive restart',
    () async {
      await service.save(diagnostics: true, analytics: false);
      TelemetryService.event('search_submitted');
      TelemetryService.report(
        StateError('test'),
        StackTrace.current,
        'api.search',
      );
      expect(backend.events, isEmpty);
      expect(backend.reports, ['api.search']);
      final restarted = TelemetryService(
        preferences: service.preferences,
        backend: FakeBackend(),
      );
      await restarted.initialize();
      expect(restarted.consent.decided, true);
      expect(restarted.consent.diagnostics, true);
      expect(restarted.consent.analytics, false);
      restarted.dispose();
    },
  );

  test(
    'withdrawal blocks events before asynchronous shutdown finishes',
    () async {
      await service.save(diagnostics: true, analytics: true);
      backend.stoppingAnalytics = Completer<void>();
      final save = service.save(diagnostics: false, analytics: false);
      TelemetryService.event('search_submitted');
      TelemetryService.report(
        StateError('test'),
        StackTrace.current,
        'api.search',
      );
      expect(service.consent.analytics, false);
      expect(service.consent.diagnostics, false);
      expect(backend.events, isEmpty);
      expect(backend.reports, isEmpty);
      backend.stoppingAnalytics!.complete();
      expect(await save, true);
      final restored = TelemetryConsent.read(
        service.preferences.getString(TelemetryService.consentKey),
      );
      expect(restored.decided, true);
      expect(restored.analytics, false);
      expect(restored.diagnostics, false);
    },
  );

  test('declining is a saved choice and does not prompt again', () async {
    expect(await service.save(diagnostics: false, analytics: false), true);
    final restored = TelemetryConsent.read(
      service.preferences.getString(TelemetryService.consentKey),
    );
    expect(restored.decided, true);
    expect(restored.analytics || restored.diagnostics, false);
  });

  test('SDK setup failure is visible and the other SDK still starts', () async {
    backend.failDiagnostics = true;
    expect(await service.save(diagnostics: true, analytics: true), false);
    expect(service.error, isNotNull);
    expect(backend.analytics, true);
    backend.failDiagnostics = false;
    expect(await service.save(diagnostics: true, analytics: true), true);
    expect(service.error, isNull);
  });

  test(
    'withdrawal persists and stops both SDKs even if one shutdown fails',
    () async {
      await service.save(diagnostics: true, analytics: true);
      backend.failDiagnostics = true;
      expect(await service.save(diagnostics: false, analytics: false), false);
      expect(backend.analytics, false);
      final restored = TelemetryConsent.read(
        service.preferences.getString(TelemetryService.consentKey),
      );
      expect(restored.decided, true);
      expect(restored.diagnostics || restored.analytics, false);
    },
  );

  test('missing SDK configuration reports a setup error', () async {
    final backend = SdkTelemetryBackend(sentryDsn: '', posthogToken: '');
    await expectLater(backend.setDiagnosticsEnabled(true), throwsStateError);
    await expectLater(backend.setAnalyticsEnabled(true), throwsStateError);
  });

  test('SDK metadata separates development and distribution channels', () {
    final backend = SdkTelemetryBackend();
    expect(backend.environment, 'development');
    expect(
      backend.distribution,
      appFlavor == 'play'
          ? 'play'
          : const String.fromEnvironment('UPDATE_CHANNEL') == 'github'
          ? 'github'
          : 'fdroid',
    );
  });

  test('corrupted or old consent never enables collection', () {
    for (final raw in [
      null,
      true,
      1,
      'invalid',
      '[]',
      '{"version":2,"decided":true,"analytics":true}',
      '{"version":1,"analytics":true}',
    ]) {
      final consent = TelemetryConsent.read(raw);
      expect(
        consent.decided || consent.analytics || consent.diagnostics,
        false,
      );
    }
  });

  test(
    'Sentry payload retains stack type while removing content and identity',
    () {
      final event = SentryEvent(
        user: SentryUser(id: 'user', email: 'someone@example.com'),
        request: SentryRequest(url: 'https://api.example/search?value=private'),
        message: SentryMessage('private search'),
        exceptions: [
          SentryException(type: 'FormatException', value: 'private response'),
        ],
      );
      event.contexts['flutter_error_details'] = {
        'information': 'private hadith',
      };
      final json = SdkTelemetryBackend.scrubError(event).toJson().toString();
      expect(json, contains('FormatException'));
      expect(json, isNot(contains('private')));
      expect(json, isNot(contains('someone@example.com')));
      expect(event.user, isNull);
      expect(event.request, isNull);
    },
  );
}
