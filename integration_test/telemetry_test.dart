import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// ignore: implementation_imports
import 'package:sentry_flutter/src/utils/platform_dispatcher_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hadithsearcher/app.dart';
import 'package:hadithsearcher/services/telemetry/sdk_telemetry_backend.dart';
import 'package:hadithsearcher/services/telemetry/telemetry_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android telemetry respects consent and discards queued data on withdrawal',
    (tester) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bodies = <String>[];
      var accepting = true;
      var requests = 0;
      final subscription = server.listen((request) async {
        requests++;
        if (request.uri.path == '/array/phc_local_test/config') {
          request.response
            ..headers.contentType = ContentType.json
            ..write('{"sessionRecording":{"sampleRate":"1"}}');
          await request.response.close();
          return;
        }
        var bytes = await request.fold<List<int>>(
          [],
          (buffer, data) => buffer..addAll(data),
        );
        if (request.headers.value('content-encoding') == 'gzip') {
          bytes = gzip.decode(bytes);
        }
        if (accepting) bodies.add(utf8.decode(bytes));
        request.response.statusCode = accepting ? 200 : 503;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"status":1}');
        await request.response.close();
      });
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();
      await preferences.setBool('welcomeCompleted', true);
      final backend = SdkTelemetryBackend(
        sentryDsn: 'http://public@127.0.0.1:${server.port}/1',
        posthogToken: 'phc_local_test',
        posthogHost: 'http://127.0.0.1:${server.port}',
      );
      final telemetry = TelemetryService(
        preferences: preferences,
        backend: backend,
      );
      Future<void> saveChoices() async {
        final button = find.byKey(const Key('save-telemetry-consent'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        for (var attempt = 0; telemetry.saving && attempt < 100; attempt++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(telemetry.saving, isFalse);
        await tester.pumpAndSettle();
      }

      addTearDown(() async {
        await telemetry.save(diagnostics: false, analytics: false);
        TelemetryService.instance = null;
        telemetry.dispose();
        await subscription.cancel();
        await server.close(force: true);
      });
      TelemetryService.instance = telemetry;
      await telemetry.initialize();
      await tester.pumpWidget(
        HadithSearcherApp(
          initialThemeMode: ThemeMode.light,
          telemetry: telemetry,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('analytics-consent')), findsOneWidget);
      expect(requests, 0);
      expect(Sentry.isEnabled, false);
      for (final key in ['analytics-consent', 'diagnostics-consent']) {
        expect(
          tester.widget<CheckboxListTile>(find.byKey(Key(key))).value,
          true,
        );
        await tester.tap(find.byKey(Key(key)));
      }
      await tester.pump();
      await saveChoices();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(requests, 0);

      await tester.tap(find.text('الإعدادات').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('الخصوصية والقياس الاختياري'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الخصوصية والقياس الاختياري'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('diagnostics-consent')));
      await tester.tap(find.byKey(const Key('analytics-consent')));
      await saveChoices();
      expect(telemetry.consent.analytics, true);
      expect(telemetry.consent.diagnostics, true);
      expect(Sentry.isEnabled, true);
      expect(find.byType(NavigationBar), findsOneWidget);

      for (var index = 0; index < 4; index++) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
      }

      final firstId = await backend.analyticsId();
      await backend.capture('search_submitted', {'query': 'consented-query'});
      await backend.report(
        StateError('secret-query@example.com'),
        StackTrace.current,
        'integration.error',
        details: {'status_code': 503},
      );
      final frameworkError = StateError('private-framework-error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: frameworkError,
          stack: StackTrace.current,
        ),
      );
      expect(tester.takeException(), same(frameworkError));
      // Flutter's TestPlatformDispatcher.onError setter is a no-op. Connect
      // the installed SDK integration to the real dispatcher for this check.
      // ignore: invalid_use_of_internal_member
      final hub = Sentry.currentHub;
      // ignore: invalid_use_of_internal_member
      final onError = hub.options.integrations
          .whereType<OnErrorIntegration>()
          .single;
      onError.close();
      onError.dispatchWrapper = PlatformDispatcherWrapper(
        PlatformDispatcher.instance,
      );
      // ignore: invalid_use_of_internal_member
      onError(hub, hub.options as SentryFlutterOptions);
      expect(PlatformDispatcher.instance.onError, isNotNull);
      PlatformDispatcher.instance.onError!(
        StateError('private-async-error'),
        StackTrace.current,
      );
      await backend.flushAnalytics();
      await tester.runAsync(() async {
        for (
          var attempt = 0;
          attempt < 30 &&
              (!bodies.any((body) => body.contains('search_submitted')) ||
                  !bodies.any((body) => body.contains('integration.error')) ||
                  !bodies.any((body) => body.contains('FlutterError')) ||
                  !bodies.any((body) => body.contains(r'$snapshot')) ||
                  !bodies.any(
                    (body) => body.contains('PlatformDispatcher.onError'),
                  ));
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      });
      expect(
        bodies.any(
          (body) =>
              body.contains('search_submitted') &&
              body.contains('consented-query'),
        ),
        true,
      );
      expect(bodies.any((body) => body.contains('integration.error')), true);
      expect(bodies.any((body) => body.contains('FlutterError')), true);
      expect(
        bodies.any((body) => body.contains('PlatformDispatcher.onError')),
        true,
      );
      expect(bodies.any((body) => body.contains('screen_viewed')), true);
      final analyticsEvents = bodies
          .map(jsonDecodeOrNull)
          .whereType<Map<String, dynamic>>()
          .expand((body) => (body['batch'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>();
      final screen = analyticsEvents.firstWhere(
        (event) => event['event'] == r'$screen',
      );
      final screenProperties = screen['properties'] as Map<String, dynamic>;
      expect(screenProperties[r'$screen_name'], isA<String>());
      expect(screenProperties[r'$device_type'], isIn(['Mobile', 'Tablet']));
      expect(screenProperties[r'$os'], 'Android');
      expect(
        screenProperties[r'$session_id'],
        matches(RegExp(r'^[0-9a-f-]{14}7')),
      );
      expect(screenProperties[r'$process_person_profile'], isFalse);
      expect(screenProperties, isNot(contains(r'$geoip_disable')));
      expect(screen['distinct_id'], firstId);
      final recordingBody = bodies
          .map(jsonDecodeOrNull)
          .whereType<List<dynamic>>()
          .expand((events) => events)
          .whereType<Map<String, dynamic>>()
          .firstWhere((event) => event['event'] == r'$snapshot');
      final recordingProperties =
          recordingBody['properties'] as Map<String, dynamic>;
      expect(recordingBody['distinct_id'], firstId);
      expect(
        recordingProperties[r'$session_id'],
        screenProperties[r'$session_id'],
      );
      expect(recordingProperties[r'$snapshot_source'], 'mobile');
      expect(recordingProperties[r'$snapshot_data'], isNotEmpty);
      final replay = jsonEncode(recordingProperties[r'$snapshot_data']);
      expect(replay, contains('"type":"rectangle"'));
      expect(replay, isNot(contains('consented-query')));
      expect(replay, isNot(contains('base64')));
      expect(bodies.join(), isNot(contains('secret-query@example.com')));
      expect(bodies.join(), isNot(contains('private-framework-error')));
      expect(bodies.join(), isNot(contains('private-async-error')));
      final diagnosticEvents = bodies
          .expand((body) => body.split('\n'))
          .map(jsonDecodeOrNull)
          .whereType<Map<String, dynamic>>()
          .where((event) => event.containsKey('exception'))
          .toList();
      final manualReport = diagnosticEvents.firstWhere(
        (event) => event['tags']?['operation'] == 'integration.error',
      );
      expect(manualReport['contexts']['failure']['status_code'], 503);
      final diagnosticId = manualReport['user']['id'];
      expect(diagnosticId, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(diagnosticId, isNot(firstId));
      expect(diagnosticEvents.map((event) => event['user']?['id']).toSet(), {
        diagnosticId,
      });

      accepting = false;
      await backend.capture('queued_before_withdrawal', {
        'query': 'queued-query',
      });
      await backend.report(
        StateError('queued diagnostic'),
        StackTrace.current,
        'queued_diagnostic',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await telemetry.save(diagnostics: false, analytics: false);
      expect(Sentry.isEnabled, false);
      expect(preferences.getString('diagnostics_installation_id'), isNull);
      accepting = true;
      final afterWithdrawal = requests;
      TelemetryService.event('after_withdrawal');
      TelemetryService.report(
        StateError('declined'),
        StackTrace.current,
        'declined',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      expect(requests, afterWithdrawal);
      final restored = TelemetryService(
        preferences: preferences,
        backend: backend,
      );
      await restored.initialize();
      expect(restored.consent.analytics || restored.consent.diagnostics, false);
      await restored.save(diagnostics: true, analytics: true);
      expect(await backend.analyticsId(), isNot(firstId));
      expect(
        preferences.getString('diagnostics_installation_id'),
        isA<String>().having((id) => id, 'diagnostics ID', isNot(diagnosticId)),
      );
      await backend.capture('after_reconsent', {});
      await backend.flushAnalytics();
      await tester.runAsync(() async {
        for (
          var attempt = 0;
          attempt < 30 &&
              !bodies.any((body) => body.contains('after_reconsent'));
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      });
      expect(bodies.any((body) => body.contains('after_reconsent')), true);
      expect(bodies.join(), isNot(contains('queued_before_withdrawal')));
      expect(bodies.join(), isNot(contains('queued_diagnostic')));
      await restored.save(diagnostics: false, analytics: false);
      await tester.pumpWidget(const SizedBox());
      restored.dispose();
    },
  );
}

Object? jsonDecodeOrNull(String data) {
  try {
    return jsonDecode(data);
  } on FormatException {
    // A Sentry envelope is not a single JSON object.
    return null;
  }
}
