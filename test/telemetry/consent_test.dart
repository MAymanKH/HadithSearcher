import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
    'Play automatically enables analytics, replay, and diagnostics',
    () async {
      final preferences = service.preferences;
      const fossConsent = '{"version":1,"decided":true,"analytics":true}';
      await preferences.setString(TelemetryService.consentKey, fossConsent);
      final recorder = _ReplayBackend();
      service.dispose();
      service = TelemetryService(
        preferences: preferences,
        backend: recorder,
        policy: TelemetryPolicy.alwaysOn,
      );
      TelemetryService.instance = service;
      await service.initialize();
      expect(service.needsConsent, false);
      expect(service.canChangeConsent, false);
      expect(recorder.diagnostics, true);
      expect(recorder.analytics, true);
      expect(service.replayEnabled, true);
      TelemetryService.event('screen_viewed');
      await service.captureReplay(() async => null, null);
      expect(recorder.events, ['screen_viewed']);
      expect(recorder.replayFrames, 1);
      expect(await service.save(diagnostics: false, analytics: false), false);
      expect(preferences.getString(TelemetryService.consentKey), fossConsent);
    },
  );

  test('Play never writes a consent choice for FOSS to inherit', () async {
    final preferences = service.preferences;
    service.dispose();
    service = TelemetryService(
      preferences: preferences,
      backend: backend,
      policy: TelemetryPolicy.alwaysOn,
    );
    await service.initialize();
    expect(preferences.containsKey(TelemetryService.consentKey), false);
    final foss = TelemetryService(
      preferences: preferences,
      backend: FakeBackend(),
    );
    addTearDown(foss.dispose);
    await foss.initialize();
    expect(foss.needsConsent, true);
    expect(
      foss.replayEnabled || foss.analyticsEnabled || foss.diagnosticsEnabled,
      false,
    );
  });

  test(
    'previous analytics opt-in is renewed before expanded collection',
    () async {
      final preferences = service.preferences;
      await preferences.setString(
        TelemetryService.consentKey,
        '{"version":1,"decided":true,"diagnostics":true,"analytics":true}',
      );
      service.dispose();
      service = TelemetryService(preferences: preferences, backend: backend);
      await service.initialize();
      expect(service.needsConsent, true);
      expect(service.analyticsEnabled, false);
      expect(backend.transitions, ['diagnostics:true']);
      expect(await service.save(diagnostics: true, analytics: true), true);
      expect(service.needsConsent, false);
      expect(backend.analytics, true);
    },
  );

  test('previous analytics refusal is respected after the update', () async {
    final preferences = service.preferences;
    await preferences.setString(
      TelemetryService.consentKey,
      '{"version":1,"decided":true,"diagnostics":true,"analytics":false}',
    );
    service.dispose();
    service = TelemetryService(preferences: preferences, backend: backend);
    await service.initialize();
    expect(service.needsConsent, false);
    expect(backend.analytics, false);
  });

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
    expect(backend.distribution, appFlavor == 'play' ? 'play' : 'foss');
  });

  test('diagnostics ID and failure context reach a Sentry envelope', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Hadith Searcher',
      packageName: 'com.moaymandev.hadithsearcher',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    const channel = MethodChannel('hadithsearcher/telemetry');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final nativeIds = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'configureDiagnosticsPrivacy') {
        nativeIds.add(call.arguments['installationId']);
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    addTearDown(Sentry.close);

    final transport = _CaptureTransport();
    Future<SdkTelemetryBackend> start() async {
      final backend = SdkTelemetryBackend(
        sentryDsn: 'http://public@127.0.0.1/1',
      );
      await backend.setDiagnosticsEnabled(true);
      // ignore: invalid_use_of_internal_member
      Sentry.currentHub.options.transport = transport;
      return backend;
    }

    Future<Map<String, dynamic>> lastReport() async {
      final item = transport.envelopes.last.items.single;
      return jsonDecode(utf8.decode(await item.dataFactory()))
          as Map<String, dynamic>;
    }

    final first = await start();
    await first.report(
      StateError('private diagnostic message'),
      StackTrace.current,
      'api.book_details.http_500',
      details: {'status_code': 500},
    );
    final report = await lastReport();
    final firstId = report['user']['id'];
    expect(firstId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(firstId, nativeIds.single);
    expect(report['contexts']['failure']['status_code'], 500);
    expect(report.toString(), isNot(contains('private diagnostic message')));

    expect(await first.trace('verification.success', () async => 42), 42);
    final success = await lastReport();
    expect(success['transaction'], 'verification.success');
    expect(success['contexts']['trace']['status'], 'ok');
    final failure = StateError('private trace error');
    await expectLater(
      first.trace<void>('verification.failure', () async => throw failure),
      throwsA(same(failure)),
    );
    final failed = await lastReport();
    expect(failed['transaction'], 'verification.failure');
    expect(failed['contexts']['trace']['status'], 'internal_error');
    expect(failed.toString(), isNot(contains('private trace error')));

    await Sentry.close();
    final restarted = await start();
    expect(nativeIds.last, firstId);
    await restarted.setDiagnosticsEnabled(false);
    expect(
      service.preferences.getString('diagnostics_installation_id'),
      isNull,
    );
    await start();
    expect(nativeIds.last, isNot(firstId));
  });

  test('corrupted consent never enables collection', () {
    for (final raw in [
      null,
      true,
      1,
      'invalid',
      '[]',
      '{"version":99,"decided":true,"analytics":true}',
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
    'Sentry replaces personal identity with the diagnostics installation ID',
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
      final report = SdkTelemetryBackend.scrubError(
        event,
        installationId: 'diagnostic-installation',
      );
      final json = report.toJson().toString();
      expect(json, contains('FormatException'));
      expect(json, isNot(contains('private')));
      expect(json, isNot(contains('someone@example.com')));
      expect(report.user?.id, 'diagnostic-installation');
      expect(report.user?.email, isNull);
      expect(event.request, isNull);
    },
  );
}

class _CaptureTransport implements Transport {
  final envelopes = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId;
  }
}

class _ReplayBackend extends FakeBackend implements TelemetryReplayBackend {
  int replayFrames = 0;

  @override
  Future<void> captureReplay(
    CaptureReplayFrame captureFrame,
    Offset? tap,
  ) async {
    replayFrames++;
  }
}
